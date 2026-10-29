# Prebuilt Liora packages

Packages built from the Liora Linux repository (not from Arch's), copied here
so that computers already installed get their updates: the installer's
`[liora-local]` repository only exists on the ISO. `build.sh` signs and
publishes them with the others; a package here must have a higher version
than the one the ISOs carry.

| Package | Built from |
|---|---|
| `liora-branding` | `packaging/liora-branding` (with `LIORA_SRC` at the repository root) |

Keep only the newest version of each package.
