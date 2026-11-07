# Contributing to archloq

Thanks for helping improve archloq.

## Before You Start

This repo targets a **specific machine**: the Lenovo LOQ 17IRX10 (i7-13700HX +
RTX 5060 Laptop, sm_120) on Arch Linux with KDE Plasma 6 / Wayland.

Contributions that add support for other models are welcome, but keep them
additive — do not change the documented defaults for the reference hardware.
Undervolt and fan-curve values in particular are hardware-specific, and a value
that is safe on one chip can be unstable on another.

## Ground Rules for Scripts

Almost everything here runs as root. Accordingly:

- Start every script with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Quote every expansion. `"$var"`, not `$var`.
- Make scripts executable (`chmod +x`) — CI enforces this.
- Be idempotent. Running a script twice should be safe and produce the same
  result.
- Never `curl | sh` from an unpinned source.
- Back up any file you overwrite (the existing scripts use `.bak-loq`).
- Prefer failing loudly over doing something surprising to someone's machine.

## Testing Your Change

CI runs four checks; all of them work locally.

```bash
# Syntax — must parse
git ls-files '*.sh' | while read -r f; do bash -n "$f" || echo "FAIL $f"; done

# Lint — CI gates at severity `warning`
shellcheck -S warning -e SC1091 $(git ls-files '*.sh')

# Executable bits
git ls-files '*.sh' | while read -r f; do [ -x "$f" ] || echo "NOT EXEC $f"; done
```

Beyond that, state in your PR **what you actually ran and on what hardware**. A
config change that was never applied to a real machine should say so — that is
useful information, not a disqualifier.

## Secrets

Never commit credentials, keys, or `.env` files. Templates belong in
`*.example` files, which `.gitignore` deliberately preserves. See
[SECURITY.md](SECURITY.md) and [docs/SECRETS.md](docs/SECRETS.md).

## Commits and PRs

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`,
  `fix:`, `docs:`, `chore:`.
- One logical change per PR.
- Explain the *why* in the description, and note any risk to the reader's
  hardware.

## The `archinstall/` Profile

`archinstall/user_configuration.json` is the destructive half of the install, so
it is checked in CI rather than reviewed by eye:

```bash
uv venv /tmp/ai-venv
uv pip install --python /tmp/ai-venv/bin/python archinstall jsonschema
/tmp/ai-venv/bin/python archinstall/validate.py
```

The validator imports archinstall and runs its own parser over the profile. If
you change the partition layout, change the profile **and** the `EXPECTED` table
in `validate.py`, and re-run it. Do not hand-edit the JSON to make a failing
validator pass.

Never commit `user_credentials.json` — only the `.example` shape. The validator
fails if a credential key appears in the committed profile.
