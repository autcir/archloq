#!/bin/bash
# =============================================================================
# unlock-secrets.sh - Helper per decifrare i segreti con git-crypt
# =============================================================================
# Usa questo script per decifrare i file protetti da git-crypt
# Richiede che la tua chiave GPG sia configurata
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# I comandi git-crypt agiscono sul repo corrente: parti dalla root del repo,
# così lo script funziona da qualunque directory venga lanciato.
cd "$SCRIPT_DIR/.."

echo "🔓 Decifrando i segreti..."

# Controlla se git-crypt è installato
if ! command -v git-crypt &> /dev/null; then
    echo "❌ git-crypt non installato"
    echo "Installa con: sudo pacman -S git-crypt"
    exit 1
fi

# Controlla se siamo in un repo git
if ! git rev-parse --git-dir &> /dev/null; then
    echo "❌ Non sembra un repository git"
    exit 1
fi

# Controlla se il repo ha git-crypt abilitato
if ! git-crypt status &> /dev/null; then
    echo "❌ Questo repository non ha git-crypt abilitato"
    exit 1
fi

# Unlock
git-crypt unlock

echo "✅ Segreti decifrati con successo!"
echo ""
echo "Puoi ora modificare i file sensibili in chiaro."
echo "Ricorda di non committare i file in chiaro!"
echo ""
echo "Per bloccare nuovamente i file dopo le modifiche:"
echo "  git-crypt lock"