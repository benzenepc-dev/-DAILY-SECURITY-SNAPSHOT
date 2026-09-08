#!/usr/bin/env bash
# =============================================================================
#  users.sh — audit : comptes, UID 0 inattendus, politique de mots de passe
#  Propriétaire : Vincent Mactar Senghor
#
#  RÈGLE : ce fichier n'écrit RIEN sur stdout à part des appels à emit_finding.
#  Toute trace de debug part sur stderr via log_info / log_warn.
#  common.sh est sourcé par security_audit.sh : ne le source pas toi-même.
# =============================================================================

audit_users() {
    log_info "audit users : démarrage"

    local found_extra_root=0

    while IFS=: read -r name _ uid _ _ _ _; do
        if [ "$uid" = "0" ] && [ "$name" != "root" ]; then
            found_extra_root=1
            emit_finding "users" "unexpected_uid_zero_account" "FAIL" "critical" \
                "$name" "Account '$name' has UID 0 (root privileges)" \
                "Investigate immediately and remove root privileges if unauthorized: usermod -u <new_uid> $name"
        fi
    done < /etc/passwd

    if [ "$found_extra_root" -eq 0 ]; then
        emit_finding "users" "unexpected_uid_zero_account" "PASS" "info" \
            "/etc/passwd" "No unexpected UID 0 accounts found" \
            "No action needed"
    fi

    log_info "audit users : terminé"
}
