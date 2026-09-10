# Modules network / services / firewall

> Propriétaire de ce document : Mamadou Diop

## Ce que font ces modules

Trois fichiers, un seul thème (« ce qui est exposé et accessible depuis
l'extérieur ») :

| Fichier | `audit` | check | Détecte quoi | severity si FAIL |
|---|---|---|---|---|
| `scripts/lib/network.sh` | `network` | `unexpected_listening_port` | Port TCP/UDP en écoute hors de `config/allowed_ports.conf` | `critical` |
| `scripts/lib/services.sh` | `services` | `disallowed_service_running` | Service legacy/non sécurisé actif (telnet, rsh, tftp...), hors de `config/disallowed_services.conf` | `high` |
| `scripts/lib/firewall.sh` | `firewall` | `firewall_disabled` | Pare-feu (`ufw`) non actif | `critical` |

Comme les autres modules, chaque check émet une ligne **PASS** (severity
`info`) quand tout est sain — c'est ce qui prouve dans Grafana que le scan a
bien tourné, et pas juste qu'il n'a rien remonté par erreur.

## Comment ça marche

### `network.sh`

- Liste les sockets en écoute via `ss -Htuln` (Netid, State, Recv-Q, Send-Q,
  Local Address:Port, Peer Address:Port).
- Ne garde que les lignes `tcp`/`udp`, extrait le port après le dernier `:`
  de l'adresse locale.
- Compare `(port, protocole)` à `config/allowed_ports.conf` (une ligne par
  port autorisé : `<port> <proto> <justification>`).
- Tout port en écoute hors de cette liste = `FAIL`.

### `services.sh`

- Liste les services `systemd` actifs via
  `systemctl list-units --type=service --state=running --no-legend --plain`.
- Compare chaque nom de service (sans le suffixe `.service`) à
  `config/disallowed_services.conf` (un service interdit par ligne).
- Tout service listé et actif = `FAIL`.

### `firewall.sh`

- Lit `ufw status` et cherche la ligne `Status: active`.
- Absence de la ligne (pare-feu coupé, ou `ufw` pas installé) = `FAIL`.

## Fichiers de configuration

- `config/allowed_ports.conf` : ports légitimes du serveur (SSH, HTTP(S),
  ports Wazuh agent→manager). **À vérifier sur la VM de démo** avant la
  soutenance avec `ss -tuln`.
- `config/disallowed_services.conf` : services legacy jugés systématiquement
  non sécurisés (`telnet`, `rsh`, `rlogin`, `tftp`, `vsftpd`, `xinetd`,
  `nis`, `ypserv`). Contrairement aux ports, ce n'est **pas** une liste
  blanche : n'importe quel autre service actif et non listé ici est
  considéré comme sain.

## Lancer uniquement ces modules

```bash
bash scripts/security_audit.sh --stdout --only network
bash scripts/security_audit.sh --stdout --only services
bash scripts/security_audit.sh --stdout --only firewall
```

## Lancer les tests

```bash
bash tests/test_network.sh
bash tests/test_services.sh
bash tests/test_firewall.sh
bash tests/test_json.sh             # contrat JSON du groupe
```

Aucun de ces trois tests ne touche au vrai réseau/aux vrais services : chaque
module accepte une variable d'environnement pour rejouer une sortie de
commande figée (`AUDIT_NETWORK_SS_CMD`, `AUDIT_SERVICES_LIST_CMD`,
`AUDIT_FIREWALL_STATUS_CMD`) — voir l'en-tête de chaque fichier `.sh` pour le
détail, et [`docs/testing.md`](testing.md) pour le principe commun à tous les
modules du projet.

## Scénario de démo (voir `demo/attack-scenarios.md`)

```bash
python3 -m http.server 4444 &
```

Résultat attendu : une ligne `unexpected_listening_port` / `FAIL` / `critical`
sur `0.0.0.0:4444` dans le prochain audit.

## À qui parler si je change quelque chose ici

- **Ahmad** si je renomme ou j'ajoute un `check` (impacte ses règles Wazuh
  dans `wazuh/manager/local_rules.xml`).
- **Papa** si le nom du check change (impacte ses panels Grafana).
- **Vincent** si j'ai besoin d'une nouvelle clé dans le contrat JSON, ou si
  je veux ajouter `network`/`services`/`firewall` à `MODULES` dans
  `scripts/security_audit.sh` (déjà fait pour ces trois modules).
