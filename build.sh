#!/usr/bin/bash
# Builds Liora's Secure Boot packages from Arch Linux's current kernel and
# NVIDIA modules, signs them with Liora's keys, and with PUBLISH=1 publishes
# them as a pacman repository: the assets of this GitHub repository's "repo"
# release. GitHub Actions runs it every few hours (.github/workflows/build.yml);
# it does nothing when Arch has released nothing new.
#
# Runs as root in an Arch Linux container. Needs:
#   LIORA_SB_KEY    Secure Boot private key, PEM (repository secret)
#   LIORA_GPG_KEY   package signing key, armored (repository secret)
#   GH_TOKEN        for PUBLISH=1
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo=liora-secureboot
tag=repo
out="$here/out"
work="$(mktemp -d /tmp/liora-sb.XXXXXX)"
trap 'rm -rf "$work"' EXIT
# pacman downloads as its unprivileged alpm user.
chmod 755 "$work"

pacman -Syu --noconfirm --needed base-devel sbsigntools grub linux-headers zstd github-cli git >/dev/null
git config --global --add safe.directory "$here"
recipe_rel="$(git -C "$here" rev-list --count HEAD -- packages/liora-secureboot 2>/dev/null || echo 1)"
id builder >/dev/null 2>&1 || useradd -m builder

# The keys, readable by the unprivileged user makepkg runs as.
keys="$work/keys"
install -d -m 700 -o builder "$keys"
printf '%s\n' "${LIORA_SB_KEY:?}" | install -m 600 -o builder /dev/stdin "$keys/liora-secureboot.key"
export LIORA_SB_KEY_FILE="$keys/liora-secureboot.key" LIORA_SB_CERT="$here/keys/liora.pem"
export GNUPGHOME="$work/gnupg"
install -d -m 700 "$GNUPGHOME"
gpg --batch --quiet --import <<<"${LIORA_GPG_KEY:?}"
fpr="$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr/ { print $10; exit }')"

# Arch's packages, checked against Arch's signatures by pacman.
install -d "$work/arch"
pacman -Sw --noconfirm --nodeps --nodeps --cachedir "$work/arch" linux nvidia-open >/dev/null
linux_pkg="$(ls "$work"/arch/linux-[0-9]*.pkg.tar.zst | sort -V | tail -n 1)"
nvidia_pkg="$(ls "$work"/arch/nvidia-open-[0-9]*.pkg.tar.zst | sort -V | tail -n 1)"
version() { bsdtar -xOf "$1" .PKGINFO | awk '$1 == "pkgver" { print $3 }'; }
modules_dir() { bsdtar -tf "$1" | grep -m 1 -o '^usr/lib/modules/[^/]*/' | cut -d/ -f4; }
kernel="$(version "$linux_pkg")"
nvidia="$(version "$nvidia_pkg")"

# Arch releases the NVIDIA modules for a new kernel together with it, but
# not always in the same minute: publish the kernel only with modules for it.
if [[ "$(modules_dir "$nvidia_pkg")" != "$(modules_dir "$linux_pkg")" ]]; then
    printf 'nvidia-open %s is not built for linux %s yet; trying again later.\n' "$nvidia" "$kernel"
    exit 0
fi

recipes="$(cd "$here" && find build.sh keys packages -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16)"
state="linux=$kernel nvidia-open=$nvidia $(pacman -Q grub | tr ' ' '=') liora-secureboot-rel=$recipe_rel recipes=$recipes"
if [[ ${PUBLISH:-} == 1 ]]; then
    published="$(gh release download "$tag" --repo "${GITHUB_REPOSITORY:?}" --pattern state.txt --output - 2>/dev/null || true)"
    if [[ $state == "$published" ]]; then
        printf 'Up to date: %s\n' "$state"
        exit 0
    fi
fi
printf 'Building: %s\n' "$state"

build() {
    local name=$1 dir="$work/build/$1"
    shift
    install -d -o builder "$work/build"
    cp -r "$here/packages/$name" "$dir"
    [[ $name == liora-secureboot ]] && cp "$here/keys/liora.cer" "$dir/"
    (( $# )) && cp "$@" "$dir/"
    chown -R builder "$dir"
    runuser -u builder -- env LIORA_SB_KEY_FILE="$LIORA_SB_KEY_FILE" LIORA_SB_CERT="$LIORA_SB_CERT" \
        LIORA_KERNEL="$kernel" LIORA_RECIPE_REL="$recipe_rel" LIORA_SIGN_FILE="$(ls /usr/lib/modules/*/build/scripts/sign-file | head -n 1)" \
        bash -c "cd '$dir' && makepkg --nodeps --noconfirm --noprogressbar" >/dev/null
    cp "$dir/$name"-[0-9]*.pkg.tar.zst "$out/"
}

rm -rf "$out"
install -d "$out"
build linux-liora "$linux_pkg"
build nvidia-open-liora "$nvidia_pkg"
build liora-secureboot

for package in "$out"/*.pkg.tar.zst; do
    gpg --batch --yes --local-user "$fpr" --detach-sign "$package"
done
repo-add --quiet --sign --key "$fpr" "$out/$repo.db.tar.gz" "$out"/*.pkg.tar.zst
# Release assets cannot be links: pacman asks for $repo.db and $repo.files.
for file in db files; do
    rm -f "$out/$repo.$file" "$out/$repo.$file.sig"
    cp "$out/$repo.$file.tar.gz" "$out/$repo.$file"
    cp "$out/$repo.$file.tar.gz.sig" "$out/$repo.$file.sig"
done
printf '%s\n' "$state" >"$out/state.txt"
ls -l "$out"

[[ ${PUBLISH:-} == 1 ]] || exit 0
gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1 ||
    gh release create "$tag" --repo "$GITHUB_REPOSITORY" --title 'Liora Secure Boot repository' \
        --notes 'pacman repository of Liora Linux signed kernel, NVIDIA modules and boot chain. Updated automatically.'
# The new packages and database first, then the superseded packages go.
gh release upload "$tag" --repo "$GITHUB_REPOSITORY" --clobber "$out"/*
gh release view "$tag" --repo "$GITHUB_REPOSITORY" --json assets --jq '.assets[].name' |
    while read -r asset; do
        [[ -e "$out/$asset" ]] || gh release delete-asset "$tag" "$asset" --repo "$GITHUB_REPOSITORY" --yes
    done
