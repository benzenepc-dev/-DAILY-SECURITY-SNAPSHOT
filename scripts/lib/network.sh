#!/usr/bin/env bash
# =============================================================================
#  network.sh — audit : ports ouverts, interfaces, firewall
#  Propriétaire : Mamadou Diop
#
#  RÈGLE : ce fichier n'écrit RIEN sur stdout à part des appels à emit_finding.
#  Toute trace de debug part sur stderr via log_info / log_warn.
#  common.sh est sourcé par security_audit.sh : ne le source pas toi-même.
#
#  Checks produits (audit=network) :
#    - unexpected_listening_port : port TCP/UDP en écoute hors de
#                                  config/allowed_ports.conf
#
#  Variables d'environnement reconnues (toutes optionnelles, surchargeables
#  pour les tests) :
#    AUDIT_PORTS_ALLOWLIST  chemin du fichier de ports autorisés
#                           (défaut : config/allowed_ports.conf du projet)
#    AUDIT_NETWORK_SS_CMD   commande à exécuter pour lister les sockets en
#                           écoute, au format `ss -Htuln` (défaut : `ss -Htuln`)
#                           — surchargeable dans les tests pour rejouer une
#                           sortie `ss` figée sans toucher au vrai réseau.
# =============================================================================

_NETWORK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_NETWORK_DEFAULT_ALLOWLIST="$_NETWORK_LIB_DIR/../../config/allowed_ports.conf"

# ── Le port est-il autorisé pour ce protocole ? ──────────────────────────────
# Format d'une ligne de config/allowed_ports.conf : "<port> <proto> <justification>"
_network_is_allowed_port() {
    local port="$1" proto="$2" allowlist="$3" line lport lproto

    [ -r "$allowlist" ] || return 1

    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        set -- $line
        lport="${1:-}" lproto="${2:-}"
        if [ "$lport" = "$port" ] && [ "$lproto" = "$proto" ]; then
            return 0
        fi
    done < "$allowlist"

    return 1
}

# ── Contrôle : ports en écoute hors liste blanche ────────────────────────────
_network_check_listening_ports() {
    local allowlist="${AUDIT_PORTS_ALLOWLIST:-$_NETWORK_DEFAULT_ALLOWLIST}"
    local cmd="${AUDIT_NETWORK_SS_CMD:-ss -Htuln}"
    local unexpected=0
    local line proto local_addr port

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        proto=$(printf '%s' "$line" | awk '{print tolower($1)}')
        case "$proto" in
            tcp|udp) ;;
            *) continue ;;
        esac

        local_addr=$(printf '%s' "$line" | awk '{print $5}')
        port="${local_addr##*:}"
        case "$port" in
            ''|*[!0-9]*) continue ;;
        esac

        _network_is_allowed_port "$port" "$proto" "$allowlist" && continue

        unexpected=1
        emit_finding "network" "unexpected_listening_port" "FAIL" "critical" \
            "$local_addr" "Unexpected listening port $port ($proto)" \
            "Stop the service or add the port to config/allowed_ports.conf"
    done < <($cmd 2>/dev/null)

    if [ "$unexpected" -eq 0 ]; then
        emit_finding "network" "unexpected_listening_port" "PASS" "info" \
            "${AUDIT_HOSTNAME:-localhost}" "No unexpected listening port found" \
            "No action needed"
    fi
}

# ── Point d'entrée appelé par security_audit.sh ──────────────────────────────
audit_network() {
    log_info "audit network : démarrage"

    _network_check_listening_ports

    log_info "audit network : terminé"
}
