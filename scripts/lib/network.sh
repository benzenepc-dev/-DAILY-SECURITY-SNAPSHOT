#!/usr/bin/env bash
# =============================================================================
#  network.sh — audit : ports ouverts, interfaces, firewall
#  Propriétaire : Mamadou Diop
#
#  RÈGLE : ce fichier n'écrit RIEN sur stdout à part des appels à emit_finding.
#  Toute trace de debug part sur stderr via log_info / log_warn.
#  common.sh est sourcé par security_audit.sh : ne le source pas toi-même.
# =============================================================================

audit_network() {
    log_info "audit network : démarrage"

    # TODO(Mamadou Diop) : implémenter les contrôles ici.
    # Chaque contrôle se termine par un emit_finding, PASS comme FAIL.
    # Exemple (7 arguments, toujours dans cet ordre) :
    #
    #   emit_finding "network" "nom_du_check" "FAIL" "high" "/ressource" "Message en anglais" "Comment corriger"

    log_info "audit network : terminé"
}
