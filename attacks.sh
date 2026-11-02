#!/usr/bin/env bash
# attacks.sh - runs the same attack set against DVWA at every stage of the project
# and saves the results as evidence. Only run it against YOUR OWN lab deployment.
#
# Usage:
#   bash attacks.sh <stage> <target-url> [--sqlmap]
#
#   stage       evidence folder: 00-baseline | 01-private-subnets | 02-https | 03-waf | 04-secrets | 05-logging
#   target-url  e.g. http://13.217.38.98   (later: https://<alb-dns>)
#   --sqlmap    also run a short sqlmap scan (slow, run it once per stage)
#
# Optional environment variables (needed for the database tests):
#   DB_HOST   RDS endpoint           (terraform output rds_endpoint)
#   DB_USER   default: dvwa
#   DB_PASS   default: Password123
#   HTTP_URL  plain-HTTP URL of the same app, to test the HTTP->HTTPS redirect (layer 2+)
#   TASKDEF   ECS task definition family, default: dvwa-baseline-task
#
# Not automated: the cleartext-credentials proof. Capture it in Wireshark while you log in.
set -uo pipefail

STAGE="${1:-}"; TARGET="${2:-}"; RUN_SQLMAP="${3:-}"
if [[ -z "$STAGE" || -z "$TARGET" ]]; then
  sed -n '2,20p' "$0"; exit 1
fi
TARGET="${TARGET%/}"

DB_USER="${DB_USER:-dvwa}"
DB_PASS="${DB_PASS:-Password123}"
TASKDEF="${TASKDEF:-dvwa-baseline-task}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/evidence/$STAGE"
mkdir -p "$OUT"
JAR="$(mktemp)"; trap 'rm -f "$JAR"' EXIT
CURL=(curl -sk --max-time 20 -b "$JAR" -c "$JAR")
REPORT="$OUT/attacks-result.txt"
: > "$REPORT"

say()    { printf '%s\n' "$*" | tee -a "$REPORT"; }
result() { # <name> <ATTACK SUCCEEDED|BLOCKED|INCONCLUSIVE> <detail>
  printf '%-34s %-18s %s\n' "$1" "$2" "$3" | tee -a "$REPORT"; }

say "attacks.sh | stage=$STAGE | target=$TARGET | $(date -u +%FT%TZ)"
say "-----------------------------------------------------------------------------"

# ---- 0. reachability --------------------------------------------------------
code="$("${CURL[@]}" -o /dev/null -w '%{http_code}' "$TARGET/login.php")"
if [[ "$code" == "000" ]]; then
  result "0 Reachability" "UNREACHABLE" "no answer from $TARGET (check IP / security group / task running)"
  exit 2
fi
result "0 Reachability" "OK" "HTTP $code from $TARGET/login.php"

# ---- login (DVWA needs a CSRF token) ---------------------------------------
token="$("${CURL[@]}" "$TARGET/login.php" | grep -o "user_token' value='[^']*" | head -1 | cut -d"'" -f3)"
"${CURL[@]}" -o /dev/null -d "username=admin&password=password&Login=Login&user_token=$token" "$TARGET/login.php"

# security level: the cookie is what DVWA reads
token="$("${CURL[@]}" "$TARGET/security.php" | grep -o "user_token' value='[^']*" | head -1 | cut -d"'" -f3)"
"${CURL[@]}" -o /dev/null -d "security=low&seclev_submit=Submit&user_token=$token" "$TARGET/security.php"
echo -e "$(echo "$TARGET" | sed -E 's#https?://##; s#[:/].*##')\tFALSE\t/\tFALSE\t0\tsecurity\tlow" >> "$JAR"

page="$("${CURL[@]}" "$TARGET/index.php")"
if ! grep -q "Logout" <<<"$page"; then
  result "1 Login (admin/password)" "FAILED" "could not log in. If a WAF is active this can be a block (see 403 below); else run /setup.php first."
  code="$("${CURL[@]}" -o /dev/null -w '%{http_code}' "$TARGET/login.php")"; say "   login page status: $code"
  exit 3
fi
result "1 Login (admin/password)" "OK" "logged in, security=low"
SESSION="$(awk '$6=="PHPSESSID"{print $7}' "$JAR" | tail -1)"

# ---- 2. SQL injection --------------------------------------------------------
body="$("${CURL[@]}" -w '\nHTTP_STATUS:%{http_code}' --get --data-urlencode "id=1' OR '1'='1" --data-urlencode "Submit=Submit" "$TARGET/vulnerabilities/sqli/")"
status="$(grep -o 'HTTP_STATUS:[0-9]*' <<<"$body" | cut -d: -f2)"
rows="$(grep -o 'First name' <<<"$body" | wc -l)"
printf '%s\n' "$body" > "$OUT/sqli-response.html"
if [[ "$status" == "403" ]]; then
  result "2 SQL injection (1' OR '1'='1)" "BLOCKED" "HTTP 403"
elif (( rows > 1 )); then
  result "2 SQL injection (1' OR '1'='1)" "ATTACK SUCCEEDED" "HTTP $status, $rows user rows dumped"
else
  result "2 SQL injection (1' OR '1'='1)" "INCONCLUSIVE" "HTTP $status, $rows rows (is the level Low? is the DB set up?)"
fi

# ---- 3. Reflected XSS --------------------------------------------------------
payload='<script>alert(1)</script>'
body="$("${CURL[@]}" -w '\nHTTP_STATUS:%{http_code}' --get --data-urlencode "name=$payload" "$TARGET/vulnerabilities/xss_r/")"
status="$(grep -o 'HTTP_STATUS:[0-9]*' <<<"$body" | cut -d: -f2)"
printf '%s\n' "$body" > "$OUT/xss-response.html"
if [[ "$status" == "403" ]]; then
  result "3 Reflected XSS (<script>)" "BLOCKED" "HTTP 403"
elif grep -qF "$payload" <<<"$body"; then
  result "3 Reflected XSS (<script>)" "ATTACK SUCCEEDED" "HTTP $status, payload reflected unescaped"
else
  result "3 Reflected XSS (<script>)" "INCONCLUSIVE" "HTTP $status, payload not found in response"
fi

# ---- 4. Direct database access from the internet ----------------------------
if [[ -n "${DB_HOST:-}" ]] && command -v mysql >/dev/null; then
  if out="$(timeout 12 mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" --connect-timeout=8 -e 'SELECT user(), version();' 2>&1)"; then
    result "4 Direct DB access (3306)" "ATTACK SUCCEEDED" "connected from the internet: $(tail -1 <<<"$out" | tr '\t' ' ')"
  else
    result "4 Direct DB access (3306)" "BLOCKED" "$(head -1 <<<"$out" | cut -c1-90)"
  fi
  printf '%s\n' "$out" > "$OUT/db-direct.txt"
else
  result "4 Direct DB access (3306)" "SKIPPED" "set DB_HOST=<rds endpoint> and install the mysql client"
fi

# ---- 5. HTTP -> HTTPS (layer 2 onwards) -------------------------------------
if [[ -n "${HTTP_URL:-}" ]]; then
  h="$(curl -sk --max-time 15 -o /dev/null -w '%{http_code} %{redirect_url}' "${HTTP_URL%/}/login.php")"
  if [[ "$h" == 301* || "$h" == 302* || "$h" == 308* ]]; then
    result "5 Plain HTTP request" "REDIRECTED" "$h"
  else
    result "5 Plain HTTP request" "ATTACK SUCCEEDED" "served over HTTP: $h"
  fi
else
  result "5 Plain HTTP request" "SKIPPED" "set HTTP_URL=http://<host> (only meaningful from layer 2)"
fi

# ---- 6. Secrets visible in the task definition ------------------------------
if command -v aws >/dev/null && td="$(aws ecs describe-task-definition --task-definition "$TASKDEF" --query 'taskDefinition.containerDefinitions[0]' --output json 2>/dev/null)"; then
  printf '%s\n' "$td" > "$OUT/taskdef-containerdef.json"
  if jq -e '.environment[]? | select(.name=="DB_PASSWORD")' <<<"$td" >/dev/null; then
    pw="$(jq -r '.environment[] | select(.name=="DB_PASSWORD") | .value' <<<"$td")"
    result "6 Secret in task definition" "ATTACK SUCCEEDED" "DB_PASSWORD in plaintext: $pw"
  elif jq -e '.secrets[]? | select(.name=="DB_PASSWORD")' <<<"$td" >/dev/null; then
    result "6 Secret in task definition" "BLOCKED" "only a Secrets Manager reference is visible"
  else
    result "6 Secret in task definition" "INCONCLUSIVE" "no DB_PASSWORD found in $TASKDEF"
  fi
else
  result "6 Secret in task definition" "SKIPPED" "aws cli / credentials / TASKDEF=$TASKDEF not available"
fi

# ---- 7. sqlmap (optional, once per stage) -----------------------------------
if [[ "$RUN_SQLMAP" == "--sqlmap" ]]; then
  if command -v sqlmap >/dev/null; then
    say "   running sqlmap (limited: level 1, risk 1, 1 thread) ..."
    timeout 600 sqlmap -u "$TARGET/vulnerabilities/sqli/?id=1&Submit=Submit" \
      --cookie="PHPSESSID=$SESSION; security=low" --batch --dbs --level=1 --risk=1 \
      --threads=1 --delay=1 --flush-session --output-dir="$OUT/sqlmap" >"$OUT/sqlmap.txt" 2>&1
    if grep -q "available databases" "$OUT/sqlmap.txt"; then
      result "7 sqlmap" "ATTACK SUCCEEDED" "databases enumerated (see sqlmap.txt)"
    elif grep -qiE "403|forbidden|WAF/IPS" "$OUT/sqlmap.txt"; then
      result "7 sqlmap" "BLOCKED" "403 / WAF detected (see sqlmap.txt)"
    else
      result "7 sqlmap" "INCONCLUSIVE" "see sqlmap.txt"
    fi
  else
    result "7 sqlmap" "SKIPPED" "sqlmap not installed"
  fi
fi

say "-----------------------------------------------------------------------------"
say "Saved to $REPORT"
say "Manual proof still needed: Wireshark capture of the login (cleartext on HTTP, TLS only from layer 2)."
