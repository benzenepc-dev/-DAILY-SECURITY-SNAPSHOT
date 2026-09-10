# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Une ligne par PR mergée dans `develop`. C'est le rapporteur du groupe qui
consolide avant chaque merge `develop -> main`.

## [Non publié]

### Ajouté
- Structure du dépôt, contrat JSON (`scripts/lib/common.sh`), CI, protections de branches.
- Module permissions : détection des fichiers world-writable et des binaires SUID/SGID hors liste blanche (`scripts/lib/permissions.sh`, `config/allowed_suid.conf`, `tests/test_permissions.sh`).
- Module users : détection des comptes UID 0 inattendus (`scripts/lib/users.sh`, `tests/test_users.sh`).
- Dashboard Grafana complet (5 panels) avec score de sécurité par défaut (`grafana/`).
- Module network : détection des ports TCP/UDP en écoute hors de `config/allowed_ports.conf` (`scripts/lib/network.sh`, `tests/test_network.sh`).
- Module services : détection des services legacy/non sécurisés actifs (`scripts/lib/services.sh`, `config/disallowed_services.conf`, `tests/test_services.sh`).
- Documentation Wazuh (`docs/wazuh.md`) : installation agent/manager, hiérarchie des règles `110000`-`110013`, procédure de test avec `wazuh-logtest`.
- Documentation transverse `docs/architecture.md` et `docs/testing.md`.

## [0.1.0] - à venir
- Première chaîne complète : Shell -> JSON -> Cron -> Wazuh -> Grafana.
