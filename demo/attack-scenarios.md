# Scénarios de démonstration

> Propriétaire : toute l'équipe — à répéter au moins une fois avant la soutenance.
> ⚠️ À exécuter UNIQUEMENT sur la VM de laboratoire, jamais sur une machine réelle.

## Avant : système sain

```bash
sudo /opt/daily-security-snapshot/scripts/security_audit.sh
```

Grafana doit afficher `Security Score 100/100`.

## Scénario 1 — fichier world-writable (attendu : HIGH)

```bash
sudo touch /etc/demo-insecure.conf
sudo chmod 777 /etc/demo-insecure.conf
```

## Scénario 2 — port non autorisé (attendu : CRITICAL)

```bash
python3 -m http.server 4444 &
```

## Scénario 3 — compte UID 0 en trop (attendu : CRITICAL)

```bash
sudo useradd -o -u 0 -g 0 -M demo-backdoor
```

## Relancer l'audit

```bash
sudo /opt/daily-security-snapshot/scripts/security_audit.sh
```

Chaîne attendue : Shell -> audit.jsonl -> Wazuh agent -> manager -> indexer -> Grafana.

## Nettoyage OBLIGATOIRE après la démo

```bash
sudo rm -f /etc/demo-insecure.conf
kill %1 2>/dev/null
sudo userdel demo-backdoor
```
