#!/usr/bin/env bash
# Sparrow 어댑터 — raw 스캐너 출력을 표준 JSON으로 변환
# Input:  stdin (RULE_ID|SEVERITY|FILE|LINE|MESSAGE)
# Output: latest-result.json + history/{timestamp}.json
#
# 스캐너가 바뀌어도 이 어댑터가 표준 포맷으로 정규화하므로
# /evaluate, /evolve는 항상 동일한 JSON 구조를 읽는다

REPORT_DIR="${1:-.harness/ouroboros/reports/sparrow}"
mkdir -p "$REPORT_DIR/history"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FINDINGS_RAW=$(cat)

python3 - <<EOF
import json, sys, os
from datetime import datetime

raw = """$FINDINGS_RAW"""
report_dir = "$REPORT_DIR"
timestamp = "$TIMESTAMP"

findings = []
for line in raw.strip().splitlines():
    if not line.strip():
        continue
    parts = line.split("|", 4)
    if len(parts) < 5:
        continue
    rule_id, severity, filepath, lineno, message = parts
    findings.append({
        "rule_id": rule_id.strip(),
        "severity": severity.strip(),
        "file": filepath.strip(),
        "line": int(lineno.strip()) if lineno.strip().isdigit() else 0,
        "message": message.strip()
    })

status = "FAIL" if any(f["severity"] in ("Critical", "High") for f in findings) else "PASS"

result = {
    "scanner": "sparrow-mock",
    "timestamp": timestamp,
    "status": status,
    "summary": {
        "total": len(findings),
        "critical": sum(1 for f in findings if f["severity"] == "Critical"),
        "high":     sum(1 for f in findings if f["severity"] == "High"),
        "medium":   sum(1 for f in findings if f["severity"] == "Medium")
    },
    "findings": findings
}

latest_path = os.path.join(report_dir, "latest-result.json")
history_path = os.path.join(report_dir, "history", timestamp.replace(":", "-") + ".json")

with open(latest_path, "w") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

with open(history_path, "w") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

print(f"  저장 완료: {latest_path}")
EOF
