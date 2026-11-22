# Prebuilt Liora packages

Liora's own packages (built from the Liora Linux repository, and Redstone from
its own; not from Arch's), copied here
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
| `redstone` | Liora's notes app, from its own private repository (`DenkiKun/redstone`): its `packaging/liora-publish.sh` builds it and puts it here. The version grows with every commit (`0.1.0.r<commits>.g<hash>`), so `pacman -Syu` picks up each one published. |

The `liora-*` packages are built with `LIORA_SRC` set to the `LioraLinux` folder of the Liora repository. The ISO's `[liora-local]` takes `redstone` from here too (`scripts/build-local-repo.sh`).

Keep only the newest version of each package.
