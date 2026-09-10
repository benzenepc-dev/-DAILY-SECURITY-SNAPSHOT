#!/usr/bin/env bash
# =============================================================================
#  firewall.sh — audit : état du pare-feu (ufw)
#  Propriétaire : Mamadou Diop
#
#  RÈGLE : ce fichier n'écrit RIEN sur stdout à part des appels à emit_finding.
#  Toute trace de debug part sur stderr via log_info / log_warn.
#  common.sh est sourcé par security_audit.sh : ne le source pas toi-même.
#
#  Checks produits (audit=firewall) :
#    - firewall_disabled : le pare-feu (ufw) n'est pas actif
#
#  Variables d'environnement reconnues (toutes optionnelles, surchargeables
#  pour les tests) :
#    AUDIT_FIREWALL_STATUS_CMD  commande dont la sortie ressemble à
#                               `ufw status` (défaut : `ufw status`)
#                               — surchargeable dans les tests pour rejouer
#                               une sortie figée sans dépendre d'ufw installé.
# =============================================================================

# ── Contrôle : le pare-feu est-il actif ? ────────────────────────────────────
_firewall_check_enabled() {
    local cmd="${AUDIT_FIREWALL_STATUS_CMD:-ufw status}"
    local output

    output=$($cmd 2>/dev/null)

    if printf '%s\n' "$output" | grep -qi '^Status: active'; then
        emit_finding "firewall" "firewall_disabled" "PASS" "info" \
            "ufw" "Firewall (ufw) is active" "No action needed"
    else
        emit_finding "firewall" "firewall_disabled" "FAIL" "critical" \
            "ufw" "Firewall (ufw) is not active or not installed" \
            "Enable the firewall: sudo ufw enable"
    fi
}

# ── Point d'entrée appelé par security_audit.sh ──────────────────────────────
audit_firewall() {
    log_info "audit firewall : démarrage"

    _firewall_check_enabled

    log_info "audit firewall : terminé"
}
