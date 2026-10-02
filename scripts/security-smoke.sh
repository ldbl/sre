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
#
# Run by hand after a deploy (CLAUDE.md lists it with the app security rules). Needs: curl and jq.
# Changes nothing - only GET/POST requests whose answers it inspects. Exit 1 when any check fails.
set -euo pipefail

base_url="${1:?usage: $0 BASE_URL [HOST_HEADER]}"
host_header="${2:-}"
expect_chaos="${EXPECT_CHAOS:-true}"

curl_args=(--silent --show-error --max-time 10)
[[ -n "${host_header}" ]] && curl_args+=(--header "Host: ${host_header}")

failures=0
# pass / fail <message> - print one result line; fail also counts it.
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

# HTTP status of a request; "000" when curl fails (timeout, refused) - reported, never aborting the run.
status_of() { curl "${curl_args[@]}" --output /dev/null --write-out '%{http_code}' "$@" 2>/dev/null || true; }

echo "security smoke: ${base_url}${host_header:+ (Host: ${host_header})}, chaos expected: ${expect_chaos}"

# 1. /api/env answers, and no key or value looks like a secret.
if ! env_body="$(curl "${curl_args[@]}" "${base_url}/api/env")"; then
  fail "/api/env unreachable - not checked"
elif ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"${env_body}"; then
  fail "/api/env did not return a JSON object"
else
  # Key names at any depth (names are not secrets and are printed); values are checked for
  # credentials in a URL (scheme://user[:pass]@host) or a JWT, and only counted - never printed.
  leaked_keys="$(jq -r '[.. | objects | keys[]] | unique[] | select(test("SECRET|PASSWORD|TOKEN|DSN|KEY|HEADERS|CREDENTIAL"; "i"))' <<<"${env_body}")"
  leaked_values="$(jq '[.. | strings | select(test("://[^/@[:space:]]+@|eyJ[A-Za-z0-9_-]+\\.eyJ"))] | length' <<<"${env_body}")"
  if [[ -n "${leaked_keys}" ]]; then
    fail "/api/env exposes secret-looking keys: $(tr '\n' ' ' <<<"${leaked_keys}")"
  elif [[ "${leaked_values}" != "0" ]]; then
    fail "/api/env has ${leaked_values} value(s) that look like credentials (URL userinfo or JWT) - values not shown"
  else
    pass "/api/env has no secret-looking keys or values ($(jq 'length' <<<"${env_body}") keys)"
  fi
fi

# 2. No password-less token endpoint: the route must not exist (404 from nginx, or 404/405 from a
#    backend without it). Anything else - a 2xx, a 401 (the route is back), 000 (curl failed) - fails.
code="$(status_of --request POST --data admin "${base_url}/api/token")"
if [[ "${code}" == "404" || "${code}" == "405" ]]; then pass "POST /api/token -> ${code}"; else fail "POST /api/token -> ${code} (expected 404/405)"; fi

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
# Fail closed: only a 200 from the real endpoint proves anything; a 404/500/redirect without the
# header would otherwise look like a pass.
if ! cors_headers="$(curl "${curl_args[@]}" --dump-header - --output /dev/null --write-out 'HTTP_CODE=%{http_code}' --header 'Origin: https://evil.example' "${base_url}/api/version" 2>&1)"; then
  fail "/api/version request failed - CORS not checked"
elif ! grep -q 'HTTP_CODE=200$' <<<"${cors_headers}"; then
  fail "/api/version -> $(grep -o 'HTTP_CODE=[0-9]*' <<<"${cors_headers}" | cut -d= -f2) (expected 200) - CORS not checked"
elif grep -qi '^access-control-allow-origin: \*' <<<"${cors_headers}"; then
  fail "/api/version sends Access-Control-Allow-Origin: *"
else
  pass "/api/version has no wildcard CORS header"
fi

if ((failures > 0)); then
  echo "security smoke: ${failures} check(s) FAILED"
  exit 1
fi
echo "security smoke: all checks passed"
