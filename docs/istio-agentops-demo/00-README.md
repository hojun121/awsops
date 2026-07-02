# Istio + AgentOps 관측성 데모 — 문서 인덱스

서비스 메시(Istio)에 L4·L7 장애를 동시에 주입하고, 두 가지 진단 방식을 비교하는 데모의 런북 모음이다.

- 방식 1: 사람이 Metric/Log 도구를 각각 열어 수동으로 원인을 찾는다.
- 방식 2: AgentOps(awsops 대시보드)가 한 번의 질문으로 두 신호를 통합해 진단한다.

## 문서 구성

| 번호 | 문서 | 내용 |
|---|---|---|
| 01 | [배포 인벤토리 & 아키텍처](01-deployment-inventory.md) | 무엇을 배포했고 어떻게 연결되는가 |
| 02 | [장애 시나리오](02-fault-scenarios.md) | L4/L7 장애 주입과 복구, 신호 정리 |
| 03 | [수동 진단 방법](03-manual-diagnosis.md) | Kiali, Grafana(Metric/Log), kubectl로 진단 |
| 04 | [AgentOps 진단 방법](04-agentops-diagnosis.md) | awsops 대시보드로 통합 진단 |
| 05 | [배포 계획](05-deployment-plan.md) | 배포 순서와 명령 |
| 06 | [데모 실행 대본](06-demo-runbook.md) | 발표자가 따라 읽는 실전 진행 대본 (URL·명령·질문·체크리스트) |

## 아키텍처 개요

```
메시 관측 라인 (이번 데모에서 신규 배포)
Istio/Envoy --metric--> Alloy --> Mimir  --+--> 수동: Grafana, Kiali
            --log-----> Alloy --> Loki   --+--> AgentOps: awsops 대시보드

비용 라인 (기존, 변경 없음)
노드/파드 메트릭 --> Prometheus(opencost) --> OpenCost --> awsops 대시보드
```

## 데모 진행 흐름 (약 3~4분)

1. 정상 화면 확인
2. 장애 주입: L7(ratings 500) + L4(details 0)
3. 수동 진단: Kiali, Grafana 탭을 오가며 원인 추적
4. AgentOps 진단: 한 질문으로 통합 결과 확인
5. 복구

## 환경 요약

- 클러스터: awsops-eks (ap-northeast-2, EKS 1.34, 워커 t3.medium 3대)
- 저장: emptyDir(임시), 트래픽 on-demand
- 네임스페이스: istio-system(메시, Kiali, Grafana), observability(Alloy, Mimir, Loki), bookinfo(앱), opencost(기존 비용)
