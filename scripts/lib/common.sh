#!/usr/bin/env bash
# =============================================================================
#  common.sh — LE CONTRAT DU GROUPE 5
#  Propriétaire : Vincent Mactar Senghor
#
#  ⚠️  PERSONNE d'autre ne modifie ce fichier sans l'annoncer dans le groupe.
#      Les 5 briques du projet en dépendent.
#
#  Tout module d'audit produit ses résultats UNIQUEMENT via emit_finding().
#  Jamais de `echo '{...}'` écrit à la main : une virgule oubliée casse le
#  décodeur JSON de Wazuh, donc les règles d'Ahmad, donc le dashboard de Papa.
# =============================================================================

set -uo pipefail

# ── Variables globales de la campagne d'audit ────────────────────────────────
RUN_ID="${RUN_ID:-$(date -u +%Y%m%d-%H%M%S)}"
RUN_TIMESTAMP="${RUN_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
AUDIT_HOSTNAME="${AUDIT_HOSTNAME:-$(hostname -f 2>/dev/null || hostname)}"

# Fichier lu par l'agent Wazuh (voir wazuh/agent/ossec-localfile.xml)
AUDIT_OUTPUT="${AUDIT_OUTPUT:-/var/log/daily-security-snapshot/audit.jsonl}"

# ── Valeurs autorisées — ne pas en inventer d'autres ─────────────────────────
# status   : PASS | FAIL
# severity : info | low | medium | high | critical
VALID_STATUS="PASS FAIL"
VALID_SEVERITY="info low medium high critical"

# ── Échappement JSON (RFC 8259) ──────────────────────────────────────────────
# Caractère par caractère : la substitution ${v//.../...} de bash ne double pas
# les antislashs de façon fiable selon les versions (5.2+), ce qui produirait
# du JSON invalide sur les noms de fichiers exotiques.
json_escape() {
    local s="${1-}"

    # Chemin rapide : rien à échapper (cas le plus fréquent)
    case "$s" in
        *'\'*|*'"'*|*$'\n'*|*$'\r'*|*$'\t'*) ;;
        *) printf '%s' "$s"; return 0 ;;
    esac

    local out="" c i
    for (( i = 0; i < ${#s}; i++ )); do
        c="${s:i:1}"
        case "$c" in
            '\')   out="$out"'\\' ;;
            '"')   out="$out"'\"' ;;
            $'\n') out="$out"'\n' ;;
            $'\r') out="$out"'\r' ;;
            $'\t') out="$out"'\t' ;;
            [[:cntrl:]]) out="$out$(printf '\\u%04x' "'$c")" ;;
            *)     out="$out$c" ;;
        esac
    done
    printf '%s' "$out"
}

_contract_error() {
    printf '[common.sh] ERREUR CONTRAT: %s\n' "$1" >&2
}

# ── emit_finding : LA seule façon d'écrire un résultat ───────────────────────
#
#   emit_finding <audit> <check> <status> <severity> <resource> <message> <recommendation>
#
#   audit          : permissions | network | users | services | firewall
#   check          : identifiant stable du contrôle, en snake_case
#                    (ex: world_writable_file). C'est la clé utilisée par les
#                    règles Wazuh et les panels Grafana : une fois publiée,
#                    ON NE LA RENOMME PLUS sans prévenir Ahmad et Papa.
#   status         : PASS | FAIL
#   severity       : info | low | medium | high | critical
#                    (un PASS est toujours en severity "info")
#   resource       : l'objet concerné (chemin, port, utilisateur, service)
#   message        : phrase courte en anglais, factuelle
#   recommendation : ce qu'il faut faire pour corriger
#
# Exemple :
#   emit_finding "permissions" "world_writable_file" "FAIL" "high" \
#       "/tmp/test.conf" "World writable file detected" \
#       "Remove write permission for others: chmod o-w /tmp/test.conf"
#
emit_finding() {
    if [ "$#" -ne 7 ]; then
        _contract_error "emit_finding attend 7 arguments, reçus $#"
        return 1
    fi

    local audit="$1" check="$2" status="$3" severity="$4"
    local resource="$5" message="$6" recommendation="$7"

    case " $VALID_STATUS " in
        *" $status "*) ;;
        *) _contract_error "status invalide '$status' (attendu: $VALID_STATUS)"; return 1 ;;
    esac
    case " $VALID_SEVERITY " in
        *" $severity "*) ;;
        *) _contract_error "severity invalide '$severity' (attendu: $VALID_SEVERITY)"; return 1 ;;
    esac

    printf '{"timestamp":"%s","run_id":"%s","hostname":"%s","audit":"%s","check":"%s","status":"%s","severity":"%s","resource":"%s","message":"%s","recommendation":"%s"}\n' \
        "$(json_escape "$RUN_TIMESTAMP")" \
        "$(json_escape "$RUN_ID")" \
        "$(json_escape "$AUDIT_HOSTNAME")" \
        "$(json_escape "$audit")" \
        "$(json_escape "$check")" \
        "$(json_escape "$status")" \
        "$(json_escape "$severity")" \
        "$(json_escape "$resource")" \
        "$(json_escape "$message")" \
        "$(json_escape "$recommendation")"
}

# ── Journal humain (stderr) — n'entre JAMAIS dans le .jsonl ──────────────────
log_info()  { printf '[INFO]  %s\n' "$*" >&2; }
log_warn()  { printf '[WARN]  %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }

# ── La commande existe-t-elle ? ──────────────────────────────────────────────
has_cmd() { command -v "$1" >/dev/null 2>&1; }
