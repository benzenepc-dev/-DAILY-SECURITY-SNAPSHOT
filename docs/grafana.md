# Dashboard Grafana

> Propriétaire de ce document : Papa Mamadou Ba

# Dashboard Grafana
> Propriétaire de ce document : Papa Mamadou Ba

## Panels
1. Score de sécurité (gauge) — formule : 100 - (critical*20 + high*10 + medium*5)
2. Constats FAIL par sévérité (barchart)
3. Répartition des constats par module (piechart)
4. Évolution PASS/FAIL dans le temps (timeseries)
5. Derniers constats en échec (table)

## Datasource
Index : wazuh-alerts-*
Champ temporel : @timestamp
Champs utilisés : data.audit, data.check, data.status, data.severity, data.resource, data.message, data.recommendation, rule.level

## Points à valider avec l'équipe
- [ ] Formule du score : proposition actuelle (100 - critical*20 - high*10 - medium*5) à confirmer avec Vincent
- [ ] Noms de champs indexés : basés sur la convention du doc du groupe, à reconfirmer avec Ahmad une fois le pipeline Wazuh réel branché

## Test en local
Voir docker-compose.yml à la racine + grafana/provisioning/datasource.local.yml (non commité, dans .gitignore)