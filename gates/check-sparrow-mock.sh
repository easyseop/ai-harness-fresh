#!/usr/bin/env bash
# Mock SAST 스캐너
# 스패로우/CWE/소프트웨어 보안약점 진단가이드 기반 정규식 패턴 탐지
#
# Output: RULE_ID|SEVERITY|FILE|LINE|MESSAGE (pipe-delimited, one per line)
# 향후 실제 Sparrow CLI로 대체 시 이 파일만 교체

TARGET="${1:-.}"
MODE="${2:---full}"  # --fast: Critical만 / --full: 전체

scan_file() {
  local file="$1"

  # MOCK-SPW-001 [Critical] 하드코딩 비밀정보 — CWE-798
  grep -nEi "(password|passwd|secret|api_key|apikey|token|credential)\s*=\s*['\"][^'\"]{4,}" "$file" 2>/dev/null \
    | while IFS=: read -r line _; do
        echo "MOCK-SPW-001|Critical|$file|$line|하드코딩된 비밀정보 감지 (CWE-798)"
      done

  [ "$MODE" = "--fast" ] && return

  # MOCK-SPW-002 [High] 약한 암호화 알고리즘 — CWE-327
  grep -nE "(hashlib\.md5|hashlib\.sha1|MD5\(|SHA1\(|Cipher\.DES|DES\.new|RC4)" "$file" 2>/dev/null \
    | while IFS=: read -r line _; do
        echo "MOCK-SPW-002|High|$file|$line|약한 암호화 알고리즘 사용 (CWE-327)"
      done

  # MOCK-SPW-003 [High] SQL Injection — CWE-89
  grep -nE "(\"|\')?\s*(SELECT|INSERT|UPDATE|DELETE).*(\+|\.format\(|f\")" "$file" 2>/dev/null \
    | while IFS=: read -r line _; do
        echo "MOCK-SPW-003|High|$file|$line|SQL 문자열 직접 조립 감지 (CWE-89)"
      done

  # MOCK-SPW-004 [High] 위험한 명령 실행 — CWE-78
  grep -nE "(os\.system\(|subprocess\.(call|run|Popen).*shell\s*=\s*True|eval\(|exec\(|Runtime\.exec\()" "$file" 2>/dev/null \
    | while IFS=: read -r line _; do
        echo "MOCK-SPW-004|High|$file|$line|위험한 명령 실행 패턴 (CWE-78)"
      done

  # MOCK-SPW-005 [Medium] 민감정보 로그 출력 — CWE-532
  grep -nEi "(log\.|logger\.|print\(|console\.log).*\b(password|passwd|token|secret|ssn|주민)\b" "$file" 2>/dev/null \
    | while IFS=: read -r line _; do
        echo "MOCK-SPW-005|Medium|$file|$line|민감정보 로그 출력 감지 (CWE-532)"
      done
}

find "$TARGET" -type f \( \
  -name "*.py" -o -name "*.js" -o -name "*.ts" -o \
  -name "*.java" -o -name "*.go" -o -name "*.php" \
\) \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/vendor/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/dist/*" \
| while read -r file; do
    scan_file "$file"
  done
