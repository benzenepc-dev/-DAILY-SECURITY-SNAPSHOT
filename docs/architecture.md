# Architecture

> Propriétaire de ce document : Toute l'équipe

## Vue d'ensemble

```text
┌──────────────────────── Serveur Linux ──────────────────────────┐
│                                                                 │
│   ┌──────────────┐                                              │
│   │    CRON      │  tous les jours 02:00                        │
│   └──────┬───────┘                                              │
│          ▼                                                      │
│   ┌──────────────────────────┐                                  │
│   │ scripts/security_audit.sh│  ← Vincent                       │
│   │   ├ permissions.sh       │  ← Daniel                        │
│   │   ├ network.sh           │  ← Mamadou                       │
│   │   ├ services.sh          │  ← Mamadou                       │
│   │   └ users.sh             │  ← Vincent                       │
│   └──────────┬───────────────┘                                  │
│              ▼                                                  │
│   /var/log/daily-security-snapshot/audit.jsonl                  │
│              │                                                  │
│              ▼                                                  │
│      ┌──────────────┐                                           │
│      │ Wazuh Agent  │  ← Ahmad                                  │
│      └──────┬───────┘                                           │
└─────────────┼───────────────────────────────────────────────────┘
              ▼
      ┌───────────────┐      ┌───────────────┐      ┌────────────┐
      │ Wazuh Manager │─────▶│ Wazuh Indexer │─────▶│  Grafana   │
      │ local_rules   │      │  OpenSearch   │      │ Dashboard  │
      │   ← Ahmad     │      │               │      │  ← Papa    │
      └───────────────┘      └───────────────┘      └────────────┘
```

Ce schéma est le même que celui de la [section 1 du README](../README.md#1-architecture) —
ce document en détaille chaque étape, pour qui veut comprendre le flux sans
lire les cinq lots un par un.

## Le contrat qui tient tout ensemble

Une seule structure de données traverse toute la chaîne : la ligne JSON
produite par `emit_finding()` (`scripts/lib/common.sh`, propriété de Vincent),
détaillée dans la [section 5 du README](../README.md#5-le-contrat-json--la-seule-chose-à-ne-jamais-casser).
Tant que cette ligne respecte ses 10 clés et ses valeurs autorisées, chaque
brique peut évoluer indépendamment des autres :

1. **Modules d'audit** (`permissions.sh`, `network.sh`, `services.sh`,
   `users.sh`) — chacun scanne une facette du système et appelle
   `emit_finding()`. Ils ne s'appellent jamais entre eux et n'écrivent jamais
   de JSON à la main.
2. **`security_audit.sh`** — orchestre l'exécution des modules dans un ordre
   stable et écrit le résultat dans `audit.jsonl` (ou sur stdout en mode
   `--stdout`, pour les tests).
3. **Agent Wazuh** (`wazuh/agent/ossec-localfile.xml`) — lit `audit.jsonl` en
   continu, décode chaque ligne comme du JSON, l'envoie au manager.
4. **Manager Wazuh** (`wazuh/manager/local_rules.xml`) — transforme
   `severity` en niveau d'alerte Wazuh (`level`), voir [`docs/wazuh.md`](wazuh.md).
5. **Indexer / OpenSearch** — stocke l'alerte enrichie sous `wazuh-alerts-*`,
   avec les champs originaux accessibles sous `data.*` et le niveau sous
   `rule.level`.
6. **Grafana** (`grafana/`) — interroge cet index pour calculer le score de
   sécurité et peupler les 5 panels du dashboard, voir [`docs/grafana.md`](grafana.md).

## Pourquoi cette découpe en fichiers

Chaque module d'audit vit dans son propre fichier et n'a qu'un seul
propriétaire (voir [section 2 et 3 du README](../README.md#2-léquipe--qui-fait-quoi-qui-possède-quoi)) :
c'est ce qui permet à Daniel, Mamadou, Vincent, Ahmad et Papa de travailler en
parallèle sans jamais toucher aux mêmes lignes d'un même fichier. Les seuls
points de couplage réels sont documentés dans la
[section 4 du README](../README.md#4-qui-doit-communiquer-avec-qui) : le nom
des `check`, les 7 arguments d'`emit_finding`, et les noms de champs une fois
indexés.

## Pourquoi tout passe par `audit.jsonl` et pas par un appel direct

Découpler les modules Shell de Wazuh via un simple fichier ligne-par-ligne
(JSON Lines) permet à chaque brique d'être développée et testée
indépendamment : Ahmad peut construire ses règles avec
`tests/fixtures/example-audit.jsonl` sans qu'un seul audit réel ait tourné, et
Papa peut construire son dashboard sur des données injectées à la main dans
OpenSearch (voir [section 4 du README](../README.md#4-qui-doit-communiquer-avec-qui)).
