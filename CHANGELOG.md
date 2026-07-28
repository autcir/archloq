# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-28

First tagged release. The configuration itself has been in use on the reference
hardware for some time; this release makes the repository usable by anyone else.

### Fixed

- **`runtime/` produced empty directories on every clone.** Nine entries were
  committed as gitlinks (mode 160000) with no `.gitmodules` file, so the
  NVIDIA, undervolt, and LLM reference material was unreachable for everyone
  but the original author. They are now fetched on demand via
  `runtime/fetch-runtime.sh`; all eight upstream URLs verified.
- **`99_safe_reboot_check.sh` always reported success.** It tested `$?` after
  an `echo`, which is always 0, so it printed "ALL CLEAR — safe to reboot"
  regardless of how many checks had failed.
- **`12-transparency-blur.sh` could not be parsed.** The `add_rule()`
  declaration line was missing, leaving an orphaned function body. The function
  was also never called: the script wrote `count 12` and claimed twelve opacity
  rules were applied while creating none.
- **All twelve install scripts were non-executable**, including the documented
  entrypoint `pacmaster.sh`.
- **Colour output was broken everywhere.** `lib/utils.sh` used single-quoted
  `printf`, so every script printed literal `${BLUE}==>${NC}` markers.
- **`.gitignore` hid the secrets template.** `config/*secrets*` also matched
  `config/secrets.json.example`, the file `docs/SECRETS.md` tells users to copy.
- Unquoted `$(nproc)` passed to `cmake -j` in `08_local_llm.sh`.
- Theme lookups using `ls | grep` broke on paths containing spaces.
- README documented `install-scripts/config/loq.conf`, which does not exist.

### Added

- CI (`.github/workflows/ci.yml`): shellcheck, `bash -n` parsing, executable-bit
  enforcement, and a private-key scan, all on GitHub-hosted runners.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and PR templates.
- `.editorconfig`, `.shellcheckrc`, Dependabot for GitHub Actions.
- `runtime/fetch-runtime.sh` to clone or update the upstream reference repos.

[1.0.0]: https://github.com/ciroautuori/archloq/releases/tag/v1.0.0
