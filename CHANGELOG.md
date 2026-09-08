# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Une ligne par PR mergée dans `develop`. C'est le rapporteur du groupe qui
consolide avant chaque merge `develop -> main`.

## [Non publié]

### Ajouté
- Structure du dépôt, contrat JSON (`scripts/lib/common.sh`), CI, protections de branches.
- Module permissions : détection des fichiers world-writable et des binaires SUID/SGID hors liste blanche (`scripts/lib/permissions.sh`, `config/allowed_suid.conf`, `tests/test_permissions.sh`).

## [0.1.0] - à venir
- Première chaîne complète : Shell -> JSON -> Cron -> Wazuh -> Grafana.
