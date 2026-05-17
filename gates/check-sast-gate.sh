#!/usr/bin/env bash
# SAST gate — entry point
# 교체 지점: 스캐너 라인 하나만 바꾸면 실제 Sparrow로 전환 가능
#
# Usage:
#   bash check-sast-gate.sh [target] [--fast|--full]
#   --fast : Critical만 검사 (pre-commit용)
#   --full : 전체 검사 (local gate / CI용, default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
MODE="${2:---full}"
REPORT_DIR=".harness/ouroboros/reports/sparrow"

echo "🔍 SAST Gate 실행 중... (mode: $MODE)"

# ── 스캐너 교체 지점 ──────────────────────────────────────────
# 지금:  check-sparrow-mock.sh
# 향후:  sparrow-cli scan --output=pipe ...
"$SCRIPT_DIR/check-sparrow-mock.sh" "$TARGET" "$MODE" \
  | "$SCRIPT_DIR/sparrow-adapter.sh" "$REPORT_DIR"
# ─────────────────────────────────────────────────────────────

RESULT_FILE="$REPORT_DIR/latest-result.json"

STATUS=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d['status'])" 2>/dev/null || echo "ERROR")
CRITICAL=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(len([f for f in d['findings'] if f['severity']=='Critical']))" 2>/dev/null || echo "0")
HIGH=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(len([f for f in d['findings'] if f['severity']=='High']))" 2>/dev/null || echo "0")
MEDIUM=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(len([f for f in d['findings'] if f['severity']=='Medium']))" 2>/dev/null || echo "0")

echo ""
echo "  Critical: ${CRITICAL}건 / High: ${HIGH}건 / Medium: ${MEDIUM}건"
echo "  결과 저장: $RESULT_FILE"

if [ "$STATUS" = "FAIL" ]; then
  echo ""
  echo "❌ SAST GATE FAIL — Critical/High 발견"
  python3 -c "
import json
d = json.load(open('$RESULT_FILE'))
for f in d['findings']:
    if f['severity'] in ('Critical', 'High'):
        print(f\"  [{f['severity']}] {f['rule_id']} — {f['file']}:{f['line']} {f['message']}\")
"
  exit 1
fi

echo "✅ SAST GATE PASS"
