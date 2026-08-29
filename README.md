# Daily Security Snapshot

> Audit de sécurité Linux automatisé : **Shell + Cron → JSON → Wazuh → OpenSearch → Grafana**
> Groupe 5 — Sujet 5

Un script Shell lance chaque nuit un audit du serveur (permissions, ports, comptes,
services, firewall). Chaque constat est écrit sous forme d'une ligne JSON, lue par
l'agent Wazuh, évaluée par des règles personnalisées du manager, indexée dans
OpenSearch, puis affichée dans un tableau de bord Grafana « Daily Security Snapshot ».

---

## Sommaire

1. [Architecture](#1-architecture)
2. [L'équipe : qui fait quoi, qui possède quoi](#2-léquipe--qui-fait-quoi-qui-possède-quoi)
3. [La règle d'or anti-conflit](#3-la-règle-dor-anti-conflit)
4. [Qui doit communiquer avec qui](#4-qui-doit-communiquer-avec-qui)
5. [Le contrat JSON](#5-le-contrat-json--la-seule-chose-à-ne-jamais-casser)
6. [Modèle de branches](#6-modèle-de-branches)
7. [Cycle de vie d'une contribution](#7-cycle-de-vie-dune-contribution)
8. [Protections GitHub à mettre en place](#8-protections-github-à-mettre-en-place)
9. [Les commandes Git à connaître](#9-les-commandes-git-à-connaître)
10. [Conventions de commit et de PR](#10-conventions-de-commit-et-de-pr)
11. [Démarrage rapide](#11-démarrage-rapide)
12. [Roadmap et jalons d'intégration](#12-roadmap-et-jalons-dintégration)
13. [Ce qu'on ne pousse JAMAIS](#13-ce-quon-ne-pousse-jamais)

---

## 1. Architecture

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

Le point important du projet n'est pas le nombre de contrôles Shell : c'est que
**la chaîne complète fonctionne de bout en bout**.

---

## 2. L'équipe : qui fait quoi, qui possède quoi

| Membre | Rôle | Branche | Fichiers dont il est le **seul** à écrire |
|---|---|---|---|
| **Diembi Daniel Emmanuel** | Permissions, SUID/SGID, fichiers sensibles | `feature/permissions-audit` | `scripts/lib/permissions.sh`, `tests/test_permissions.sh` |
| **Mamadou Diop** | Réseau, ports, services, firewall | `feature/network-audit` | `scripts/lib/network.sh`, `scripts/lib/services.sh`, `config/allowed_ports.conf`, `tests/test_network.sh` |
| **Vincent Mactar Senghor** | Moteur, contrat JSON, Cron, comptes | `feature/audit-engine` | `scripts/security_audit.sh`, `scripts/lib/common.sh`, `scripts/lib/users.sh`, `scripts/install.sh`, `cron/`, `config/audit.conf`, `tests/test_json.sh`, `tests/validate_finding.py` |
| **Ahmad Abdou Malick Diop** | Wazuh, règles, intégration SIEM | `feature/wazuh` | `wazuh/agent/`, `wazuh/manager/`, `docs/wazuh.md` |
| **Papa Mamadou Ba** | Grafana, dashboard, score de sécurité | `feature/grafana` | `grafana/`, `docs/grafana.md` |

Chacun est responsable de **son code + ses tests + sa documentation**. Il n'y a pas
de « celui qui fait la doc » : celui qui écrit le code écrit sa doc.

Cette répartition est encodée dans [`.github/CODEOWNERS`](.github/CODEOWNERS).
**À faire en priorité : remplacer les pseudos `@daniel-github`, `@mamadou-github`,
`@vincent-github`, `@ahmad-github`, `@papa-github` par les vrais comptes GitHub.**

---

## 3. La règle d'or anti-conflit

> **Un fichier = un propriétaire.**

Un conflit Git n'arrive presque jamais entre deux fichiers différents. Il arrive
quand deux personnes modifient **les mêmes lignes du même fichier**. Comme chaque
module est dans son propre fichier, personne ne marche sur les pieds de personne.

Les trois seuls fichiers réellement partagés, et la règle qui va avec :

| Fichier partagé | Règle |
|---|---|
| `scripts/lib/common.sh` | **Vincent uniquement.** Toute modification doit être annoncée dans le groupe avant la PR : les 4 autres en dépendent. |
| `README.md` | On ne modifie que **sa propre section**. On ne reformate jamais tout le fichier. |
| `CHANGELOG.md` | On **ajoute une ligne à la fin** de la section « Non publié ». On ne réordonne pas. |

Si tu as besoin de modifier un fichier qui n'est pas à toi : **tu ne le fais pas
toi-même**, tu ouvres une issue ou tu envoies un message à son propriétaire.

---

## 4. Qui doit communiquer avec qui

Tout le monde n'a pas besoin de parler à tout le monde. Voici les seules
conversations qui doivent réellement avoir lieu — et l'artefact qui les formalise
(une décision qui reste dans WhatsApp n'existe pas ; elle doit finir dans un fichier).

```text
        Daniel ──┐
                 ├──▶ Vincent ──▶ Ahmad ──▶ Papa
      Mamadou ──┘   (contrat JSON)  (champs)  (dashboard)
           │                                     ▲
           └─────────── noms des checks ─────────┘
```

| Qui | Avec qui | Sur quoi exactement | Formalisé dans |
|---|---|---|---|
| Daniel, Mamadou | **Vincent** | Nom de la fonction (`audit_permissions`, `audit_network`, …), les 7 arguments d'`emit_finding`, la liste des `check` produits | `scripts/lib/common.sh`, `docs/architecture.md` |
| Vincent | **Ahmad** | Chemin exact du fichier `.jsonl`, ses permissions (l'agent Wazuh doit pouvoir le lire), s'il est écrasé ou complété chaque jour, la rotation des logs | `config/audit.conf` ↔ `wazuh/agent/ossec-localfile.xml` |
| Daniel, Mamadou | **Ahmad** | La liste figée des `check` et des `severity` : c'est ce qui décide du niveau d'alerte Wazuh | `wazuh/manager/local_rules.xml` |
| Ahmad | **Papa** | Le nom des champs une fois indexés (`data.audit`, `data.severity`, `data.check`, `rule.level`), l'index (`wazuh-alerts-*`) et le champ temporel (`@timestamp`) | `docs/wazuh.md` → `grafana/provisioning/datasource.yml` |
| Papa | **Vincent** | La formule du score de sécurité et quels `check` y entrent | `docs/grafana.md` |
| Tout le monde | **Vincent** | Vincent est le gardien du contrat : toute nouvelle clé JSON passe par lui | `tests/validate_finding.py` |

**Qui n'a PAS besoin d'attendre qui :**
Daniel, Mamadou et Vincent travaillent en parallèle dès le jour 1.
Ahmad peut travailler dès qu'il a **un seul** fichier `.jsonl` d'exemple —
il en existe déjà un : [`tests/fixtures/example-audit.jsonl`](tests/fixtures/example-audit.jsonl).
Papa peut construire son dashboard sur des données injectées à la main dans
OpenSearch, sans attendre que l'audit réel tourne.

**Rythme conseillé :** un point de 15 minutes deux fois par semaine, plus un point
obligatoire à chaque fin de phase (voir [roadmap](#12-roadmap-et-jalons-dintégration)).

---

## 5. Le contrat JSON — la seule chose à ne jamais casser

Une ligne du fichier `audit.jsonl` = un constat = un objet JSON, **exactement** avec
ces 10 clés, ni plus ni moins :

```json
{
  "timestamp": "2026-08-29T02:00:00Z",
  "run_id": "20260829-020000",
  "hostname": "ubuntu-lab",
  "audit": "permissions",
  "check": "world_writable_file",
  "status": "FAIL",
  "severity": "high",
  "resource": "/tmp/demo-insecure.conf",
  "message": "World writable file detected",
  "recommendation": "chmod o-w /tmp/demo-insecure.conf"
}
```

Valeurs autorisées — rien d'autre :

| Clé | Valeurs |
|---|---|
| `audit` | `permissions` · `network` · `users` · `services` · `firewall` |
| `status` | `PASS` · `FAIL` |
| `severity` | `info` · `low` · `medium` · `high` · `critical` (un `PASS` est toujours `info`) |
| `check` | `snake_case` minuscule, **stable dans le temps** |

> ⚠️ Un `check` renommé casse les règles Wazuh d'Ahmad **et** les panels de Papa.
> Une fois qu'un nom de `check` est mergé dans `develop`, il ne change plus sans
> prévenir Ahmad et Papa.

### On n'écrit jamais ce JSON à la main

```bash
# ❌ INTERDIT — une virgule oubliée et toute la chaîne tombe
echo '{"audit":"network","severity":"high"}' >> "$AUDIT_OUTPUT"

# ✅ CORRECT — 7 arguments, toujours dans cet ordre
emit_finding "network" "unexpected_listening_port" "FAIL" "critical" \
    "0.0.0.0:4444" "Unexpected listening port 4444" \
    "Stop the service or add the port to config/allowed_ports.conf"
```

`emit_finding` échappe les caractères spéciaux, refuse les valeurs hors contrat et
remplit `timestamp` / `run_id` / `hostname` tout seul.

### Vérifier avant de pousser

```bash
bash tests/test_json.sh
```

Ce test tourne aussi automatiquement sur chaque Pull Request (job `contract`).

---

## 6. Modèle de branches

```text
  feature/permissions-audit ─┐
  feature/network-audit     ─┤
  feature/audit-engine      ─┼──▶  develop  ──▶  main
  feature/wazuh             ─┤    (intégration)  (version montrée au prof)
  feature/grafana           ─┘
```

| Branche | Rôle | Qui y pousse |
|---|---|---|
| `main` | Version stable, présentable au professeur. Toujours fonctionnelle. | Personne directement — uniquement via PR depuis `develop` |
| `develop` | Version intégrée en cours. C'est la branche par défaut du dépôt. | Personne directement — uniquement via PR depuis une `feature/*` |
| `feature/*` | Le terrain de jeu de chacun. | Son propriétaire, autant qu'il veut |

**Personne ne pousse jamais directement sur `main` ni sur `develop`.**
Aucune PR ne va de `feature/*` directement vers `main`.

---

## 7. Cycle de vie d'une contribution

```text
1. git switch develop && git pull          ← partir de la dernière version intégrée
2. git switch feature/ma-branche
3. git merge develop                       ← se remettre à jour AVANT de coder
4. ... je code ...
5. bash tests/test_json.sh                 ← le contrat passe ?
6. git add / git commit                    ← petits commits, messages clairs
7. git push origin feature/ma-branche
8. Pull Request  feature/ma-branche → develop
9. Un relecteur approuve, la CI est verte
10. Merge (squash) → la branche est supprimée sur GitHub
11. On recrée la branche localement pour la tâche suivante
```

**Qui relit quoi ?** Le relecteur naturel est la personne qui dépend de ton travail :

| Auteur de la PR | Relecteur demandé |
|---|---|
| Daniel | Vincent (le format) + Ahmad (les noms de `check`) |
| Mamadou | Vincent (le format) + Ahmad (les noms de `check`) |
| Vincent | Ahmad (impact SIEM) |
| Ahmad | Papa (les champs indexés) |
| Papa | Ahmad (la source de données) |

Une PR se relit en 10 minutes. **Règle du groupe : aucune PR ne reste ouverte plus
de 48 h.** Si personne ne relit, le projet s'arrête.

---

## 8. Protections GitHub à mettre en place

### ⚠️ État actuel

Le dépôt est **privé sur un compte GitHub gratuit** : GitHub y **désactive** les
protections de branche et les rulesets (message : *« Upgrade to GitHub Pro or make
this repository public to enable this feature »*). Trois options :

| Option | Conséquence |
|---|---|
| **Rendre le dépôt public** (recommandé pour un projet académique) | Protections gratuites immédiatement. Le `.gitignore` du projet interdit déjà logs, clés et `.env` |
| Passer le compte en **GitHub Pro** | Le dépôt reste privé, protections activées |
| Rester privé sans protection | Les règles ci-dessous deviennent des **règles d'équipe** : rien ne les empêche techniquement, tout repose sur la discipline |

### Réglages à appliquer dès que les protections sont disponibles

`Settings → Branches → Add branch protection rule`

**Règle sur `main` :**

| Réglage | Valeur |
|---|---|
| Require a pull request before merging | ✅ |
| ↳ Require approvals | **2** |
| ↳ Dismiss stale approvals when new commits are pushed | ✅ |
| ↳ Require review from Code Owners | ✅ |
| Require status checks to pass | ✅ → `lint`, `contract`, `config` |
| ↳ Require branches to be up to date before merging | ✅ |
| Require conversation resolution before merging | ✅ |
| Require linear history | ✅ |
| Do not allow bypassing the above settings | ✅ |
| Allow force pushes / Allow deletions | ❌ / ❌ |

**Règle sur `develop` :** identique, mais **1 seule approbation** (sinon le groupe
s'auto-bloque) et sans « require linear history ».

### Autres réglages, disponibles même en privé/gratuit

`Settings → General → Pull Requests`

- ☑ Allow squash merging — **et décocher merge commits et rebase merging**
  (un squash = un commit propre par fonctionnalité dans `develop`)
- ☑ Automatically delete head branches (les branches mergées disparaissent toutes seules)
- ☑ Always suggest updating pull request branches

`Settings → General → Default branch` → **mettre `develop`**
(pour que toute nouvelle PR vise `develop` par défaut, pas `main`)

`Settings → Collaborators` → ajouter les 4 autres membres en rôle **Write**
(surtout pas Admin : ça permettrait de contourner les protections)

### Le garde-fou qui, lui, marche déjà

La CI [`.github/workflows/ci.yml`](.github/workflows/ci.yml) tourne sur chaque PR,
protections ou pas, et signale en rouge :

| Job | Ce qu'il vérifie |
|---|---|
| `lint` | `bash -n` + `shellcheck` sur tous les scripts |
| `contract` | Le format JSON du groupe est respecté |
| `config` | Le XML Wazuh et le JSON Grafana sont bien formés |

**Règle d'équipe : on ne merge jamais une PR dont la CI est rouge**, même si GitHub
laisse techniquement le bouton cliquable.

---

## 9. Les commandes Git à connaître

### Une seule fois, au tout début

```bash
# Se présenter à Git (à faire une fois par machine)
git config --global user.name  "Prénom Nom"
git config --global user.email "ton.email@exemple.com"

# Récupérer le projet
git clone https://github.com/benzenepc-dev/-DAILY-SECURITY-SNAPSHOT.git
cd -DAILY-SECURITY-SNAPSHOT

# Récupérer sa branche déjà créée sur GitHub (exemple pour Daniel)
git switch feature/permissions-audit
```

### Tous les jours, en commençant à travailler

```bash
git switch feature/ma-branche     # aller sur SA branche
git fetch origin                  # voir ce qui a bougé chez les autres
git merge origin/develop          # récupérer le travail intégré des autres
```

> Fais ce `merge origin/develop` **souvent** (au moins une fois par jour).
> Plus tu attends, plus les conflits seront gros.

### Voir où on en est

```bash
git status                        # quels fichiers j'ai modifiés
git diff                          # ce que j'ai changé, ligne par ligne
git diff --staged                 # ce qui est déjà ajouté pour le commit
git log --oneline --graph --all -20   # l'histoire du projet
git branch -a                     # toutes les branches
```

### Enregistrer et pousser son travail

```bash
git add scripts/lib/permissions.sh          # ajouter SES fichiers (pas `git add .` à l'aveugle)
git commit -m "feat(permissions): detect world-writable files"
git push origin feature/ma-branche
```

Puis sur GitHub : **Compare & pull request** → base `develop` ← compare `feature/ma-branche`.

### Ouvrir la PR en ligne de commande (optionnel)

```bash
gh pr create --base develop --fill
gh pr status
gh pr checks                      # la CI est-elle verte ?
```

### Après le merge de sa PR

```bash
git switch develop
git pull origin develop
git branch -d feature/ma-branche              # supprimer la branche locale
git switch -c feature/ma-nouvelle-tache       # repartir sur une nouvelle tâche
```

### Résoudre un conflit (ça arrivera, c'est normal)

```bash
git merge origin/develop
# CONFLICT (content): Merge conflict in scripts/lib/common.sh
```

1. Ouvre le fichier. Tu verras :

```text
<<<<<<< HEAD
        ma version
=======
        la version de develop
>>>>>>> origin/develop
```

2. Garde ce qu'il faut, **efface les lignes `<<<<<<<`, `=======` et `>>>>>>>`**.
3. Puis :

```bash
git add scripts/lib/common.sh
git commit                        # message de merge proposé : garde-le
bash tests/test_json.sh           # vérifie que ça marche encore
git push origin feature/ma-branche
```

En cas de doute total :

```bash
git merge --abort                 # tout annuler, revenir à avant le merge
```

Et **appelle le propriétaire du fichier en conflit** avant de trancher tout seul.

### Rattraper une erreur

```bash
# J'ai modifié un fichier et je veux revenir en arrière (AVANT commit)
git restore scripts/lib/permissions.sh

# J'ai fait `git add` par erreur
git restore --staged scripts/lib/permissions.sh

# Je me suis trompé dans le message du dernier commit (pas encore poussé)
git commit --amend -m "feat(permissions): message correct"

# J'ai commité sur develop au lieu de ma branche (pas encore poussé)
git branch feature/ma-branche      # sauvegarder le travail sur une branche
git reset --hard origin/develop    # remettre develop propre
git switch feature/ma-branche      # continuer sur sa branche

# Je veux mettre mon travail de côté 5 minutes
git stash
git stash pop
```

### Les commandes à ne JAMAIS taper

```bash
git push --force origin develop    # ❌ efface le travail des autres
git push --force origin main       # ❌ idem
git push origin main               # ❌ on passe par une PR
git reset --hard                   # ❌ si tu n'es pas sûr : tu perds ton travail
git add . && git commit -am "..."  # ⚠️ à éviter : tu commites des fichiers qui ne sont pas à toi
```

Si tu as vraiment besoin d'un `--force`, c'est `--force-with-lease`, sur **ta propre
branche uniquement**, et tu préviens le groupe.

---

## 10. Conventions de commit et de PR

Format des messages : **Conventional Commits**.

```text
<type>(<zone>): <description à l'infinitif, en anglais, sans point final>
```

Types : `feat` · `fix` · `docs` · `test` · `refactor` · `chore` · `ci`
Zones : `permissions` · `network` · `services` · `users` · `engine` · `cron` · `wazuh` · `grafana`

Exemples :

```text
feat(permissions): detect SUID binaries outside the allowlist
fix(network): handle hosts without the ss command
docs(wazuh): document custom rule IDs 110000-110013
test(engine): cover JSON escaping of quotes and backslashes
ci: run shellcheck on pull requests
```

Un commit = une idée. Mieux vaut cinq petits commits clairs qu'un seul commit
« update ».

Chaque PR remplit le modèle [`.github/pull_request_template.md`](.github/pull_request_template.md),
qui se charge tout seul à l'ouverture.

---

## 11. Démarrage rapide

### Lancer l'audit sans rien installer

```bash
bash scripts/security_audit.sh --stdout          # tout à l'écran
bash scripts/security_audit.sh --only network    # un seul module
```

### Vérifier son travail avant de pousser

```bash
bash -n scripts/lib/mon_module.sh                          # syntaxe
shellcheck scripts/lib/mon_module.sh                       # qualité
bash tests/test_json.sh                                    # le contrat du groupe
bash scripts/security_audit.sh --stdout | python3 tests/validate_finding.py
```

### Installer sur le serveur (Vincent)

```bash
sudo ./scripts/install.sh
```

Le script copie le projet dans `/opt/daily-security-snapshot`, crée
`/var/log/daily-security-snapshot`, installe `/etc/cron.d/daily-security-audit`
(audit quotidien à **02:00**) et lance un premier audit.

### Structure du dépôt

```text
scripts/security_audit.sh   chef d'orchestre           Vincent
scripts/lib/common.sh       LE CONTRAT (emit_finding)  Vincent
scripts/lib/*.sh            un module par thème        Daniel / Mamadou / Vincent
config/                     ports autorisés, réglages  Mamadou / Vincent
cron/                       tâche planifiée 02:00      Vincent
wazuh/agent/                config de l'agent          Ahmad
wazuh/manager/              règles personnalisées      Ahmad
grafana/                    datasource + dashboard     Papa
tests/                      tests + validateur JSON    chacun le sien
docs/                       documentation par thème    chacun la sienne
demo/                       scénarios de soutenance    tout le monde
logs/                       vide dans Git (gitignoré)  —
```

---

## 12. Roadmap et jalons d'intégration

| Phase | Objectif | Qui | Jalon : c'est fini quand… |
|---|---|---|---|
| **1. Infrastructure** | Dépôt, branches, VM Ubuntu, Wazuh, Grafana debout | Tous | Chacun a cloné, poussé un commit sur sa branche et vu la CI verte |
| **2. Audit Shell** | 6 contrôles qui marchent vraiment | Daniel, Mamadou, Vincent | `security_audit.sh --stdout \| python3 tests/validate_finding.py` renvoie 0 avec de vrais constats |
| **3. Automatisation** | Cron + fichier `.jsonl` en place | Vincent | Un audit apparaît tout seul à 02:00 dans `/var/log/daily-security-snapshot/audit.jsonl` |
| **4. SIEM** | Agent, décodeur JSON, règles 110000-110013 | Ahmad | `wazuh-logtest` fait remonter une alerte de niveau 12 sur un constat `critical` |
| **5. Dashboard** | Panels + score de sécurité | Papa | Le score passe de 100 à ~77 après le scénario de démo |
| **6. Intégration** | Répétition complète | Tous | `demo/attack-scenarios.md` rejoué de bout en bout sans intervention manuelle |
| **7. Soutenance** | Présentation | Tous | `main` est à jour et le dashboard tourne |

**V1 volontairement réduite — 6 contrôles seulement, mais parfaits :**
fichiers world-writable · binaires SUID/SGID · ports ouverts non autorisés ·
comptes UID 0 inattendus · état du firewall · services exposés sur `0.0.0.0`.

Les contrôles supplémentaires (SSH, politique de mots de passe, logins échoués,
comptes inactifs, mises à jour, Docker…) n'arrivent **qu'après** que la chaîne
complète fonctionne.

---

## 13. Ce qu'on ne pousse JAMAIS

- Les vrais résultats d'audit (`*.jsonl`, `logs/`) — ils décrivent les faiblesses d'une machine réelle
- Les mots de passe, jetons, `.env`, clés privées (`*.pem`, `*.key`, `*.crt`)
- Les adresses IP et identifiants du serveur Wazuh, de l'indexer ou de Grafana
  → dans `grafana/provisioning/datasource.yml`, on garde des espaces réservés
  (`<IP_WAZUH_INDEXER>`, `${WAZUH_INDEXER_PASSWORD}`)
- Les captures d'écran contenant des données réelles non floutées

Le [`.gitignore`](.gitignore) bloque déjà l'essentiel, mais **il ne remplace pas la
relecture** : avant chaque `git add`, un `git status` et un `git diff`.

Si un secret est poussé par accident : **prévenir tout de suite le groupe**, changer
le mot de passe concerné, et ne pas se contenter de le supprimer dans un commit
suivant (il reste dans l'historique).

---

## Licence

MIT — voir [LICENSE](LICENSE).
