# 배포 진행 상태 (인수인계)

Istio + 관측(Mimir/Loki) + AgentOps 데모 배포 현황. 새 세션에서 이 문서를 읽고 이어서 진행한다.

## 환경

- 클러스터: `awsops-eks` (ap-northeast-2, EKS 1.34, 워커 t3.medium x3)
- KUBECONFIG: `~/.kube/config` (로컬 WSL에서 kubectl/helm/istioctl/eksctl 사용, 전부 `~/.local/bin`)
- 리포: `~/awsops` (원격 github.com/hojun121/awsops, credential helper 설정됨)
- 로컬에 미푸시 커밋 다수 있음 (push는 사용자 요청 시에만)

## 완료된 것 (검증됨)

- Istio 코어(demo 프로파일), mTLS STRICT
- 관측: **Loki, Mimir(모놀리식), Alloy** (observability ns) — 메트릭+로그 동작 검증
  - 메트릭: Alloy가 Envoy 사이드카 scrape -> Mimir
  - 로그: Alloy가 bookinfo/istio-system 파드 로그 -> Loki
- **트레이스(Tempo)는 제거함** — Istio 1.30 Envoy OTel/Zipkin 트레이서가 span을 안 만드는 이슈. 메트릭+로그 2-pillar로 결정.
- Bookinfo(6파드 2/2, reviews v2 고정), Kiali(Mimir 소스), Grafana(Mimir/Loki 데이터소스, admin/qwe1212!Q)
- **외부 노출 (Gateway API + NLB + ACM TLS)**: 5개 호스트 HTTPS 검증(200/302)
  - NLB: `a360f3d140f254e33bc4f0d02bb66cf0-8649479b95618601.elb.ap-northeast-2.amazonaws.com`
  - ACM(ap-northeast-2): `*.kia-awsops.noticore.co.kr` (ISSUED)
  - Route53 서브존: `Z03681161TE21SNQIYCK` (kia-awsops.noticore.co.kr)

## 접속 URL

- 대시보드: https://kia-awsops.noticore.co.kr/awsops  (hojun121@gmail.com / qwe1212!Q)
- bookinfo: https://bookinfo.kia-awsops.noticore.co.kr/productpage
- grafana: https://grafana.kia-awsops.noticore.co.kr (admin / qwe1212!Q)
- kiali: https://kiali.kia-awsops.noticore.co.kr (익명)
- mimir: https://mimir.kia-awsops.noticore.co.kr/prometheus
- loki: https://loki.kia-awsops.noticore.co.kr

## 남은 작업

1. **Step 10 대시보드 배선**: awsops 대시보드에 데이터소스 등록 (EC2/UI에서)
   - Mimir(prometheus): https://mimir.kia-awsops.noticore.co.kr/prometheus
   - Loki: https://loki.kia-awsops.noticore.co.kr
   - 저장 위치: EC2 `data/config.json`의 `datasources` 배열, 또는 대시보드 `/api/datasources` UI
   - 주의: 코드에 SSRF URL 화이트리스트 있음 -> 공개 URL 막히는지 확인 필요 (src/app/api/datasources/route.ts, getDatasourceAllowedNetworks)
2. **Step 11 장애 리허설**: L7(app-demo/faults/l7-ratings-500.yaml) + L4(details replicas=0) 주입 -> 수동 진단(Kiali/Grafana) -> AgentOps 진단
3. **보안 하드닝**: Mimir/Loki/Kiali 공개 무인증 노출됨. 데모 후 삭제 또는 IP 제한/인증 권장.
4. **문서 정리**: docs/istio-agentops-demo/ (00~05)에 Tempo/트레이스 언급 남아있음 -> 2-pillar로 수정 필요.

## 재현/정리 명령

- 배포물: `app-demo/platform/` (istio-install.yaml, observability/*.yaml, addons/*.yaml, gateway/gateway.yaml)
- 장애 주입/복구: `app-demo/faults/README.md`
- 트래픽: `app-demo/scripts/traffic.sh`
- 비용주의: EKS 워커3 + NLB + 컨트롤플레인 상시 과금. 데모 후 `eksctl delete cluster -f ~/awsops-eks.yaml`
