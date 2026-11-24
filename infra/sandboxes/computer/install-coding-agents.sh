#!/bin/sh
# Installs the coding agent CLIs a bot can run inside its computer: Claude Code, Codex and the
# Antigravity CLI (agy). Each is the vendor's own release, checked against a published checksum.
# Sign-in is never baked in: the person signs each CLI in once inside the computer, and the home
# volume keeps it.
#   Codex: pinned release, sha256 below (bump the version and both hashes together).
#   Claude Code: pinned version through the official installer, which checks its own manifest.
#   agy: the official installer's latest build, which it checks with the manifest's sha512. The
#        vendor offers no way to pin it, so the version is whatever was current at build time.
# agy lands in <lib-folder> because /usr/local/bin/agy is Rakazo's wrapper (see rakazo-agy).
set -eu
bin="${1:?usage: install-coding-agents.sh <bin-folder> <lib-folder>}"
lib="${2:?usage: install-coding-agents.sh <bin-folder> <lib-folder>}"
codex_version=0.171.0
claude_version=2.1.331
case "$(uname -m)" in
  x86_64 | amd64) codex_arch=x86_64; codex_sha256=01baa2e47809f8597be5b2f8abd4e4dfe3fb5bcb6e504c2fbaaad97056c15e8d ;;
  aarch64 | arm64) codex_arch=aarch64; codex_sha256=bcf50b836385e51bd2976ab2bbe92b1b08a1cbe37712eb8dbe378aa78d24871c ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$bin" "$lib"

# Release downloads sometimes answer 502/503/504 for a while; --retry repeats those.
fetch() { curl -fsSL --retry 5 "$1" -o "$2"; }

archive="codex-${codex_arch}-unknown-linux-musl.tar.gz"
fetch "https://github.com/openai/codex/releases/download/rust-v${codex_version}/${archive}" "$work/codex.tar.gz"
echo "$codex_sha256  $work/codex.tar.gz" | sha256sum -c -
mkdir "$work/codex"
tar -xzf "$work/codex.tar.gz" -C "$work/codex"
install -m 755 "$work/codex/codex-${codex_arch}-unknown-linux-musl" "$bin/codex"

# Each installer writes under $HOME, so give it a scratch one and copy the binary out.
mkdir "$work/claude-home"
fetch https://claude.ai/install.sh "$work/claude-install.sh"
HOME="$work/claude-home" bash "$work/claude-install.sh" "$claude_version"
install -m 755 "$(readlink -f "$work/claude-home/.local/bin/claude")" "$bin/claude"

mkdir "$work/agy-home"
fetch https://antigravity.google/cli/install.sh "$work/agy-install.sh"
HOME="$work/agy-home" bash "$work/agy-install.sh" --dir "$work/agy-home/bin"
install -m 755 "$work/agy-home/bin/agy" "$lib/agy"

"$bin/codex" --version
"$bin/claude" --version
"$lib/agy" --version
