#!/usr/bin/env bash
# tests/test_services.sh — tests du module services
# Propriétaire : Mamadou
#
# Principe : on rejoue une liste de services actifs figée
# (AUDIT_SERVICES_LIST_CMD) contre une denylist contrôlée, on lance l'audit,
# on vérifie la détection.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# shellcheck source=../scripts/lib/common.sh
. scripts/lib/common.sh
# shellcheck source=/dev/null
. scripts/lib/services.sh

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

# Fixture au format `systemctl list-units ... --no-legend --plain` :
# unit load active sub description
write_units_fixture() {
    printf '%s\n' "$1" > "$SANDBOX/units.out"
    printf 'cat %q' "$SANDBOX/units.out"
}

write_denylist() {
    printf '%s\n' "$1" > "$SANDBOX/denylist.conf"
    printf '%s' "$SANDBOX/denylist.conf"
}

echo "== 1. aucun service interdit actif -> PASS ==============================="
new_sandbox
UNITS_CMD=$(write_units_fixture 'sshd.service loaded active running OpenSSH server')
DENYLIST=$(write_denylist 'telnet')

out=$(AUDIT_SERVICES_DENYLIST="$DENYLIST" AUDIT_SERVICES_LIST_CMD="$UNITS_CMD" audit_services 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"status":"FAIL"'; then
    ko "sshd (non interdit) a déclenché un FAIL"
else
    ok "sshd (non interdit) ne déclenche pas de FAIL"
fi
if printf '%s\n' "$out" | grep -q '"check":"disallowed_service_running".*"status":"PASS"'; then
    ok "PASS émis quand rien d'interdit ne tourne"
else
    ko "le PASS attendu est absent"
fi

echo "== 2. service interdit actif -> FAIL/high ================================"
new_sandbox
UNITS_CMD=$(write_units_fixture 'telnet.service loaded active running Telnet server')
DENYLIST=$(write_denylist 'telnet')

out=$(AUDIT_SERVICES_DENYLIST="$DENYLIST" AUDIT_SERVICES_LIST_CMD="$UNITS_CMD" audit_services 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"disallowed_service_running".*"status":"FAIL".*"severity":"high"'; then
    ok "telnet actif est détecté en FAIL/high"
else
    ko "telnet actif n'a pas été détecté"
fi
if printf '%s\n' "$out" | grep -q '"resource":"telnet"'; then
    ok "la resource pointe bien vers 'telnet' (suffixe .service retiré)"
else
    ko "la resource ne pointe pas vers le bon service"
fi

echo "== 3. plusieurs services interdits actifs -> plusieurs FAIL ============="
new_sandbox
UNITS_CMD=$(write_units_fixture 'telnet.service loaded active running Telnet server
rsh.service loaded active running Remote shell')
DENYLIST=$(write_denylist 'telnet
rsh')

out=$(AUDIT_SERVICES_DENYLIST="$DENYLIST" AUDIT_SERVICES_LIST_CMD="$UNITS_CMD" audit_services 2>/dev/null)

count=$(printf '%s\n' "$out" | grep -c '"status":"FAIL"')
if [ "$count" -eq 2 ]; then
    ok "les deux services interdits (telnet, rsh) sont chacun signalés"
else
    ko "attendu 2 FAIL, obtenu $count"
fi

echo "== 4. toute la sortie du module respecte le contrat JSON du groupe ======"
new_sandbox
UNITS_CMD=$(write_units_fixture 'telnet.service loaded active running Telnet server')
DENYLIST=$(write_denylist 'telnet')

out=$(AUDIT_SERVICES_DENYLIST="$DENYLIST" AUDIT_SERVICES_LIST_CMD="$UNITS_CMD" audit_services 2>/dev/null)

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
    echo "services.sh : TOUS LES TESTS PASSENT ✅"
else
    echo "services.sh : DES TESTS ONT ÉCHOUÉ ❌"
fi
exit "$FAILED"
