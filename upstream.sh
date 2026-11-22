#!/usr/bin/bash
# Prints "<version> <url> <sha256>" of the newest official release of a
# package Liora builds from its publisher's GitHub releases (Waywallen and its
# plugins), taking the SHA-256 GitHub recorded when the file was uploaded.
# build.sh (the [liora-secureboot] repository) and the Liora ISO's
# build-local-repo.sh both use it, so the two always build the same release.
#
#   upstream.sh <package>
set -euo pipefail

# <package> <owner/repo> <asset name, with VERSION for the version>
releases=(
    'waywallen-bin                   waywallen/waywallen              waywallen-VERSION-x86_64.AppImage'
    'plasma-wallpaper-waywallen      waywallen/waywallen-display      waywallen-kde-VERSION-x86_64.zip'
    'gnome-shell-extension-waywallen waywallen/waywallen-display      waywallen-gnome-VERSION-x86_64.zip'
    'waywallen-open-wallpaper-engine waywallen/open-wallpaper-engine  org.waywallen.open-wallpaper-engine-VERSION-linux-x86_64.zip'
)

for entry in "${releases[@]}"; do
    read -r package repo asset <<<"$entry"
    [[ $package == "${1:-}" ]] || continue
    api="https://api.github.com/repos/$repo/releases/latest"
    if [[ -n ${GH_TOKEN:-} ]]; then
        json="$(curl -fsSL --retry 3 -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' "$api")"
    else
        json="$(curl -fsSL --retry 3 -H 'Accept: application/vnd.github+json' "$api")"
    fi
    version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$json")"
    [[ $version =~ ^[0-9][0-9A-Za-z.+_]*$ ]] || { echo "upstream.sh: unexpected version for $package: $version" >&2; exit 1; }
    name="${asset//VERSION/$version}"
    read -r url sha256 < <(jq -r --arg name "$name" '.assets[] | select(.name == $name)
        | "\(.browser_download_url) \(.digest // "" | ltrimstr("sha256:"))"' <<<"$json")
    [[ ${url:-} == https://github.com/"$repo"/releases/download/* && ${sha256:-} =~ ^[0-9a-f]{64}$ ]] ||
        { echo "upstream.sh: $name not found (or without a SHA-256) in $repo's latest release" >&2; exit 1; }
    printf '%s %s %s\n' "$version" "$url" "$sha256"
    exit 0
done
echo "upstream.sh: unknown package: ${1:-}" >&2
exit 1
