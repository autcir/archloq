# Security Policy

## Scope

archloq is a collection of system configuration scripts for Arch Linux on the
Lenovo LOQ. Most scripts **run as root** and modify kernel modules, power
management, and firmware-adjacent settings. Treat every script here as
privileged code.

## Reporting a Vulnerability

**Do not open a public issue for security problems.**

Report via [GitHub Security Advisories](../../security/advisories/new) — the
Security tab of this repository → "Report a vulnerability".

Please include:

- The affected script or config file
- What an attacker (or an unlucky user) could cause to happen
- Your hardware/kernel/Arch version, if relevant

Expect an initial response within 7 days.

## What Counts as a Vulnerability Here

Because this is machine configuration rather than a network service, the
interesting failure modes are unusual:

- **Privilege escalation** — a script writing to a path a non-root user can
  control, unquoted expansions in a root context, or `curl | sh` from a
  non-pinned source.
- **Destructive defaults** — a script that can brick boot, corrupt firmware, or
  render a machine unbootable without confirmation.
- **Secret leakage** — any committed credential, or a `.gitignore` rule that
  fails to exclude one. See below.
- **Undervolt/thermal settings** that could cause hardware damage on models
  other than the documented one.

## Secrets

This repository must never contain credentials. `.gitignore` excludes keys,
`.env` files, and browser credential stores, and CI scans every push for
private key material.

If you find a committed secret, report it privately as above — **do not** open
a public issue naming it.

Applying these configs is at your own risk. Review any script before running it
as root, especially the undervolt and fan control paths, which are tuned for the
specific hardware documented in the README.
