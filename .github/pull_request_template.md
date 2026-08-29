## Ce que fait cette PR

<!-- 2-3 lignes maximum -->

## Zone concernée

- [ ] permissions (Daniel)
- [ ] network / services (Mamadou)
- [ ] moteur / JSON / cron (Vincent)
- [ ] wazuh (Ahmad)
- [ ] grafana (Papa Mamadou)
- [ ] docs

## Checklist obligatoire

- [ ] Je n'ai modifié QUE des fichiers de ma zone (voir `.github/CODEOWNERS`)
- [ ] `bash -n` passe sur mes scripts (pas d'erreur de syntaxe)
- [ ] `shellcheck` ne remonte pas d'erreur bloquante
- [ ] Chaque ligne produite est un JSON valide au format du contrat (`jq -e . < sortie`)
- [ ] J'ai utilisé `emit_finding` de `scripts/lib/common.sh` (je n'ai PAS écrit de JSON à la main)
- [ ] J'ai mis à jour ma doc dans `docs/`
- [ ] Ma branche est à jour avec `develop` (`git pull --rebase origin develop`)

## Preuve que ça marche

<!-- Colle ici la sortie de ton test, ou une capture d'écran -->

```json

```

## Impact sur les autres

<!-- Est-ce que quelqu'un doit adapter son code ? Si oui, qui, et l'as-tu prévenu ? -->
