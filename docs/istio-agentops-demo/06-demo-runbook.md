# 06 · 데모 실행 대본 (Run-of-Show)

발표자가 이 문서 하나만 띄워놓고 위에서 아래로 따라가면 되는 실전 대본이다.
개념 설명은 00~04 문서를 참고하고, 여기서는 "무엇을 열고, 무엇을 치고, 무엇을 말하는가"만 순서대로 담는다.
전체 소요 약 4~5분.

## 접속 정보

| 대상 | URL | 로그인 |
|---|---|---|
| awsops 대시보드 (AgentOps) | https://kia-awsops.noticore.co.kr/awsops | hojun121@gmail.com / qwe1212!Q |
| Bookinfo (데모 앱) | https://bookinfo.kia-awsops.noticore.co.kr/productpage | 없음 |
| Grafana | https://grafana.kia-awsops.noticore.co.kr | hojun121@gmail.com / qwe1212!Q (admin/qwe1212!Q 도 가능) |
| Kiali | https://kiali.kia-awsops.noticore.co.kr | 익명 |

Grafana에서 미리 열어둘 대시보드:

| 대시보드 | 경로 | 용도 |
|---|---|---|
| Istio Mesh | /d/1a9a8ea49444aae205c7737573e894f9/istio-mesh-dashboard | 메시 전체 요청량·에러율 |
| Istio Service | /d/536dd68a-4754-4e4a-8b9c-587665f6086a/istio-service-dashboard | 서비스별(ratings/details) 상세 |
| Istio Workload | /d/629a5706-0aa2-4cd1-b8f4-1c3650b5ebff/istio-workload-dashboard | 워크로드 인바운드/아웃바운드 |
| Loki · Mesh Logs | /d/loki-mesh-logs | bookinfo/istio 로그 (에러 필터 패널 포함) |

## 사전 체크리스트 (데모 시작 전 반드시 확인)

1. 클러스터·파드 정상 (KUBECONFIG=~/.kube/config, PATH에 ~/.local/bin)
   ```bash
   kubectl get pods -n bookinfo          # 6개 모두 Running, details-v1 1/1
   kubectl get deploy details-v1 -n bookinfo   # 1/1 (이전 데모의 0 잔재 없어야)
   kubectl get vs -n bookinfo            # ratings VS 없어야 정상 (있으면 이전 fault 잔재)
   ```
   잔재 있으면 복구 명령(맨 아래) 먼저 실행.

2. AI 어시스턴트 모델이 Opus인지 확인
   - awsops 대시보드 AI 어시스턴트의 모델 선택이 Opus 4.6 이어야 한다.
   - 이유: 이 계정에서 `claude-sonnet-4-6` 모델 액세스가 차단돼 있다(AWS Marketplace/SCP). sonnet-4-6로 호출하면 AI 어시스턴트가 전부 에러난다.

3. EC2 대시보드 서버를 clean 재배포하지 말 것
   - EC2(`/home/ec2-user/awsops`)에는 git에 없는 수동 패치 2개가 적용돼 있다.
     - `src/lib/collectors/incident.ts` — incident 엔진 쿼리를 Istio 메트릭(`istio_requests_total`)으로 교체
     - `src/app/api/ai/route.ts` — 모델을 opus로 교체
   - 깨끗한 `git pull` 후 재빌드하면 두 패치가 사라져 AgentOps가 동작하지 않는다. 재빌드가 꼭 필요하면 두 패치를 다시 적용하고 `bash scripts/03-build-deploy.sh`.

4. Grafana 데이터소스 health OK (Mimir, Loki 둘 다 초록)

## 진행 순서

### 0. 정상 상태 보여주기 (30초)

- Bookinfo productpage 열기 → 별점(ratings)과 상세(details)가 정상 표시됨을 보여준다.
- Kiali Graph(bookinfo 네임스페이스) → 엣지가 전부 초록.
- "지금은 다 정상입니다. 여기에 서로 다른 계층의 장애 두 개를 동시에 넣겠습니다."

### 1. 장애 주입 (L7 + L4 동시)

```bash
# L7 (앱 계층): ratings가 HTTP 500 반환 (Envoy response_flags=FI)
kubectl apply -f ~/awsops/app-demo/faults/l7-ratings-500.yaml

# L4 (전송 계층): details 파드 0개 → 연결 자체 실패 (response_flags=UH)
kubectl scale deploy details-v1 -n bookinfo --replicas=0
```

말할 것: "하나는 앱이 에러를 뱉는 L7 장애, 하나는 연결이 끊기는 L4 장애입니다. 계층이 다릅니다."

### 2. 트래픽 흘리기 (관찰용, 계속 켜두기)

```bash
# 공개 URL로 지속 트래픽 (Ctrl+C로 중단). 데모 내내 켜둔다.
for i in $(seq 1 600); do curl -s -o /dev/null https://bookinfo.kia-awsops.noticore.co.kr/productpage; sleep 0.3; done
```

- productpage를 새로고침 → "Ratings service currently unavailable"(L7)와 "Error fetching product details"(L4)가 뜬다. 단, 페이지 자체는 죽지 않고 200으로 degraded 됨을 강조.

### 3. 수동 진단 (사람이 도구를 오가며)

이 단계의 메시지: "원인을 찾으려면 사람이 화면 서너 개를 오가야 합니다."

- Kiali Graph: `reviews→ratings` 엣지 빨강, `productpage→details` 엣지 빨강. "위치는 보이는데 왜 깨졌는지는 모릅니다."
- Grafana → Istio Service 대시보드에서 ratings, details 선택. 또는 Explore(Mimir)에서:
  ```promql
  topk(20, sum by (destination_service_name, source_workload, response_code, response_flags)
    (rate(istio_requests_total{response_code=~"5.."}[5m])))
  ```
  결과: ratings `500 / FI`, details `503 / UH`. "response_flags로 계층이 갈립니다. FI는 앱 계층, UH는 연결 실패."
- Grafana → Loki · Mesh Logs 대시보드 (namespace=bookinfo). 에러 패널에서:
  - L7: `"GET /ratings/0" 500 FI fault_filter_abort`
  - L4: `no healthy upstream` / `upstream connect error`
- "메트릭, 로그, 그래프를 사람이 시간축 맞춰가며 종합해야 합니다. 원인이 둘이고 계층이 다르면 더 오래 걸립니다."

### 4. AgentOps 진단 (한 질문으로)

- awsops 대시보드 → AI 어시스턴트 → 반드시 새 대화(직전 대화 이어가지 말 것. 히스토리가 분류를 오염시킴).
- 질문 입력:
  ```
  장애 원인 분석해줘. productpage가 지금 장애야. Metric/Log 종합해서 계층별 원인 찾아줘.
  ```
- 기대 응답: 두 원인을 계층과 함께 제시.
  - L7 — ratings에 fault injection(HTTP 500, response_flags=FI). 조치: ratings VirtualService의 fault 블록 제거.
  - L4 — details 파드 0개, 연결 실패(response_flags=UH). 조치: details를 replicas 1 이상으로 복구.
- 말할 것: "사람이 화면 서너 개를 오가던 걸, 자연어 한 문장으로 대신합니다. 계층 구분과 조치까지 나옵니다."
- 화면 하단 표시가 incident 엔진이어야 정상. `Bedrock Direct (fallback ...)`이 뜨면 모델/분류가 깨진 것(사전 체크리스트 2번 확인).

### 5. 복구

```bash
kubectl delete -f ~/awsops/app-demo/faults/l7-ratings-500.yaml
kubectl scale deploy details-v1 -n bookinfo --replicas=1
kubectl rollout status deploy/details-v1 -n bookinfo
```

- productpage 새로고침 → 별점·상세 정상 복귀. 트래픽 루프는 Ctrl+C로 종료.

## 신호 요약 (한 장 참고표)

| 신호 | L7 (ratings 500) | L4 (details 0) |
|---|---|---|
| Kiali | reviews→ratings 엣지 빨강 | productpage→details 엣지 빨강 |
| Mimir | response_code=500, response_flags=FI | response_code=503, response_flags=UH |
| Loki | 500 FI fault_filter_abort | no healthy upstream / connection refused |
| 화면 | "Ratings service currently unavailable" | "Error fetching product details" |
| 근본 원인 | ratings VS의 fault.abort | details replicas=0 |

## 트러블슈팅

- AI 어시스턴트가 모델 접근 에러: 모델을 Opus로 바꾼다. sonnet-4-6는 이 계정에서 차단.
- AgentOps가 원인을 못 잡고 원론적 답만: (a) 새 대화로 다시 질문, (b) 트래픽이 흐르는지 확인(장애 신호는 요청이 있어야 생김), (c) EC2가 clean 재배포돼 패치가 날아갔는지 확인.
- Grafana 패널이 빔: 데이터소스 health 확인, 시간 범위를 최근 15분으로.
- EKS/노드 리소스 대시보드: 현재 노드/kube-state/cadvisor 메트릭을 수집하지 않아 데이터 없음. 메시(Istio) 대시보드와 Loki 로그만 사용.
