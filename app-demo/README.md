# app-demo

Istio + AgentOps 관측성 데모에서 사용하는 데모 애플리케이션과 메시 설정, 장애 매니페스트 모음이다.
전부 명령형(kubectl)으로 배포한다. 관측 플랫폼(Istio 코어, Mimir/Loki/Tempo/Alloy, Kiali/Grafana) 배포와 전체 흐름은 `docs/istio-agentops-demo/`를 참고한다.

## 디렉토리 구성

```
app-demo/
  bookinfo/
    bookinfo.yaml               # Bookinfo 앱 (upstream vendoring)
    reviews-v2-routing.yaml     # reviews를 v2로 고정 (ratings 항상 호출)
  istio/
    peer-authentication.yaml    # 메시 전체 mTLS STRICT
    telemetry.yaml              # 액세스 로그 + 트레이싱(샘플링 100%)
  faults/
    l7-ratings-500.yaml         # L7 장애: ratings HTTP 500
    README.md                   # L7/L4 주입·복구 방법
  scripts/
    traffic.sh                  # on-demand 트래픽 생성기
```

## 사전 조건

- awsops-eks 클러스터에 Istio가 설치되어 있고 bookinfo 네임스페이스에 사이드카 주입이 켜져 있어야 한다.
- KUBECONFIG가 awsops-eks를 가리켜야 한다.

## 배포 순서

```bash
export KUBECONFIG=~/.kube/config

# 1. 네임스페이스 + 사이드카 주입
kubectl create namespace bookinfo
kubectl label namespace bookinfo istio-injection=enabled --overwrite

# 2. mTLS, 텔레메트리 (메시 전체)
kubectl apply -f istio/peer-authentication.yaml
kubectl apply -f istio/telemetry.yaml

# 3. Bookinfo 앱 + 라우팅 고정
kubectl -n bookinfo apply -f bookinfo/bookinfo.yaml
kubectl -n bookinfo apply -f bookinfo/reviews-v2-routing.yaml

# 4. 파드 Ready 확인
kubectl -n bookinfo get pods
```

## 트래픽 생성 (검증/데모)

```bash
kubectl -n bookinfo port-forward svc/productpage 9080:9080 &
./scripts/traffic.sh 200
```

## 장애 주입 / 복구

`faults/README.md` 참고. 요약하면 L7은 매니페스트 apply, L4는 details 스케일 0.

## 정리

```bash
kubectl delete namespace bookinfo
kubectl delete -f istio/telemetry.yaml -f istio/peer-authentication.yaml
```
