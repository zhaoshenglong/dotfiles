# Design: mise-managed CLI tools with chezmoi one-shot bootstrap

Date: 2026-08-08
Status: approved (with one change: drop `cargo:tock` from the manifest)

## Problem

The original `dot_bashrc` ran installers at every interactive shell
startup (`_install_ble`, `_install_rust` via `curl | sh rustup`, and
`cargo install` for each Rust tool). This produced noisy failures on
fresh machines and made shell startup slow, fragile, and
network-dependent.

Requirements established with the user:

- Keep the functionality: ble.sh, Rust/cargo, starship, fzf, and the
  cargo tools (cloc, flamegraph).
- No check-and-install at bash startup — startup must be pure
  configuration.
- No separate manual step (e.g. `dotfiles-install`) after
  `chezmoi init --apply`; the bootstrap must be automatic but run
  exactly once per machine.

## Decision

Bootstrap chain:

```
chezmoi (verified manual install, unchanged trust anchor)
  -> chezmoi init --apply
    -> run_onchange_after_install-tools.sh.tmpl
      -> installs mise if missing
      -> mise install (reads manifest deployed by the same apply)
      -> installs ble.sh if missing (not available via mise)
```

chezmoi stays the manually installed, signature-verified trust anchor
(see README); everything downstream is installed by mise.

mise was chosen over aqua (larger community, ~32k vs ~1.8k GitHub
stars, single manifest covers GitHub-release tools and cargo packages)
and over a plain ad-hoc script (declarative manifest, version pinning,
clean upgrade path). mise also takes over managing Rust itself
(`rust = "stable"`); the rustup toolchain under `~/.cargo` becomes
redundant and is shadowed by mise shims.

## Components

### 1. Manifest: `home/private_dot_config/mise/config.toml`

Deployed to `~/.config/mise/config.toml` (mise's global config; trusted
by default, so no `mise trust` step):

```toml
[tools]
rust = "stable"
starship = "latest"
fzf = "latest"
"cargo:cloc" = "latest"
"cargo:flamegraph" = "latest"
```

Editing this file in the repo + `chezmoi update` is the upgrade path.

### 2. Bootstrap: `home/run_onchange_after_install-tools.sh.tmpl`

- `run_onchange_after_`: runs after files are applied, so the manifest
  is already in place when `mise install` runs.
- The template embeds the manifest's sha256
  (`{{ include "private_dot_config/mise/config.toml" | sha256sum }}`),
  so the script re-runs exactly when the tool list changes.
- Steps (each idempotent):
  1. Install mise to `~/.local/bin` via the official `mise.run`
     installer, only if `mise` is not already available.
  2. `mise install` — installs only missing tools.
  3. Install ble.sh from the nightly tarball to `~/.local/share`, only
     if `~/.local/share/blesh/ble.sh` is missing (mise has no ble.sh
     package, so this stays a custom step).
- `set -euo pipefail`; logs each step; a network failure aborts the
  apply loudly rather than leaving half-installed state.

### 3. `home/dot_bashrc` — pure configuration

- PATH: `~/.local/share/mise/shims`, `~/.local/bin`, `~/.cargo/bin`
  (dedup-safe, only if they exist; shims first so mise-managed tools
  win over any leftover rustup/cargo installs). No `mise activate`
  subprocess at startup — shims suffice for global tools.
- ble.sh: sourced only if the file exists; `ble-import` only when
  `BLE_VERSION` is set (sourcing can fail in TTY-less sessions);
  `ble-attach` at the end, guarded as before.
- starship: `eval "$(starship init bash)"` guarded by `command -v`.
- fzf: `eval "$(fzf --bash)"` guarded by `command -v`, and only when
  ble.sh is NOT loaded (ble.sh has its own fzf integration via
  `ble-import`; loading both would double-bind keys). This replaces the
  old `~/.fzf` git-clone flow entirely.
- All `_install_*` / `dotfiles-install` functions are removed.

### 4. README

New section describing the tool-management chain (chezmoi trust anchor
-> run_onchange script -> mise manifest) and the upgrade workflow.

## Error handling

- Every install step checks before acting; re-running the script is
  safe and cheap.
- Script failures propagate (`set -euo pipefail`) so `chezmoi apply`
  reports them.
- bashrc degrades gracefully: any missing tool is simply skipped.

## Testing

- `bash -n` and shellcheck (if available) on the script and bashrc.
- Run the bootstrap script twice: second run must install nothing.
- `chezmoi apply` for real (source = local repo); verify mise, shims,
  and tools appear.
- Fresh empty `HOME` bash startup: clean, no network.
- Real interactive shell: starship prompt active, fzf bindings loaded,
  ble.sh attaches.

## PR handling

This supersedes PR #5 ("Make bashrc startup side-effect free and guard
missing tools"). PR #5 will be closed with a comment pointing to the
new PR; this work lands on branch `feature/mise-managed-tools` off
`main`.
