#!/usr/bin/env bash
# =============================================================================
#  security_audit.sh — chef d'orchestre du Daily Security Snapshot
#  Propriétaire : Vincent Mactar Senghor
#
#  Usage :
#     sudo ./scripts/security_audit.sh                 # sortie vers $AUDIT_OUTPUT
#     sudo ./scripts/security_audit.sh --stdout        # sortie à l'écran (tests)
#     sudo ./scripts/security_audit.sh --only network  # un seul module
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

# Configuration (surchargeable par /etc/daily-security-snapshot/audit.conf)
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config/audit.conf}"
# shellcheck source=/dev/null
[ -r "$CONFIG_FILE" ] && . "$CONFIG_FILE"

TO_STDOUT=0
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --stdout) TO_STDOUT=1 ;;
        --only)   ONLY="${2:-}"; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) log_error "option inconnue: $1"; exit 2 ;;
    esac
    shift
done

# Modules d'audit — l'ordre est stable pour que le .jsonl soit lisible
MODULES="permissions network users services"

for m in $MODULES; do
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/lib/$m.sh"
done

run_all() {
    for m in $MODULES; do
        [ -n "$ONLY" ] && [ "$ONLY" != "$m" ] && continue
        "audit_$m"
    done
}

if [ "$TO_STDOUT" -eq 1 ]; then
    run_all
else
    mkdir -p "$(dirname "$AUDIT_OUTPUT")"
    run_all >> "$AUDIT_OUTPUT"
    chmod 640 "$AUDIT_OUTPUT" 2>/dev/null || true
    log_info "audit terminé — run_id=$RUN_ID — résultats dans $AUDIT_OUTPUT"
fi
