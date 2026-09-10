#!/usr/bin/env bash
# tests/test_firewall.sh — tests du module firewall
# Propriétaire : Mamadou
#
# Principe : on rejoue une sortie `ufw status` figée (AUDIT_FIREWALL_STATUS_CMD),
# on lance l'audit, on vérifie la détection. Puis on nettoie.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# shellcheck source=../scripts/lib/common.sh
. scripts/lib/common.sh
# shellcheck source=/dev/null
. scripts/lib/firewall.sh

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

write_status_fixture() {
    printf '%s\n' "$1" > "$SANDBOX/ufw.out"
    printf 'cat %q' "$SANDBOX/ufw.out"
}

echo "== 1. pare-feu actif -> PASS =============================================="
new_sandbox
CMD=$(write_status_fixture 'Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere')

out=$(AUDIT_FIREWALL_STATUS_CMD="$CMD" audit_firewall 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"firewall_disabled".*"status":"PASS"'; then
    ok "ufw actif -> PASS"
else
    ko "ufw actif aurait dû produire un PASS"
fi

echo "== 2. pare-feu inactif -> FAIL/critical ==================================="
new_sandbox
CMD=$(write_status_fixture 'Status: inactive')

out=$(AUDIT_FIREWALL_STATUS_CMD="$CMD" audit_firewall 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"firewall_disabled".*"status":"FAIL".*"severity":"critical"'; then
    ok "ufw inactif détecté en FAIL/critical"
else
    ko "ufw inactif n'a pas été détecté"
fi

echo "== 3. commande absente (ufw non installé) -> FAIL ========================="
new_sandbox

out=$(AUDIT_FIREWALL_STATUS_CMD="commande-qui-nexiste-pas" audit_firewall 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"firewall_disabled".*"status":"FAIL"'; then
    ok "ufw absent traité comme pare-feu désactivé -> FAIL"
else
    ko "l'absence d'ufw aurait dû être traitée comme un FAIL"
fi

echo "== 4. toute la sortie du module respecte le contrat JSON du groupe ======"
new_sandbox
CMD=$(write_status_fixture 'Status: inactive')

out=$(AUDIT_FIREWALL_STATUS_CMD="$CMD" audit_firewall 2>/dev/null)

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
    echo "firewall.sh : TOUS LES TESTS PASSENT ✅"
else
    echo "firewall.sh : DES TESTS ONT ÉCHOUÉ ❌"
fi
exit "$FAILED"
