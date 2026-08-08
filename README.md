# Dotfiles

A collection of my dotfiles, managed with [chezmoi](https://www.chezmoi.io/).
The source state lives in `home/` (see `.chezmoiroot`).

## Installation

One command bootstraps chezmoi and applies the dotfiles:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply zhaoshenglong/dotfiles
```

### Verified install (recommended)

The one-liner above executes a mutable remote script. For a pinned
version with checksum verification instead (linux-amd64; pick a version
from <https://github.com/twpayne/chezmoi/releases>):

```sh
VERSION=2.72.0
curl -fsSLO "https://github.com/twpayne/chezmoi/releases/download/v${VERSION}/chezmoi-linux-amd64"
curl -fsSLO "https://github.com/twpayne/chezmoi/releases/download/v${VERSION}/chezmoi_${VERSION}_checksums.txt"
grep 'chezmoi-linux-amd64$' "chezmoi_${VERSION}_checksums.txt" | sha256sum -c -
install -m 755 chezmoi-linux-amd64 ~/.local/bin/chezmoi
rm chezmoi-linux-amd64 "chezmoi_${VERSION}_checksums.txt"
chezmoi init --apply zhaoshenglong/dotfiles
```

## Daily usage

```sh
chezmoi update          # pull the repo and re-apply
chezmoi edit ~/.bashrc  # edit a managed file in the source state
chezmoi diff            # preview what apply would change
chezmoi apply           # apply the source state
```

## Testing

Apply the source state into a throwaway destination instead of `$HOME`:

```sh
chezmoi init --apply --source /path/to/this/repo --destination /tmp/dotfiles-test
```
