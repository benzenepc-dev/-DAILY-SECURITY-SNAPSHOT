#!/usr/bin/env bash
# =============================================================================
#  install.sh — déploiement du Daily Security Snapshot sur le serveur Linux
#  Propriétaire : Vincent Mactar Senghor
#  Usage : sudo ./scripts/install.sh
# =============================================================================
set -euo pipefail

PREFIX="/opt/daily-security-snapshot"
LOGDIR="/var/log/daily-security-snapshot"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "Lance ce script avec sudo."; exit 1; }

echo "[1/4] Copie du projet dans $PREFIX"
mkdir -p "$PREFIX"
cp -r "$SRC/scripts" "$SRC/config" "$PREFIX/"
chmod 750 "$PREFIX/scripts/security_audit.sh"

echo "[2/4] Création de $LOGDIR"
mkdir -p "$LOGDIR"
chmod 750 "$LOGDIR"

echo "[3/4] Installation de la tâche cron"
install -m 644 "$SRC/cron/daily-security-audit" /etc/cron.d/daily-security-audit

echo "[4/4] Premier audit de vérification"
"$PREFIX/scripts/security_audit.sh"

echo
echo "Installé. Prochaines étapes :"
echo "  - Ahmad  : ajouter le bloc <localfile> de wazuh/agent/ossec-localfile.xml dans /var/ossec/etc/ossec.conf"
echo "  - Ahmad  : ajouter wazuh/manager/local_rules.xml dans /var/ossec/etc/rules/local_rules.xml sur le manager"
echo "  - Papa   : brancher Grafana sur l'index wazuh-alerts-*"
