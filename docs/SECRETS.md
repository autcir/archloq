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

### config/secrets.yaml.example

```yaml
api_keys:
  openvidia: "YOUR_API_KEY_HERE"
  anthropic: "YOUR_API_KEY_HERE"
  openai: "YOUR_API_KEY_HERE"

github:
  token: "YOUR_TOKEN_HERE"

database:
  host: "localhost"
  port: 5432
  name: "loq_dev"
  user: "loq"
  password: "YOUR_PASSWORD_HERE"
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