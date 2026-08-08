# Dotfiles

A collection of my dotfiles, managed with [chezmoi](https://www.chezmoi.io/).
The source state lives in `home/` (see `.chezmoiroot`).

## Installation

Install a pinned chezmoi release with signature verification, then apply
the dotfiles (linux-amd64; pick a version from
<https://github.com/twpayne/chezmoi/releases>). Requires `cosign`
(`sudo apt install cosign`, or see
<https://docs.sigstore.dev/cosign/system_config/installation/>).

```sh
VERSION=2.72.0
# chezmoi's release-signing public key, pinned here from
# https://github.com/twpayne/chezmoi/blob/master/assets/cosign/cosign.pub
cat > chezmoi-cosign.pub <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEJDy2Dn3u5hqjQkTrcAukXwJty9Ke
oquP+qONwiD4r+cjO8yrhoELoUk1ogXzvpM7f9bOS/YS5pdx2snCmMudDg==
-----END PUBLIC KEY-----
EOF
curl -fsSLO "https://github.com/twpayne/chezmoi/releases/download/v${VERSION}/chezmoi-linux-amd64"
curl -fsSLO "https://github.com/twpayne/chezmoi/releases/download/v${VERSION}/chezmoi_${VERSION}_checksums.txt"
curl -fsSLO "https://github.com/twpayne/chezmoi/releases/download/v${VERSION}/chezmoi_${VERSION}_checksums.txt.sigstore.json"
# --insecure-ignore-sct: chezmoi signs with a plain public key (no
# certificate), so CT-log SCT checks do not apply; the signature and the
# Rekor transparency-log entry are still verified.
cosign verify-blob --key chezmoi-cosign.pub \
  --bundle "chezmoi_${VERSION}_checksums.txt.sigstore.json" \
  --insecure-ignore-sct \
  "chezmoi_${VERSION}_checksums.txt"
grep 'chezmoi-linux-amd64$' "chezmoi_${VERSION}_checksums.txt" | sha256sum -c -
install -m 755 chezmoi-linux-amd64 ~/.local/bin/chezmoi
rm chezmoi-linux-amd64 "chezmoi_${VERSION}_checksums.txt" "chezmoi_${VERSION}_checksums.txt.sigstore.json" chezmoi-cosign.pub
chezmoi init --apply zhaoshenglong/dotfiles
```

The trust anchor is the public key pinned above, so an attacker
substituting release assets cannot produce a valid signature.

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
