#!/usr/bin/env bash
# =============================================================================
#  permissions.sh — audit : permissions, world-writable, SUID/SGID, fichiers sensibles
#  Propriétaire : Diembi Daniel Emmanuel
#
#  RÈGLE : ce fichier n'écrit RIEN sur stdout à part des appels à emit_finding.
#  Toute trace de debug part sur stderr via log_info / log_warn.
#  common.sh est sourcé par security_audit.sh : ne le source pas toi-même.
#
#  Checks produits (audit=permissions) :
#    - world_writable_file           : fichier accessible en écriture par tout le monde
#    - unexpected_suid_sgid_binary   : binaire SUID/SGID hors de config/allowed_suid.conf
#
#  Variables d'environnement reconnues (toutes optionnelles, surchargeables
#  pour les tests) :
#    AUDIT_ROOT             racine du scan (défaut : /)
#    AUDIT_EXCLUDE_PATHS    chemins à ne pas parcourir, séparés par des espaces
#                           (défini dans config/audit.conf, propriété de Vincent)
#    AUDIT_STAY_ON_FS       si non vide, n'entre pas dans les autres points de
#                           montage (équivalent find -xdev)
#    AUDIT_SUID_ALLOWLIST   chemin du fichier d'autorisation SUID/SGID
#                           (défaut : config/allowed_suid.conf du projet)
# =============================================================================

# Répertoire réel de ce fichier, pour retrouver config/allowed_suid.conf
# quelle que soit la façon dont le projet est copié/installé (cf install.sh).
_PERMISSIONS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PERMISSIONS_DEFAULT_ALLOWLIST="$_PERMISSIONS_LIB_DIR/../../config/allowed_suid.conf"

# ── Contrôle 1 : fichiers world-writable ─────────────────────────────────────
_permissions_check_world_writable() {
    local root="${AUDIT_ROOT:-/}"
    local -a prune_args=()
    local p

    for p in ${AUDIT_EXCLUDE_PATHS:-}; do
        prune_args+=(-path "$p" -prune -o)
    done

    local found=0
    local f

    while IFS= read -r -d '' f; do
        found=1
        emit_finding "permissions" "world_writable_file" "FAIL" "high" \
            "$f" "World writable file detected" \
            "Remove write permission for others: chmod o-w \"$f\""
    done < <(find "$root" ${AUDIT_STAY_ON_FS:+-xdev} "${prune_args[@]}" \
                -type f -perm -0002 -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        emit_finding "permissions" "world_writable_file" "PASS" "info" \
            "$root" "No world writable file found" "None"
    fi
}

# ── Contrôle 2 : binaires SUID/SGID hors liste blanche ───────────────────────

# Le chemin donné en $1 est-il présent, tel quel, dans le fichier d'allowlist $2 ?
# (une ligne par chemin absolu, '#' pour les commentaires, comme
#  config/allowed_ports.conf)
_permissions_is_allowed_suid() {
    local target="$1" allowlist="$2" line

    [ -r "$allowlist" ] || return 1

    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        [ "$line" = "$target" ] && return 0
    done < "$allowlist"

    return 1
}

_permissions_check_suid_sgid() {
    local root="${AUDIT_ROOT:-/}"
    local allowlist="${AUDIT_SUID_ALLOWLIST:-$_PERMISSIONS_DEFAULT_ALLOWLIST}"
    local -a prune_args=()
    local p

    for p in ${AUDIT_EXCLUDE_PATHS:-}; do
        prune_args+=(-path "$p" -prune -o)
    done

    local unexpected=0
    local f

    while IFS= read -r -d '' f; do
        _permissions_is_allowed_suid "$f" "$allowlist" && continue
        unexpected=1
        emit_finding "permissions" "unexpected_suid_sgid_binary" "FAIL" "high" \
            "$f" "Unexpected SUID/SGID binary detected" \
            "Confirm the binary is legitimate; otherwise remove the SUID/SGID bit (chmod u-s,g-s \"$f\") or add it to config/allowed_suid.conf"
    done < <(find "$root" ${AUDIT_STAY_ON_FS:+-xdev} "${prune_args[@]}" \
                -type f \( -perm -4000 -o -perm -2000 \) -print0 2>/dev/null)

    if [ "$unexpected" -eq 0 ]; then
        emit_finding "permissions" "unexpected_suid_sgid_binary" "PASS" "info" \
            "$root" "No unexpected SUID/SGID binary found" "None"
    fi
}

# ── Point d'entrée appelé par security_audit.sh ──────────────────────────────
audit_permissions() {
    log_info "audit permissions : démarrage"

    _permissions_check_world_writable
    _permissions_check_suid_sgid

    log_info "audit permissions : terminé"
}
