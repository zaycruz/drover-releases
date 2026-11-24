#!/bin/sh
# One-command standalone installer for Drover: downloads the release binary, verifies its SHA-256 checksum, installs it, and runs `drover init`.
set -eu

say() { printf 'drover-install: %s\n' "$*" >&2; }
die() { say "$*"; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Linux)  printf 'linux' ;;
    Darwin) printf 'macos' ;;
    *)      die "unsupported OS '$(uname -s)': Drover releases support Linux and macOS" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  printf 'x86_64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *)             die "unsupported architecture '$(uname -m)': Drover releases support x86_64/amd64 and aarch64/arm64" ;;
  esac
}

fetch() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 15 --max-time 300 -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries=2 -T 30 -O "$out" "$url"
  else
    die "neither curl nor wget is installed; install curl and retry"
  fi
}

compute_sha256() {
  file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print tolower($1)}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r "$file" | awk '{print tolower($1)}'
  else
    die "no sha256sum, shasum, or openssl found to verify download checksum"
  fi
}

os=$(detect_os)
arch=$(detect_arch)
asset="drover-${os}-${arch}"

releases_base="${DROVER_RELEASES_URL:-https://github.com/zaycruz/drover-releases/releases/latest/download}"
releases_base="${releases_base%/}"
if [ -n "${DROVER_VERSION:-}" ]; then
  ver="${DROVER_VERSION#v}"
  base_root="${releases_base%/latest/download}"
  url="${base_root}/download/v${ver}/${asset}"
else
  case "$releases_base" in
    */latest/download) url="${releases_base}/${asset}" ;;
    *) url="${releases_base}/latest/download/${asset}" ;;
  esac
fi

install_dir="${DROVER_INSTALL_DIR:-$HOME/.local/bin}"
dest="${install_dir}/drover"

tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t drover-install)
trap 'rm -rf "$tmp_dir"' EXIT INT TERM HUP

tmp_bin="${tmp_dir}/${asset}"
tmp_sum="${tmp_bin}.sha256"

say "downloading ${asset} from ${url}"
fetch "$url" "$tmp_bin" || die "failed to download ${url}"
fetch "${url}.sha256" "$tmp_sum" || die "failed to download checksum ${url}.sha256"

want=$(awk '{print tolower($1); exit}' "$tmp_sum")
[ "${#want}" -eq 64 ] || die "invalid SHA-256 checksum file from ${url}.sha256"
got=$(compute_sha256 "$tmp_bin")
[ "$got" = "$want" ] || die "checksum mismatch for ${asset} (expected ${want}, got ${got})"

mkdir -p "$install_dir"
chmod 0755 "$tmp_bin"
mv -f "$tmp_bin" "$dest"
say "installed ${dest} (SHA-256 verified)"

"$dest" init

cat <<EOF

2-Minute Distributed Quickstart:
  1. Add a compute provider:
       drover providers init boat      # or: gke, proxmox, ssh-pool
       drover providers --json
  2. Split work across local + cloud:
       drover set placement.mix "local=50, boat=50"
       drover add "Ship feature X" --on auto --delegate
  3. Enable spot failover & track spend:
       drover set placement.failoverAfter 2m
       drover cost
EOF
