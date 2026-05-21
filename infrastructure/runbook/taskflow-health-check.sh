#!/bin/bash
# TaskFlow Stack Health Check

NAMESPACES=("taskflow-dev" "taskflow-staging" "taskflow-prod")
ENDPOINTS=(
  "dev:http://13.221.130.136.nip.io/api/health"
  "staging:http://staging.13.221.130.136.nip.io/api/health"
  "prod:http://prod.13.221.130.136.nip.io/api/health"
)
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
REPORT_FILE="/tmp/taskflow-health-$(date +%Y%m%d_%H%M%S).txt"

PASS=0
FAIL=0
WARN=0

log()     { echo -e "$1" | tee -a "$REPORT_FILE"; }
pass()    { log "  [PASS] $1"; PASS=$((PASS+1)); }
fail()    { log "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn()    { log "  [WARN] $1"; WARN=$((WARN+1)); }
section() { log "\n--- $1 ---"; }

check_nodes() {
  section "Cluster Nodes"
  NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null || true)
  NOT_READY=$(echo "$NODE_STATUS" | grep -v " Ready" | grep -c "." || true)
  if [ "$NOT_READY" -eq 0 ]; then
    pass "All nodes Ready"
  else
    fail "$NOT_READY node(s) not Ready"
  fi
}

check_pods() {
  section "Pod Health"
  for NS in "${NAMESPACES[@]}"; do
    POD_STATUS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null || true)
    if [ -z "$POD_STATUS" ]; then
      fail "$NS: no pods found"
      continue
    fi
    TOTAL=$(echo "$POD_STATUS" | wc -l)
    NOT_RUNNING=$(echo "$POD_STATUS" | grep -v "Running\|Completed" | \
      grep -c "." || true)
    if [ "$NOT_RUNNING" -eq 0 ]; then
      pass "$NS: $TOTAL pods running"
    else
      fail "$NS: $NOT_RUNNING/$TOTAL pods not running"
      echo "$POD_STATUS" | grep -v "Running\|Completed" | \
        tee -a "$REPORT_FILE" || true
    fi
  done
}

check_endpoints() {
  section "API Health Endpoints"
  for ENTRY in "${ENDPOINTS[@]}"; do
    ENV="${ENTRY%%:*}"
    URL="${ENTRY#*:}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --connect-timeout 5 --max-time 10 "$URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
      pass "$ENV: HTTP $HTTP_CODE"
    else
      fail "$ENV: HTTP $HTTP_CODE -- $URL unreachable"
    fi
  done
}

check_disk() {
  section "Disk Usage"
  USAGE=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
  if [ "$USAGE" -lt 70 ]; then
    pass "Disk usage: ${USAGE}%"
  elif [ "$USAGE" -lt 85 ]; then
    warn "Disk usage: ${USAGE}% (getting high)"
  else
    fail "Disk usage: ${USAGE}% (critical)"
  fi
}

check_memory() {
  section "Memory Usage"
  USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
  if [ "$USAGE" -lt 70 ]; then
    pass "Memory usage: ${USAGE}%"
  elif [ "$USAGE" -lt 85 ]; then
    warn "Memory usage: ${USAGE}%"
  else
    fail "Memory usage: ${USAGE}% (critical)"
  fi
}

send_slack() {
  if [ -z "$SLACK_WEBHOOK" ]; then return; fi
  if [ "$FAIL" -gt 0 ]; then STATUS="UNHEALTHY"
  elif [ "$WARN" -gt 0 ]; then STATUS="DEGRADED"
  else STATUS="HEALTHY"; fi
  REPORT=$(sed 's/\x1b\[[0-9;]*m//g' "$REPORT_FILE" | head -50)
  curl -s -X POST "$SLACK_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"TaskFlow Health: $STATUS\n\`\`\`$REPORT\`\`\`\"}" \
    > /dev/null && log "Slack notification sent"
}

log "TaskFlow Health Check -- $(date)"
log "======================================"
check_nodes
check_pods
check_endpoints
check_disk
check_memory
log "\n--- Summary ---"
log "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
log "Report saved: $REPORT_FILE"
send_slack
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
