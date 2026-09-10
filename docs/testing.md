# Tests

> Propriétaire de ce document : Toute l'équipe

## Principe commun à tous les modules

Chaque module d'audit a son propre fichier de test
(`tests/test_<module>.sh`), qui suit toujours le même schéma :

1. Créer un bac à sable isolé (`mktemp -d`, ou un fichier de fixture pour un
   module qui ne scanne pas un répertoire) — jamais le vrai système.
2. Injecter volontairement une situation vulnérable et une situation saine.
3. Lancer la fonction `audit_<module>` avec les variables d'environnement du
   module pointées vers le bac à sable.
4. Vérifier la sortie JSON (présence du bon `check`/`status`/`severity`, et
   absence de faux positifs).
5. Nettoyer avec `trap ... EXIT`, même si un test échoue en cours de route.
6. Valider que toute la sortie respecte le contrat JSON du groupe via
   `python3 tests/validate_finding.py`.

Aucun test ne touche `/etc/passwd`, le vrai système de fichiers en dehors du
bac à sable, ni un vrai service/port du système : chaque module expose une ou
plusieurs variables d'environnement pour rejouer une source de données figée.

| Module | Test | Ce qui est surchargé pour tester sans toucher au système |
|---|---|---|
| `permissions.sh` | `tests/test_permissions.sh` | `AUDIT_ROOT` (racine du scan), `AUDIT_SUID_ALLOWLIST` |
| `network.sh` | `tests/test_network.sh` | `AUDIT_NETWORK_SS_CMD` (sortie `ss` figée), `AUDIT_PORTS_ALLOWLIST` |
| `services.sh` | `tests/test_services.sh` | `AUDIT_SERVICES_LIST_CMD` (sortie `systemctl` figée), `AUDIT_SERVICES_DENYLIST` |
| `users.sh` | `tests/test_users.sh` | `AUDIT_PASSWD_FILE` (fichier passwd de test) |

## Le contrat du groupe : `tests/test_json.sh`

C'est le seul test qui tourne automatiquement en CI (job `contract` de
`.github/workflows/ci.yml`), sur chaque Pull Request vers `main`/`develop`. Il
vérifie :

- qu'`emit_finding` produit un JSON valide, y compris avec des caractères
  spéciaux à échapper ;
- qu'il refuse les valeurs hors contrat (`status`/`severity` invalides,
  mauvais nombre d'arguments) ;
- que la sortie de chaque module (`audit_permissions`, `audit_network`,
  `audit_users`, `audit_services`) est 100 % conforme au contrat quand on
  l'exécute avec sa configuration par défaut ;
- que les fixtures d'exemple (`tests/fixtures/*.jsonl`) restent conformes.

`tests/validate_finding.py` (propriété de Vincent) est le seul endroit qui
connaît la liste exacte des 10 clés et des valeurs autorisées : c'est lui qui
fait autorité, pas une relecture manuelle.

## Lancer tous les tests en local, avant de pousser

```bash
bash tests/test_json.sh          # le contrat — obligatoire avant toute PR
bash tests/test_permissions.sh
bash tests/test_network.sh
bash tests/test_services.sh
bash tests/test_users.sh
```

⚠️ `tests/test_json.sh` exécute chaque module avec sa configuration par
défaut (`AUDIT_ROOT=/` pour `permissions.sh`, `ss`/`systemctl` réels pour
`network.sh`/`services.sh`) : sur une machine sans ces commandes (par exemple
un environnement Windows/Git Bash), les modules concernés remontent
simplement une sortie vide et le test l'accepte — c'est sur une VM Linux
(voir `demo/attack-scenarios.md`) que le scan réel doit être vérifié.

## Preuve d'exécution réelle (VM de démo, 2026-09-10)

- [`docs/screenshots/audit-baseline-terminal.png`](screenshots/audit-baseline-terminal.png) — `security_audit.sh` sur système sain : 6/6 checks en PASS.
- [`docs/screenshots/demo-attack-scenarios-terminal.png`](screenshots/demo-attack-scenarios-terminal.png) — les 3 scénarios de `demo/attack-scenarios.md` injectés puis détectés (3 FAIL exacts, rien d'autre).

## Ce qui n'est PAS couvert par des tests automatisés

- Les règles Wazuh (`wazuh/manager/local_rules.xml`) : validées avec
  `xmllint` (syntaxe) en CI, et manuellement avec `wazuh-logtest` sur une VM
  (voir [`docs/wazuh.md`](wazuh.md)).
- Le dashboard Grafana : vérifié visuellement sur une instance locale
  (`docker-compose.yml` + `grafana/provisioning/`), voir
  [`docs/grafana.md`](grafana.md).
- La chaîne bout-en-bout complète (cron → agent → manager → indexer →
  Grafana) : uniquement testable sur une VM avec Wazuh installé, via les
  scénarios de `demo/attack-scenarios.md`.
