# Intégration Wazuh

> Propriétaire de ce document : Ahmad Abdou Malick Diop

## Ce que fait ce module

Ce lot branche le fichier `audit.jsonl` produit par le moteur d'audit
(propriété de Vincent) sur la chaîne Wazuh, jusqu'à ce que chaque constat
devienne une alerte indexée dans OpenSearch, exploitable par Grafana :

```
audit.jsonl  ──▶  Agent Wazuh  ──▶  Manager Wazuh (local_rules.xml)  ──▶  Indexer/OpenSearch
             (localfile, JSON)     (règles + niveau d'alerte)          (wazuh-alerts-*)
```

Deux fichiers, deux machines :

| Fichier | Où il va | Rôle |
|---|---|---|
| [`wazuh/agent/ossec-localfile.xml`](../wazuh/agent/ossec-localfile.xml) | `/var/ossec/etc/ossec.conf` de **l'agent** installé sur le serveur audité | Dit à l'agent de lire `audit.jsonl` et de le décoder en JSON |
| [`wazuh/manager/local_rules.xml`](../wazuh/manager/local_rules.xml) | `/var/ossec/etc/rules/local_rules.xml` du **manager** Wazuh | Transforme chaque ligne JSON en alerte, avec un niveau qui dépend de `severity` |

## Comment ça marche

### Côté agent — lecture du fichier

Le bloc `<localfile>` déclare `log_format=json` : l'agent Wazuh décode chaque
ligne de `audit.jsonl` comme un objet JSON et l'envoie au manager tel quel,
champ par champ (accessibles côté manager sous `data.<clé>`, par exemple
`data.severity`, `data.check`).

### Côté manager — la hiérarchie de règles

Toutes les règles vivent dans le groupe `daily_security_snapshot` et utilisent
la plage d'ID personnalisée **110000-110013** (la plage 100000-120000 est
réservée par Wazuh aux règles locales).

| ID | Condition | Niveau | Rôle |
|---|---|---|---|
| `110000` | `run_id` et `audit` présents | 0 (silencieuse) | Règle mère : reconnaît un événement du projet, ne génère pas d'alerte seule |
| `110001` | `status = PASS` | 3 | Trace qu'un contrôle est passé (bruit faible, utile pour prouver que le scan tourne) |
| `110010` | `status = FAIL` + `severity = low` | 5 | |
| `110011` | `status = FAIL` + `severity = medium` | 7 | |
| `110012` | `status = FAIL` + `severity = high` | 10 | |
| `110013` | `status = FAIL` + `severity = critical` | 12 | Niveau le plus haut : correspond à un `usermod`/backdoor/port critique |

Le mapping `severity → level` est volontairement générique (basé sur les 5
valeurs du contrat JSON, pas sur le nom du `check`) : un nouveau `check` créé
par Daniel, Mamadou ou Vincent est **automatiquement couvert**, sans toucher à
`local_rules.xml`, tant qu'il respecte le contrat (`audit`/`check`/`status`/
`severity` — voir [section 5 du README](../README.md#5-le-contrat-json--la-seule-chose-à-ne-jamais-casser)).

## Installation

```bash
# Sur le serveur audité (agent Wazuh déjà installé et enregistré)
# Coller le contenu de wazuh/agent/ossec-localfile.xml
# à l'intérieur de <ossec_config> dans :
sudo nano /var/ossec/etc/ossec.conf
sudo systemctl restart wazuh-agent

# Sur le manager Wazuh
# Coller le contenu de wazuh/manager/local_rules.xml dans :
sudo nano /var/ossec/etc/rules/local_rules.xml
sudo /var/ossec/bin/wazuh-logtest    # valider la syntaxe des règles
sudo systemctl restart wazuh-manager
```

`scripts/install.sh` (propriété de Vincent) rappelle ces deux étapes à la fin
de l'installation du moteur d'audit.

## Piège rencontré : le champ `status` est réservé

`status` est un nom de champ **statique** dans le moteur de règles Wazuh
(utilisé nativement, par ex. par les événements FIM `added`/`modified`/
`deleted`) : il ne peut pas être matché avec `<field name="status">` — Wazuh
refuse de charger la règle (`Field 'status' is static`). Il faut utiliser la
balise dédiée `<status>^PASS$</status>` à la place. Les autres clés du contrat
(`audit`, `check`, `severity`, `resource`, `run_id`) restent des champs
dynamiques standards et se matchent normalement avec `<field name="...">`.

Validé le 2026-09-10 avec `wazuh-logtest` v4.14.7 sur la VM de démo, avec
`tests/fixtures/example-audit.jsonl` : `severity=high` → règle `110012`
(niveau 10), `severity=critical` → règle `110013` (niveau 12),
`status=PASS` → règle `110001` (niveau 3). Conforme au tableau de la section
précédente. Transcript complet : [`docs/screenshots/wazuh-logtest-output.txt`](screenshots/wazuh-logtest-output.txt).

Le pipeline complet a aussi été validé en conditions réelles sur cette même VM
(pas seulement via `wazuh-logtest`) : `wazuh-manager` installé, notre
`local_rules.xml` chargé, `audit.jsonl` surveillé par `wazuh-logcollector`, et
les 3 scénarios de `demo/attack-scenarios.md` rejoués ont bien produit de
vraies alertes dans `/var/ossec/logs/alerts/alerts.log` avec les niveaux
attendus.

## Vérifier avant de pousser

```bash
xmllint --noout wazuh/agent/ossec-localfile.xml wazuh/manager/local_rules.xml
```

C'est ce que vérifie le job `config` de la CI (`.github/workflows/ci.yml`).

Pour valider qu'une ligne `audit.jsonl` donnée produit bien l'alerte attendue,
sur une VM avec Wazuh installé :

```bash
sudo /var/ossec/bin/wazuh-logtest
# Coller une ligne de tests/fixtures/example-audit.jsonl et vérifier
# le niveau d'alerte renvoyé (voir le tableau ci-dessus).
```

## Scénario de démo (voir `demo/attack-scenarios.md`)

Après un des trois scénarios (fichier world-writable, port non autorisé,
compte UID 0 en trop) et un nouvel audit, l'alerte doit apparaître côté
manager avec le niveau attendu (`high` → niveau 10, `critical` → niveau 12).
Si rien ne remonte : vérifier dans l'ordre `audit.jsonl` (le constat est-il
bien écrit ?), les logs de l'agent (`/var/ossec/logs/ossec.log`), puis
`wazuh-logtest` sur le manager.

## Champs indexés utilisés par Papa (Grafana)

Une fois indexé, chaque constat est disponible dans `wazuh-alerts-*` sous les
champs suivants (voir [`docs/grafana.md`](grafana.md)) :

`data.audit`, `data.check`, `data.status`, `data.severity`, `data.resource`,
`data.message`, `data.recommendation`, `rule.level`, `@timestamp`.

## À qui parler si je change quelque chose ici

- **Vincent** si j'ai besoin d'une nouvelle clé dans le contrat JSON pour
  affiner une règle (ex: filtrer sur un champ qui n'existe pas encore).
- **Papa** avant de renommer un champ indexé ou de changer un niveau de
  règle : ses panels Grafana lisent `rule.level` et `data.severity`
  directement.
- **Daniel / Mamadou** si un nouveau `check` a besoin d'un niveau d'alerte
  différent de celui donné automatiquement par sa `severity` (cas rare —
  nécessite une règle dédiée en plus de `110010`-`110013`).
