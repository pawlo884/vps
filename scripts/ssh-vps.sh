#!/bin/bash
# Łączenie z VPS przez SSH

cd "$(dirname "$0")/.." || exit 1

# Wczytaj konfigurację z hosts.ini
VPS_HOST=$(grep ansible_host ansible/inventories/prod/hosts.ini | awk -F= '{print $2}')
VPS_USER=$(grep ansible_user ansible/inventories/prod/hosts.ini | awk -F= '{print $2}')

if [ -z "$VPS_HOST" ] || [ -z "$VPS_USER" ]; then
    echo "❌ Nie można odczytać konfiguracji VPS z hosts.ini"
    exit 1
fi

echo "🔐 Łączenie z VPS..."
echo "   Host: $VPS_HOST"
echo "   User: $VPS_USER"
echo ""

ssh "$VPS_USER@$VPS_HOST"

