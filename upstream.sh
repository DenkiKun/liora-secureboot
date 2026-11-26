#!/usr/bin/bash
# Prints "<version> <url> <sha256>" of the newest official release of a
# package Liora builds from its publisher's GitHub releases (Waywallen and its
# plugins, Vice), taking the SHA-256 GitHub recorded when the file was
# uploaded (Vice releases only a source tag, which has none: "SKIP").
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
    'waywallen-open-wallpaper-engine waywallen/open-wallpaper-engine  open-wallpaper-engine-VERSION-linux-x86_64.zip'
)

latest_release() {
    local api="https://api.github.com/repos/$1/releases/latest"
    if [[ -n ${GH_TOKEN:-} ]]; then
        curl -fsSL --retry 3 -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' "$api"
    else
        curl -fsSL --retry 3 -H 'Accept: application/vnd.github+json' "$api"
    fi
}

# Vice: the release is the tagged source (no files with checksums).
if [[ ${1:-} == vice-clipper ]]; then
    tag="$(latest_release splitshotz/Vice | jq -r '.tag_name')"
    version="${tag#v}"
    [[ $version =~ ^[0-9][0-9A-Za-z.+_]*$ ]] || { echo "upstream.sh: unexpected version for vice-clipper: $version" >&2; exit 1; }
    printf '%s %s SKIP\n' "$version" "https://github.com/splitshotz/Vice/archive/refs/tags/$tag.tar.gz"
    exit 0
fi

for entry in "${releases[@]}"; do
    read -r package repo asset <<<"$entry"
    [[ $package == "${1:-}" ]] || continue
    json="$(latest_release "$repo")"
    version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$json")"
    [[ $version =~ ^[0-9][0-9A-Za-z.+_]*$ ]] || { echo "upstream.sh: unexpected version for $package: $version" >&2; exit 1; }
    name="${asset//VERSION/$version}"
    # (read fails when there is no such file: let the message below say so.)
    read -r url sha256 < <(jq -r --arg name "$name" '.assets[] | select(.name == $name)
        | "\(.browser_download_url) \(.digest // "" | ltrimstr("sha256:"))"' <<<"$json") || true
    if [[ ${url:-} != https://github.com/"$repo"/releases/download/* || ! ${sha256:-} =~ ^[0-9a-f]{64}$ ]]; then
        printf 'upstream.sh: %s not found (or without a SHA-256) in %s %s; its files: %s\n' \
            "$name" "$repo" "$version" "$(jq -r '[.assets[].name] | join(", ")' <<<"$json")" >&2
        exit 1
    fi
    printf '%s %s %s\n' "$version" "$url" "$sha256"
    exit 0
done
echo "upstream.sh: unknown package: ${1:-}" >&2
exit 1
