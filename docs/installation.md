# Installation

> Propriétaire de ce document : Vincent Mactar Senghor

## Prérequis

- Un serveur Linux (Ubuntu/Debian) avec `bash`, `find`, `cron`.
- Un agent Wazuh déjà installé et enregistré auprès d'un manager (voir
  [`docs/wazuh.md`](wazuh.md) pour la partie SIEM).
- `python3` pour lancer les tests (`tests/test_json.sh`).

## Installer le moteur d'audit

```bash
git clone <url-du-dépôt>
cd daily-security-snapshot
sudo ./scripts/install.sh
```

`scripts/install.sh` (propriété de Vincent) :

1. Copie `scripts/` et `config/` dans `/opt/daily-security-snapshot`.
2. Crée `/var/log/daily-security-snapshot` (permissions `750`).
3. Installe la tâche cron `cron/daily-security-audit` dans
   `/etc/cron.d/daily-security-audit` (audit quotidien à 02:00).
4. Lance un premier audit de vérification.

## Brancher Wazuh et Grafana

L'installation du moteur ne branche pas automatiquement le reste de la
chaîne — deux étapes manuelles, décrites en détail dans leurs docs
respectives :

1. **Ahmad** — agent + manager Wazuh : voir [`docs/wazuh.md`](wazuh.md#installation).
2. **Papa** — dashboard Grafana sur l'index `wazuh-alerts-*` : voir
   [`docs/grafana.md`](grafana.md).

## Vérifier que tout fonctionne

```bash
sudo /opt/daily-security-snapshot/scripts/security_audit.sh --stdout
```

Doit afficher une ligne JSON par `check` de chaque module
(`permissions`, `network`, `users`, `services`), avec un `PASS` si le serveur
est sain. Si rien ne s'affiche : vérifier les permissions d'exécution
(`chmod 750`) et que `scripts/lib/*.sh` sont bien présents dans
`/opt/daily-security-snapshot/scripts/lib/`.

## Configuration

`config/audit.conf` (propriété de Vincent) contrôle le comportement commun à
tous les modules : chemin de sortie (`AUDIT_OUTPUT`), répertoires exclus des
parcours `find` (`AUDIT_EXCLUDE_PATHS`), et si le scan doit rester sur le
système de fichiers de départ (`AUDIT_STAY_ON_FS`). Les listes blanches par
module (`config/allowed_suid.conf`, `config/allowed_ports.conf`,
`config/disallowed_services.conf`) sont à ajuster à l'environnement réel
avant la démo — voir la section correspondante de chaque doc de module.

## Désinstaller / réinitialiser pour une nouvelle démo

```bash
sudo rm -rf /opt/daily-security-snapshot /var/log/daily-security-snapshot
sudo rm -f /etc/cron.d/daily-security-audit
```
