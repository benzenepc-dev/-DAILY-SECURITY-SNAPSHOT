#!/usr/bin/env python3
"""Validateur du contrat JSON du Groupe 5.

Lit des lignes JSONL sur l'entrée standard et vérifie que chacune respecte
exactement le format convenu (voir README, section « Le contrat JSON »).

Usage :
    ./scripts/security_audit.sh --stdout | python3 tests/validate_finding.py

Sortie : 0 si tout est conforme, 1 sinon (une ligne d'erreur par problème).
"""
import json
import sys

REQUIRED_KEYS = [
    "timestamp", "run_id", "hostname", "audit", "check",
    "status", "severity", "resource", "message", "recommendation",
]
VALID_STATUS = {"PASS", "FAIL"}
VALID_SEVERITY = {"info", "low", "medium", "high", "critical"}
VALID_AUDIT = {"permissions", "network", "users", "services", "firewall"}


def validate(line, lineno, errors):
    try:
        doc = json.loads(line)
    except ValueError as exc:
        errors.append("ligne %d : JSON invalide (%s) -> %s" % (lineno, exc, line[:120]))
        return

    if not isinstance(doc, dict):
        errors.append("ligne %d : l'objet racine doit etre un objet JSON" % lineno)
        return

    for key in REQUIRED_KEYS:
        if key not in doc:
            errors.append("ligne %d : cle manquante '%s'" % (lineno, key))

    extra = set(doc) - set(REQUIRED_KEYS)
    if extra:
        errors.append("ligne %d : cle(s) hors contrat %s "
                      "(ajoute-la au contrat avec l'accord du groupe)"
                      % (lineno, sorted(extra)))

    if doc.get("status") not in VALID_STATUS:
        errors.append("ligne %d : status '%s' interdit (attendu %s)"
                      % (lineno, doc.get("status"), sorted(VALID_STATUS)))

    if doc.get("severity") not in VALID_SEVERITY:
        errors.append("ligne %d : severity '%s' interdite (attendu %s)"
                      % (lineno, doc.get("severity"), sorted(VALID_SEVERITY)))

    if doc.get("audit") not in VALID_AUDIT:
        errors.append("ligne %d : audit '%s' inconnu (attendu %s)"
                      % (lineno, doc.get("audit"), sorted(VALID_AUDIT)))

    if doc.get("status") == "PASS" and doc.get("severity") != "info":
        errors.append("ligne %d : un PASS doit avoir severity 'info', pas '%s'"
                      % (lineno, doc.get("severity")))

    check = doc.get("check", "")
    if not check or check != check.lower().replace(" ", "_"):
        errors.append("ligne %d : check '%s' doit etre en snake_case minuscule"
                      % (lineno, check))


def main():
    errors = []
    count = 0
    for lineno, line in enumerate(sys.stdin, start=1):
        line = line.strip()
        if not line:
            continue
        count += 1
        validate(line, lineno, errors)

    for err in errors:
        sys.stderr.write("  KO   %s\n" % err)

    if errors:
        sys.stderr.write("\n%d ligne(s) analysee(s), %d probleme(s)\n" % (count, len(errors)))
        return 1
    sys.stdout.write("  OK   %d ligne(s) conforme(s) au contrat\n" % count)
    return 0


if __name__ == "__main__":
    sys.exit(main())
