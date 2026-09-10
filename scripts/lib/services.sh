#!/usr/bin/env bash
# =============================================================================
#  services.sh — audit : services exposés et leur état
#  Propriétaire : Mamadou Diop
#
#  RÈGLE : ce fichier n'écrit RIEN sur stdout à part des appels à emit_finding.
#  Toute trace de debug part sur stderr via log_info / log_warn.
#  common.sh est sourcé par security_audit.sh : ne le source pas toi-même.
#
#  Checks produits (audit=services) :
#    - disallowed_service_running : service legacy/non sécurisé actif
#                                    (config/disallowed_services.conf)
#
#  Variables d'environnement reconnues (toutes optionnelles, surchargeables
#  pour les tests) :
#    AUDIT_SERVICES_DENYLIST  chemin de la liste des services interdits
#                             (défaut : config/disallowed_services.conf du projet)
#    AUDIT_SERVICES_LIST_CMD  commande listant les services actifs, une unité
#                             par ligne (défaut :
#                             `systemctl list-units --type=service --state=running --no-legend --plain`)
#                             — surchargeable dans les tests pour rejouer une
#                             sortie figée sans dépendre de systemd.
# =============================================================================

_SERVICES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SERVICES_DEFAULT_DENYLIST="$_SERVICES_LIB_DIR/../../config/disallowed_services.conf"

# ── Le service est-il dans la liste des interdits ? ──────────────────────────
_services_is_disallowed() {
    local svc="$1" denylist="$2" line

    [ -r "$denylist" ] || return 1

    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        [ "$line" = "$svc" ] && return 0
    done < "$denylist"

    return 1
}

# ── Contrôle : services interdits actuellement actifs ────────────────────────
_services_check_disallowed_running() {
    local denylist="${AUDIT_SERVICES_DENYLIST:-$_SERVICES_DEFAULT_DENYLIST}"
    local cmd="${AUDIT_SERVICES_LIST_CMD:-systemctl list-units --type=service --state=running --no-legend --plain}"
    local found=0
    local line svc

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        svc=$(printf '%s' "$line" | awk '{print $1}')
        svc="${svc%.service}"

        _services_is_disallowed "$svc" "$denylist" || continue

        found=1
        emit_finding "services" "disallowed_service_running" "FAIL" "high" \
            "$svc" "Disallowed/legacy service '$svc' is running" \
            "Stop and disable the service: systemctl disable --now $svc"
    done < <($cmd 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        emit_finding "services" "disallowed_service_running" "PASS" "info" \
            "${AUDIT_HOSTNAME:-localhost}" "No disallowed service running" \
            "No action needed"
    fi
}

# ── Point d'entrée appelé par security_audit.sh ──────────────────────────────
audit_services() {
    log_info "audit services : démarrage"

    _services_check_disallowed_running

    log_info "audit services : terminé"
}
