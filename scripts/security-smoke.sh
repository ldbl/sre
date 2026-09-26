#!/usr/bin/env bash
# Security smoke test from the outside, through the public path (ingress -> frontend nginx -> /api/).
# Checks what the 2026-09-27 security fixes promise; fails loudly on any regression.
#
#   scripts/security-smoke.sh https://develop.safeops.work                 # Hetzner
#   scripts/security-smoke.sh http://localhost:8080 develop.safeops.work   # kind (Host header)
#   EXPECT_CHAOS=false scripts/security-smoke.sh https://sre.safeops.work  # production: no chaos
#
# EXPECT_CHAOS (default true): with chaos on, /api/panic without a token is 401; with chaos off, 404.
# Never prints response bodies: on a failure they may hold the very secrets this test looks for.
set -euo pipefail

base_url="${1:?usage: $0 BASE_URL [HOST_HEADER]}"
host_header="${2:-}"
expect_chaos="${EXPECT_CHAOS:-true}"

curl_args=(--silent --show-error --max-time 10)
[[ -n "${host_header}" ]] && curl_args+=(--header "Host: ${host_header}")

failures=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

# HTTP status of a request; "000" when curl fails (timeout, refused) - reported, never aborting the run.
status_of() { curl "${curl_args[@]}" --output /dev/null --write-out '%{http_code}' "$@" 2>/dev/null || true; }

echo "security smoke: ${base_url}${host_header:+ (Host: ${host_header})}, chaos expected: ${expect_chaos}"

# 1. /api/env answers, and no key or value looks like a secret.
env_body="$(curl "${curl_args[@]}" "${base_url}/api/env")" || { fail "/api/env unreachable"; env_body='{}'; }
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"${env_body}"; then
  fail "/api/env did not return a JSON object"
else
  leaked_keys="$(jq -r 'keys[] | select(test("SECRET|PASSWORD|TOKEN|DSN|KEY|HEADERS|CREDENTIAL"; "i"))' <<<"${env_body}")"
  if [[ -n "${leaked_keys}" ]]; then
    fail "/api/env exposes secret-looking keys: $(tr '\n' ' ' <<<"${leaked_keys}")"
  else
    pass "/api/env has no secret-looking keys ($(jq 'length' <<<"${env_body}") keys)"
  fi
fi

# 2. No password-less token endpoint.
code="$(status_of --request POST --data admin "${base_url}/api/token")"
if [[ "${code}" == "200" ]]; then fail "POST /api/token issued something (200)"; else pass "POST /api/token -> ${code}"; fi

# 3. No profiling on the public path.
for path in /api/debug/pprof/ /api/debug/pprof/heap /api/debug/pprof/cmdline; do
  code="$(status_of "${base_url}${path}")"
  if [[ "${code}" == "404" ]]; then pass "${path} -> 404"; else fail "${path} -> ${code} (expected 404)"; fi
done

# 4. Chaos endpoints: gone when off, token-protected when on.
code="$(status_of "${base_url}/api/panic")"
if [[ "${expect_chaos}" == "true" ]]; then
  if [[ "${code}" == "401" ]]; then pass "/api/panic without token -> 401"; else fail "/api/panic without token -> ${code} (expected 401)"; fi
else
  if [[ "${code}" == "404" ]]; then pass "/api/panic -> 404 (chaos off)"; else fail "/api/panic -> ${code} (expected 404, chaos off)"; fi
fi

# 5. /delay is bounded.
code="$(status_of "${base_url}/api/delay/99999")"
if [[ "${code}" == "400" ]]; then pass "/api/delay/99999 -> 400"; else fail "/api/delay/99999 -> ${code} (expected 400)"; fi

# 6. The backend no longer answers with a wildcard CORS header.
cors_headers="$(curl "${curl_args[@]}" --dump-header - --output /dev/null --header 'Origin: https://evil.example' "${base_url}/api/version" || true)"
if grep -qi '^access-control-allow-origin: \*' <<<"${cors_headers}"; then
  fail "/api/version sends Access-Control-Allow-Origin: *"
else
  pass "/api/version has no wildcard CORS header"
fi

if ((failures > 0)); then
  echo "security smoke: ${failures} check(s) FAILED"
  exit 1
fi
echo "security smoke: all checks passed"
