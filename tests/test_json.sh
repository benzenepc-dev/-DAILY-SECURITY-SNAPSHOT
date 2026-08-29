#!/usr/bin/env bash
# =============================================================================
#  test_json.sh — VÉRIFIE LE CONTRAT DU GROUPE
#  Propriétaire : Vincent Mactar Senghor (mais tout le monde le fait tourner)
#
#  C'est CE test qui empêche les 5 briques d'être incompatibles à la fin.
#  Il tourne automatiquement sur chaque Pull Request (job « contract »).
#
#  En local :   bash tests/test_json.sh
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# shellcheck source=../scripts/lib/common.sh
. scripts/lib/common.sh

VALIDATOR="python3 tests/validate_finding.py"
command -v python3 >/dev/null 2>&1 || { echo "python3 requis : sudo apt install -y python3"; exit 2; }

FAILED=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
ko()   { printf '  \033[31mKO\033[0m   %s\n' "$1"; FAILED=1; }

echo "== 1. emit_finding produit un JSON conforme =="
if emit_finding permissions world_writable_file FAIL high \
        '/tmp/test.conf' 'World writable file detected' 'chmod o-w /tmp/test.conf' \
        | $VALIDATOR >/dev/null; then
    ok "cas nominal"
else
    ko "cas nominal"
fi

echo "== 2. les caractères spéciaux sont échappés =="
if emit_finding network unexpected_port FAIL critical \
        '0.0.0.0:4444' 'Port "4444" not in allow\list' 'Close the port' \
        | $VALIDATOR >/dev/null; then
    ok "guillemets, antislash et tabulations"
else
    ko "guillemets, antislash et tabulations"
fi

echo "== 3. les valeurs hors contrat sont refusées =="
if emit_finding permissions x FAIL URGENT /tmp m r >/dev/null 2>&1; then
    ko "severity 'URGENT' aurait dû être refusée"
else
    ok "severity invalide rejetée"
fi
if emit_finding permissions x BROKEN high /tmp m r >/dev/null 2>&1; then
    ko "status 'BROKEN' aurait dû être refusé"
else
    ok "status invalide rejeté"
fi
if emit_finding permissions x FAIL high /tmp m >/dev/null 2>&1; then
    ko "un appel à 6 arguments aurait dû être refusé"
else
    ok "nombre d'arguments contrôlé"
fi

echo "== 4. chaque module ne produit que des findings valides sur stdout =="
for m in permissions network users services; do
    # shellcheck source=/dev/null
    . "scripts/lib/$m.sh"
    out=$("audit_$m" 2>/dev/null)
    if [ -z "$out" ]; then
        ok "$m : module encore vide, rien à valider"
    elif printf '%s\n' "$out" | $VALIDATOR >/dev/null; then
        ok "$m : sortie conforme"
    else
        ko "$m : sortie NON conforme (détail ci-dessous)"
        printf '%s\n' "$out" | $VALIDATOR
    fi
done

echo "== 5. les fixtures d'exemple sont conformes =="
shopt -s nullglob
fixtures=(tests/fixtures/*.jsonl)
if [ "${#fixtures[@]}" -eq 0 ]; then
    ok "aucune fixture"
else
    for f in "${fixtures[@]}"; do
        if $VALIDATOR < "$f" >/dev/null; then
            ok "$f"
        else
            ko "$f"
            $VALIDATOR < "$f"
        fi
    done
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "CONTRAT RESPECTÉ ✅  tu peux pousser."
else
    echo "CONTRAT CASSÉ ❌  corrige avant de pousser."
fi
exit "$FAILED"
