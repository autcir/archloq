# Secrets Management

## Overview

Never commit secrets to GitHub! Use one of these methods:

1. **git-crypt** - File-level encryption
2. **SOPS** - Mozilla's secrets editor
3. **GitHub Actions Secrets** - CI/CD secrets

---

## git-crypt

### Install

```bash
sudo pacman -S git-crypt
```

### Initialize Repository

```bash
# Initialize
git-crypt init

# Add your GPG key
git-crypt add-gpg-user YOUR_GPG_KEY_ID

# Lock the repository
git-crypt lock
```

### Configure .gitattributes

```bash
# Add to .gitattributes
*.key filter=git-crypt diff=git-crypt
*.pem filter=git-crypt diff=git-crypt
*.yaml filter=git-crypt diff=git-crypt
*.json filter=git-crypt diff=git-crypt
```

### Daily Usage

```bash
# Unlock secrets
git-crypt unlock

# Edit files (they're decrypted)
nano config/secrets.yaml

# Commit (files are encrypted)
git add config/secrets.yaml
git commit -m "Update secrets"
git push
```

---

## SOPS (Mozilla)

### Install

```bash
sudo pacman -S sops
```

### Setup

```bash
# Create encrypted file
sops -e config/secrets.yaml > config/secrets.enc.yaml

# Decrypt
sops -d config/secrets.enc.yaml > config/secrets.yaml
```

### GPG Key Setup

```bash
# Add GPG key to SOPS
echo "-----BEGIN PGP PUBLIC KEY BLOCK-----" > .sops.yaml
```

### .sops.yaml Configuration

```yaml
creation_rules:
  - path_regex: ^config/.*\.enc\.yaml$
    encrypted_regex: "^(accessKeyId|secretAccessKey)$"
    pgp: "YOUR_GPG_KEY_ID"
```

---

## GitHub Actions Secrets

### Add Secrets

1. Go to: `Settings → Secrets → Actions`
2. Click `New repository secret`
3. Add secret name and value

### Available Secrets

| Name | Description |
|------|-------------|
| OPENVIDIA_API_KEY | OpenVIDIA API key |
| ANTHROPIC_API_KEY | Anthropic API key |
| OPENAI_API_KEY | OpenAI API key |
| GITHUB_TOKEN | GitHub personal access token |

### Use in Workflows

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.OPENVIDIA_API_KEY }}
        run: |
          echo "Deploying with API key..."
```

---

## Template Files

### .claude.json.example

```json
{
  "openvidia": {
    "api_key": "YOUR_API_KEY_HERE",
    "endpoint": "https://api.openvidia.ai/v1"
  },
  "anthropic": {
    "api_key": "YOUR_API_KEY_HERE"
  },
  "openai": {
    "api_key": "YOUR_API_KEY_HERE"
  },
  "github": {
    "token": "YOUR_GITHUB_TOKEN_HERE"
  }
}
```

Copy to `~/.claude.json` and fill in values.

### config/secrets.json.example

```json
{
  "openvidia": {
    "api_key": "YOUR_OPENVIDIA_API_KEY_HERE",
    "endpoint": "https://api.openvidia.ai/v1"
  },
  "anthropic": {
    "api_key": "YOUR_ANTHROPIC_API_KEY_HERE"
  },
  "openai": {
    "api_key": "YOUR_OPENAI_API_KEY_HERE"
  },
  "cloudflare": {
    "api_token": "YOUR_CLOUDFLARE_API_TOKEN_HERE",
    "account_id": "YOUR_CLOUDFLARE_ACCOUNT_ID_HERE"
  },
  "google": {
    "places_api_key": "YOUR_GOOGLE_PLACES_API_KEY_HERE",
    "agent_platform_api_key": "YOUR_GOOGLE_AGENT_PLATFORM_API_KEY_HERE"
  },
  "meta_ads": {
    "access_token": "YOUR_META_ACCESS_TOKEN_HERE",
    "account_id": "YOUR_META_ACCOUNT_ID_HERE",
    "app_id": "YOUR_META_APP_ID_HERE",
    "app_secret": "YOUR_META_APP_SECRET_HERE"
  },
  "instagram": {
    "studio_centros_token": "YOUR_INSTAGRAM_TOKEN_HERE",
    "instagram_access_token": "YOUR_INSTAGRAM_ACCESS_TOKEN_HERE",
    "verace_token": "YOUR_VERACE_TOKEN_HERE"
  },
  "discord": {
    "studio_centros_bot_token": "YOUR_DISCORD_BOT_TOKEN_HERE",
    "guild_id": "YOUR_DISCORD_GUILD_ID_HERE"
  },
  "youtube": {
    "stream_key": "YOUR_YOUTUBE_STREAM_KEY_HERE",
    "channel_id": "YOUR_YOUTUBE_CHANNEL_ID_HERE"
  },
  "kick": {
    "client_id": "YOUR_KICK_CLIENT_ID_HERE",
    "client_secret": "YOUR_KICK_CLIENT_SECRET_HERE"
  },
  "telegram": {
    "eros_bot_token": "YOUR_TELEGRAM_BOT_TOKEN_HERE",
    "chat_id": "YOUR_TELEGRAM_CHAT_ID_HERE"
  }
}
```

---

## Using Tokens from EROS

EROS (`/home/ciroautuori/Scrivania/eros/.env`) contains all your API keys. To use them in LOQ:

### Step 1: Copy the template

```bash
cp config/secrets.json.example config/secrets.json
```

### Step 2: Copy tokens from EROS .env

Open EROS secrets file:
```bash
nano /home/ciroautuori/Scrivania/eros/.env
```

Copy the relevant tokens to `config/secrets.json`:
- `NVIDIA_API_KEY` → `openvidia.api_key`
- `CLOUDFLARE_API_TOKEN` → `cloudflare.api_token`
- `GOOGLE_PLACES_API_KEY` → `google.places_api_key`
- `META_ADS_ACCESS_TOKEN` → `meta_ads.access_token`
- etc.

### Step 3: Protect the file

```bash
# Add to .gitignore (already done)
echo "config/secrets.json" >> .gitignore
```

### Step 4: Set environment variables (alternative)

```bash
# Load from secrets.json
export $(jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' config/secrets.json)
```

---

## Backup Encrypted Secrets

### Using loq-backup.sh

```bash
# Create encrypted backup
bash manage/loq-backup.sh

# Output: ~/backups/loq-YYYYMMDD-HHMM/secrets.tar.zst.gpg
```

### Restore

```bash
# Decrypt backup
gpg -d secrets.tar.zst.gpg | tar -xaf -

# Restore files
cp -r secrets/* ~/
```

---

## Best Practices

1. **Never commit in plaintext** - Always use templates
2. **Use separate GPG keys** - Different keys for different projects
3. **Backup your GPG key** - Export to secure location
4. **Review PRs** - Check for accidental secret commits
5. **Use scanners** - `git-secrets` or `trufflehog`

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check for secrets
if git diff --cached | grep -E "(API_KEY|SECRET|PASSWORD)"; then
    echo "⚠️ Potential secrets detected!"
    exit 1
fi
```

### Install git-secrets

```bash
yay -S git-secrets
git secrets --install
git secrets --register-aws
```