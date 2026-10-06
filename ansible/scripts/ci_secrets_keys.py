"""Wypisuje nazwy kluczy (bez wartości) z secrets.yml w CI i sprawdza wymagane.

Użycie: python ansible/scripts/ci_secrets_keys.py <secrets.yml> [wymagany_klucz ...]
"""
import sys

import yaml

path, required = sys.argv[1], sys.argv[2:]
with open(path, encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

if not isinstance(data, dict):
    sys.exit(f"❌ {path}: oczekiwano mapy klucz: wartość, jest {type(data).__name__}")

print(f"Klucze w secrets.yml ({len(data)}): {', '.join(sorted(data))}")
missing = [k for k in required if not str(data.get(k) or "").strip()]
if missing:
    sys.exit(
        "❌ Brak lub puste w ANSIBLE_SECRETS (GitLab → Settings → CI/CD → Variables): "
        + ", ".join(missing)
    )
print("✅ Wymagane sekrety są ustawione")
