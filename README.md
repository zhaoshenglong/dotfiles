# Dotfiles

A collection of my dotfiles, managed with [chezmoi](https://www.chezmoi.io/).
The source state lives in `home/` (see `.chezmoiroot`).

## Installation

One command bootstraps chezmoi and applies the dotfiles:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply zhaoshenglong/dotfiles
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
