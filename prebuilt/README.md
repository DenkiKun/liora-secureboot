# Prebuilt Liora packages

Packages built from the Liora Linux repository (not from Arch's), copied here
so that computers already installed get their updates: the installer's
`[liora-local]` repository only exists on the ISO. `build.sh` signs and
publishes them with the others; a package here must have a higher version
than the one the ISOs carry.

| Package | Built from |
|---|---|
| `liora-branding` | `packaging/liora-branding` |
| `liora-system` | `packaging/liora-system` (Liora's system defaults; `liora-branding` depends on it) |
| `liora-apps` | `packaging/liora-apps` |
| `liora-automation` | `packaging/liora-automation` |
| `liora-trading`, `liora-webapp`, `liora-tradingview`, `liora-metatrader5`, `liora-ibkr-tws`, `liora-freqtrade` | `packaging/liora-trading` |

Each is built with `LIORA_SRC` set to the `LioraLinux` folder of the repository.

Keep only the newest version of each package.
