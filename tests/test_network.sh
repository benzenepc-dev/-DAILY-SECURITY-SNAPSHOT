#!/usr/bin/env bash
# tests/test_network.sh — tests du module network
# Propriétaire : Mamadou
#
# Principe : on rejoue une sortie `ss` figée (AUDIT_NETWORK_SS_CMD) contre une
# allowlist de ports contrôlée, on lance l'audit, on vérifie la détection.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# shellcheck source=../scripts/lib/common.sh
. scripts/lib/common.sh
# shellcheck source=/dev/null
. scripts/lib/network.sh

FAILED=0
ok() { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
ko() { printf '  \033[31mKO\033[0m   %s\n' "$1"; FAILED=1; }

VALIDATOR="python3 tests/validate_finding.py"

SANDBOX=""
cleanup() { [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

new_sandbox() {
    cleanup
    SANDBOX="$(mktemp -d)"
}

# Fixture au format `ss -Htuln` : Netid State Recv-Q Send-Q Local:Port Peer:Port
write_ss_fixture() {
    printf '%s\n' "$1" > "$SANDBOX/ss.out"
    printf 'cat %q' "$SANDBOX/ss.out"
}

write_allowlist() {
    printf '%s\n' "$1" > "$SANDBOX/allowed_ports.conf"
    printf '%s' "$SANDBOX/allowed_ports.conf"
}

echo "== 1. port autorisé -> pas de FAIL, PASS émis ==========================="
new_sandbox
SS_CMD=$(write_ss_fixture 'tcp   LISTEN  0  128  0.0.0.0:22   0.0.0.0:*')
ALLOWLIST=$(write_allowlist '22 tcp SSH')

out=$(AUDIT_PORTS_ALLOWLIST="$ALLOWLIST" AUDIT_NETWORK_SS_CMD="$SS_CMD" audit_network 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"status":"FAIL"'; then
    ko "un port pourtant autorisé (22/tcp) a déclenché un FAIL"
else
    ok "le port autorisé (22/tcp) ne déclenche pas de FAIL"
fi
if printf '%s\n' "$out" | grep -q '"check":"unexpected_listening_port".*"status":"PASS"'; then
    ok "PASS émis quand rien d'inattendu n'écoute"
else
    ko "le PASS attendu est absent"
fi

echo "== 2. port non autorisé -> FAIL/critical ================================"
new_sandbox
SS_CMD=$(write_ss_fixture 'tcp   LISTEN  0  128  0.0.0.0:4444   0.0.0.0:*')
ALLOWLIST=$(write_allowlist '22 tcp SSH')

out=$(AUDIT_PORTS_ALLOWLIST="$ALLOWLIST" AUDIT_NETWORK_SS_CMD="$SS_CMD" audit_network 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"unexpected_listening_port".*"status":"FAIL".*"severity":"critical"'; then
    ok "le port 4444/tcp inattendu est détecté en FAIL/critical"
else
    ko "le port 4444/tcp inattendu n'a pas été détecté"
fi
if printf '%s\n' "$out" | grep -q '"resource":"0.0.0.0:4444"'; then
    ok "la resource pointe bien vers 0.0.0.0:4444"
else
    ko "la resource ne pointe pas vers le bon socket"
fi

echo "== 3. même port, protocole différent -> toujours en FAIL ================"
new_sandbox
SS_CMD=$(write_ss_fixture 'udp   UNCONN  0  0  0.0.0.0:22   0.0.0.0:*')
ALLOWLIST=$(write_allowlist '22 tcp SSH')

out=$(AUDIT_PORTS_ALLOWLIST="$ALLOWLIST" AUDIT_NETWORK_SS_CMD="$SS_CMD" audit_network 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"unexpected_listening_port".*"status":"FAIL"'; then
    ok "22/udp n'est pas couvert par l'autorisation 22/tcp -> FAIL"
else
    ko "22/udp aurait dû être en FAIL (seul 22/tcp est autorisé)"
fi

echo "== 4. lignes non tcp/udp ignorées (pas de crash) ========================"
new_sandbox
SS_CMD=$(write_ss_fixture 'raw   UNCONN  0  0  *:*   *:*')
ALLOWLIST=$(write_allowlist '22 tcp SSH')

out=$(AUDIT_PORTS_ALLOWLIST="$ALLOWLIST" AUDIT_NETWORK_SS_CMD="$SS_CMD" audit_network 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"unexpected_listening_port".*"status":"PASS"'; then
    ok "une ligne raw/non tcp-udp est ignorée sans fausse alerte"
else
    ko "une ligne non tcp/udp a provoqué une sortie inattendue"
fi

echo "== 5. toute la sortie du module respecte le contrat JSON du groupe ======"
new_sandbox
SS_CMD=$(write_ss_fixture 'tcp   LISTEN  0  128  0.0.0.0:4444   0.0.0.0:*')
ALLOWLIST=$(write_allowlist '22 tcp SSH')

out=$(AUDIT_PORTS_ALLOWLIST="$ALLOWLIST" AUDIT_NETWORK_SS_CMD="$SS_CMD" audit_network 2>/dev/null)

if printf '%s\n' "$out" | $VALIDATOR >/dev/null; then
    ok "sortie 100% conforme au contrat (10 clés, valeurs autorisées)"
else
    ko "sortie NON conforme au contrat"
    printf '%s\n' "$out" | $VALIDATOR
fi

cleanup
trap - EXIT

echo
if [ "$FAILED" -eq 0 ]; then
    echo "network.sh : TOUS LES TESTS PASSENT ✅"
else
    echo "network.sh : DES TESTS ONT ÉCHOUÉ ❌"
fi
exit "$FAILED"
