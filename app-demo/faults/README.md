# 장애 시나리오

L7과 L4 장애를 각각 다른 계층에서 주입한다. 자세한 신호 해석은 `docs/istio-agentops-demo/02-fault-scenarios.md` 참고.

## L7 장애 — ratings에 HTTP 500 (앱 계층)

TCP 연결은 성공하고 애플리케이션이 500을 응답한다. Envoy response_flags = FI.

```bash
kubectl apply -f l7-ratings-500.yaml     # 주입
kubectl delete -f l7-ratings-500.yaml    # 복구
```

## L4 장애 — details 파드 0개 (전송 계층)

엔드포인트가 없어 TCP 연결 자체가 실패한다. Envoy response_flags = UH, 로그에는 connection refused.
매니페스트가 아니라 스케일 명령으로 낸다.

```bash
kubectl scale deploy details -n bookinfo --replicas=0    # 주입
kubectl scale deploy details -n bookinfo --replicas=1    # 복구
```

## 동시 주입 / 복구

```bash
# 주입
kubectl apply -f l7-ratings-500.yaml
kubectl scale deploy details -n bookinfo --replicas=0

# 복구
kubectl delete -f l7-ratings-500.yaml
kubectl scale deploy details -n bookinfo --replicas=1
```
