#!/usr/bin/env bash
# tests/test_users.sh — tests du module users
# Propriétaire : Vincent
#
# Principe : on rejoue un fichier passwd figé (AUDIT_PASSWD_FILE), on lance
# l'audit, on vérifie qu'il détecte les comptes UID 0 en trop. Puis on nettoie.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# shellcheck source=../scripts/lib/common.sh
. scripts/lib/common.sh
# shellcheck source=/dev/null
. scripts/lib/users.sh

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

write_passwd() {
    printf '%s\n' "$1" > "$SANDBOX/passwd"
    printf '%s' "$SANDBOX/passwd"
}

echo "== 1. seul root en UID 0 -> PASS =========================================="
new_sandbox
PASSWD=$(write_passwd 'root:x:0:0:root:/root:/bin/bash
demo:x:1000:1000:Demo User:/home/demo:/bin/bash')

out=$(AUDIT_PASSWD_FILE="$PASSWD" audit_users 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"status":"FAIL"'; then
    ko "aucun compte UID 0 en trop, pourtant un FAIL a été émis"
else
    ok "aucun FAIL quand seul root a l'UID 0"
fi
if printf '%s\n' "$out" | grep -q '"check":"unexpected_uid_zero_account".*"status":"PASS"'; then
    ok "PASS émis quand /etc/passwd est sain"
else
    ko "le PASS attendu est absent"
fi

echo "== 2. compte UID 0 en trop -> FAIL/critical ==============================="
new_sandbox
PASSWD=$(write_passwd 'root:x:0:0:root:/root:/bin/bash
backdoor:x:0:0:Backdoor:/home/backdoor:/bin/bash')

out=$(AUDIT_PASSWD_FILE="$PASSWD" audit_users 2>/dev/null)

if printf '%s\n' "$out" | grep -q '"check":"unexpected_uid_zero_account".*"status":"FAIL".*"severity":"critical"'; then
    ok "le compte 'backdoor' en UID 0 est détecté en FAIL/critical"
else
    ko "le compte 'backdoor' en UID 0 n'a pas été détecté"
fi
if printf '%s\n' "$out" | grep -q '"resource":"backdoor"'; then
    ok "la resource pointe bien vers le compte 'backdoor'"
else
    ko "la resource ne pointe pas vers le bon compte"
fi

echo "== 3. plusieurs comptes UID 0 en trop -> un FAIL par compte ==============="
new_sandbox
PASSWD=$(write_passwd 'root:x:0:0:root:/root:/bin/bash
backdoor1:x:0:0:B1:/home/b1:/bin/bash
backdoor2:x:0:0:B2:/home/b2:/bin/bash')

out=$(AUDIT_PASSWD_FILE="$PASSWD" audit_users 2>/dev/null)

count=$(printf '%s\n' "$out" | grep -c '"status":"FAIL"')
if [ "$count" -eq 2 ]; then
    ok "les deux comptes en trop (backdoor1, backdoor2) sont chacun signalés"
else
    ko "attendu 2 FAIL, obtenu $count"
fi

echo "== 4. toute la sortie du module respecte le contrat JSON du groupe ========"
new_sandbox
PASSWD=$(write_passwd 'root:x:0:0:root:/root:/bin/bash
backdoor:x:0:0:Backdoor:/home/backdoor:/bin/bash')

out=$(AUDIT_PASSWD_FILE="$PASSWD" audit_users 2>/dev/null)

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
    echo "users.sh : TOUS LES TESTS PASSENT ✅"
else
    echo "users.sh : DES TESTS ONT ÉCHOUÉ ❌"
fi
exit "$FAILED"
