# Module permissions

> Propriétaire de ce document : Diembi Daniel Emmanuel

## Ce que fait ce module

`scripts/lib/permissions.sh` expose `audit_permissions`, appelée par
`scripts/security_audit.sh`. Elle produit deux types de constat
(`audit = "permissions"`) :

| check                          | Détecte quoi | severity si FAIL |
|---------------------------------|---------------|-------------------|
| `world_writable_file`           | Fichier accessible en écriture par tout le monde (`o+w`) | `high` |
| `unexpected_suid_sgid_binary`   | Binaire portant le bit SUID ou SGID et absent de `config/allowed_suid.conf` | `high` |

Si aucun problème n'est trouvé, chaque check émet quand même **une ligne
PASS** (severity `info`) — c'est ce qui prouve dans Grafana que le scan a
bien tourné, et pas juste qu'il n'a rien remonté par erreur.

## Comment ça marche

- Le scan part de `AUDIT_ROOT` (par défaut `/`).
- Les chemins listés dans `AUDIT_EXCLUDE_PATHS` (défini dans
  `config/audit.conf`, propriété de Vincent) sont exclus via `find ... -prune`.
- Si `AUDIT_STAY_ON_FS=1`, le scan ne traverse pas les autres points de
  montage (`find -xdev`) — évite de scanner des montages réseau, tmpfs, etc.
- Les binaires SUID/SGID sont comparés à `config/allowed_suid.conf` : un
  chemin absolu par ligne, `#` pour les commentaires. Tout binaire hors de
  cette liste = `FAIL`.

## Fichier de configuration : `config/allowed_suid.conf`

Contient les binaires SUID/SGID standards d'une installation Ubuntu/Debian
propre (`sudo`, `passwd`, `mount`, `ssh-keysign`, …). **À vérifier sur la VM
de démo avant la soutenance** :

```bash
find / -perm -4000 -o -perm -2000 -type f 2>/dev/null
```

Comparer la sortie avec `config/allowed_suid.conf` et ajouter ce qui manque
légitimement (par exemple des binaires spécifiques à une distribution).

## Lancer uniquement ce module

```bash
bash scripts/security_audit.sh --stdout --only permissions
```

## Lancer les tests

```bash
bash tests/test_permissions.sh      # tests du module (bac à sable, isolé)
bash tests/test_json.sh             # contrat JSON du groupe
```

`tests/test_permissions.sh` ne touche jamais le vrai système : chaque test
crée un dossier temporaire (`mktemp -d`) avec `AUDIT_ROOT`, y place un cas
vulnérable ou sain, lance `audit_permissions`, vérifie la sortie, puis
nettoie automatiquement (même si un test échoue, via `trap ... EXIT`).

## Scénario de démo (voir `demo/attack-scenarios.md`)

```bash
sudo touch /etc/demo-insecure.conf
sudo chmod 777 /etc/demo-insecure.conf
```

Résultat attendu : une ligne `world_writable_file` / `FAIL` / `high` sur
`/etc/demo-insecure.conf` dans le prochain audit.

## À qui parler si je change quelque chose ici

- **Ahmad** si je renomme ou j'ajoute un `check` (impacte ses règles Wazuh
  dans `wazuh/manager/local_rules.xml`).
- **Papa** si le nom du check change (impacte ses panels Grafana).
- **Vincent** si j'ai besoin d'une nouvelle clé dans le contrat JSON.
