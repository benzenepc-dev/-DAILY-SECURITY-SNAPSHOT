#!/usr/bin/env bash
# tests/test_permissions.sh — tests du module permissions
# Propriétaire : Daniel
#
# Principe : on crée une situation volontairement vulnérable dans un bac à
# sable, on lance l'audit, on vérifie qu'il la détecte. Puis on nettoie.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# shellcheck source=../scripts/lib/common.sh
. scripts/lib/common.sh
# shellcheck source=/dev/null
. scripts/lib/permissions.sh

FAILED=0
ok() { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
ko() { printf '  \033[31mKO\033[0m   %s\n' "$1"; FAILED=1; }

VALIDATOR="python3 tests/validate_finding.py"

# Un bac à sable neuf par test, toujours nettoyé même en cas d'échec.
SANDBOX=""
cleanup() { [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

new_sandbox() {
    cleanup
    SANDBOX="$(mktemp -d)"
}

# Allowlist SUID vide par défaut : rien n'est jamais "attendu" dans le bac à
# sable, sauf si un test la remplit explicitement.
empty_allowlist() {
    local f
    f="$(mktemp)"
    printf '' > "$f"
    printf '%s' "$f"
}

echo "== 1. fichier world-writable détecté ==================================="
new_sandbox
touch "$SANDBOX/insecure.conf"
chmod 777 "$SANDBOX/insecure.conf"
mkdir -p "$SANDBOX/sub"
touch "$SANDBOX/sub/clean.txt"
chmod 644 "$SANDBOX/sub/clean.txt"

ALLOWLIST="$(empty_allowlist)"
out=$(AUDIT_ROOT="$SANDBOX" AUDIT_SUID_ALLOWLIST="$ALLOWLIST" audit_permissions 2>/dev/null)
rm -f "$ALLOWLIST"

if printf '%s\n' "$out" | grep -q '"check":"world_writable_file".*"status":"FAIL".*"severity":"high"'; then
    ok "le fichier 777 est détecté en FAIL/high"
else
    ko "le fichier 777 n'a pas été détecté (ou mal classé)"
fi

if printf '%s\n' "$out" | grep -q "$SANDBOX/insecure.conf"; then
    ok "la resource pointe bien vers le bon fichier"
else
    ko "la resource ne pointe pas vers insecure.conf"
fi

if printf '%s\n' "$out" | grep -q '"resource":"'"$SANDBOX/sub/clean.txt"'"'; then
    ko "clean.txt (644) n'aurait pas dû remonter"
else
    ok "clean.txt (644) n'est pas remonté"
fi

echo "== 2. bac à sable propre -> PASS ========================================"
new_sandbox
touch "$SANDBOX/normal.txt"
chmod 644 "$SANDBOX/normal.txt"

ALLOWLIST="$(empty_allowlist)"
out=$(AUDIT_ROOT="$SANDBOX" AUDIT_SUID_ALLOWLIST="$ALLOWLIST" audit_permissions 2>/dev/null)
rm -f "$ALLOWLIST"

if printf '%s\n' "$out" | grep -q '"check":"world_writable_file".*"status":"PASS"'; then
    ok "aucun fichier world-writable -> PASS émis"
else
    ko "le PASS world_writable_file est absent quand tout est propre"
fi

echo "== 3. binaire SUID hors liste blanche -> FAIL ==========================="
new_sandbox
BIN="$SANDBOX/fake-suid-binary"
printf '#!/bin/sh\necho hi\n' > "$BIN"
chmod 4755 "$BIN"

ALLOWLIST="$(empty_allowlist)"
out=$(AUDIT_ROOT="$SANDBOX" AUDIT_SUID_ALLOWLIST="$ALLOWLIST" audit_permissions 2>/dev/null)
rm -f "$ALLOWLIST"

if printf '%s\n' "$out" | grep -q '"check":"unexpected_suid_sgid_binary".*"status":"FAIL".*"severity":"high"'; then
    ok "le binaire SUID inconnu est détecté en FAIL/high"
else
    ko "le binaire SUID inconnu n'a pas été détecté"
fi

echo "== 4. binaire SUID présent dans la liste blanche -> pas de FAIL ========="
new_sandbox
BIN="$SANDBOX/known-suid-binary"
printf '#!/bin/sh\necho hi\n' > "$BIN"
chmod 4755 "$BIN"

ALLOWLIST="$(mktemp)"
printf '%s\n' "$BIN" > "$ALLOWLIST"
out=$(AUDIT_ROOT="$SANDBOX" AUDIT_SUID_ALLOWLIST="$ALLOWLIST" audit_permissions 2>/dev/null)
rm -f "$ALLOWLIST"

if printf '%s\n' "$out" | grep -q '"check":"unexpected_suid_sgid_binary".*"status":"FAIL"'; then
    ko "un binaire pourtant listé dans l'allowlist a déclenché un FAIL"
else
    ok "le binaire listé dans l'allowlist ne déclenche pas de FAIL"
fi

echo "== 5. AUDIT_EXCLUDE_PATHS est respecté =================================="
new_sandbox
mkdir -p "$SANDBOX/excluded"
touch "$SANDBOX/excluded/should-not-appear.conf"
chmod 777 "$SANDBOX/excluded/should-not-appear.conf"

ALLOWLIST="$(empty_allowlist)"
out=$(AUDIT_ROOT="$SANDBOX" AUDIT_SUID_ALLOWLIST="$ALLOWLIST" \
      AUDIT_EXCLUDE_PATHS="$SANDBOX/excluded" audit_permissions 2>/dev/null)
rm -f "$ALLOWLIST"

if printf '%s\n' "$out" | grep -q "should-not-appear.conf"; then
    ko "un chemin listé dans AUDIT_EXCLUDE_PATHS a quand même été scanné"
else
    ok "AUDIT_EXCLUDE_PATHS empêche bien le scan du dossier exclu"
fi

echo "== 6. toute la sortie du module respecte le contrat JSON du groupe ======"
new_sandbox
touch "$SANDBOX/insecure2.conf"
chmod 777 "$SANDBOX/insecure2.conf"

ALLOWLIST="$(empty_allowlist)"
out=$(AUDIT_ROOT="$SANDBOX" AUDIT_SUID_ALLOWLIST="$ALLOWLIST" audit_permissions 2>/dev/null)
rm -f "$ALLOWLIST"

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
    echo "permissions.sh : TOUS LES TESTS PASSENT ✅"
else
    echo "permissions.sh : DES TESTS ONT ÉCHOUÉ ❌"
fi
exit "$FAILED"
