#!/usr/bin/env bash
# on-demand 트래픽 생성기. 데모/리허설 때만 실행하고 종료(Ctrl+C)한다.
# 사전: kubectl -n bookinfo port-forward svc/productpage 9080:9080
#
# 사용: ./traffic.sh [요청수]   (기본 200)
set -euo pipefail

N="${1:-200}"
URL="${URL:-http://localhost:9080/productpage}"

echo "generating ${N} requests to ${URL} (Ctrl+C to stop)"
for i in $(seq 1 "${N}"); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "${URL}" || echo "000")
  printf '\r[%d/%d] last=%s' "${i}" "${N}" "${code}"
  sleep 0.2
done
echo ""
