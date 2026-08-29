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

# TODO(Daniel) : écrire les cas de test ici.
# Exemple :
#   SANDBOX=$(mktemp -d)
#   touch "$SANDBOX/vuln"; chmod 777 "$SANDBOX/vuln"
#   out=$(AUDIT_ROOT="$SANDBOX" audit_permissions 2>/dev/null)
#   echo "$out" | grep -q world_writable_file || { echo "KO: non détecté"; FAILED=1; }
#   rm -rf "$SANDBOX"

exit "$FAILED"
