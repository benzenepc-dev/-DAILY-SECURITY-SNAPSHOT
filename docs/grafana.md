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

## Validé le 2026-09-10 sur la VM de démo

Stack `docker-compose.yml` (OpenSearch + Grafana) lancée réellement, datasource
provisionnée avec l'UID exact attendu par `grafana/dashboard/daily-security-snapshot.json`
(`PD3F819237BBC744D`), données injectées dans `wazuh-alerts-4.x-*` reproduisant
l'état sain puis les 3 scénarios de `demo/attack-scenarios.md`. Les 5 panels
s'affichent et calculent correctement :

- [`docs/screenshots/grafana-dashboard-baseline-100.png`](screenshots/grafana-dashboard-baseline-100.png) — système sain, score 100/100.
- [`docs/screenshots/grafana-dashboard-after-attack-50.png`](screenshots/grafana-dashboard-after-attack-50.png) — après les 3 scénarios (1 high + 2 critical), score 100-(2×20+1×10) = **50**, table des derniers FAIL correcte.

La formule du score annoncée dans le README (`~77` après démo) était une
estimation d'exemple ; le calcul réel `100 - (critical×20 + high×10 + medium×5)`
donne 50 pour cette combinaison précise de 3 scénarios — la formule elle-même
est confirmée correcte.