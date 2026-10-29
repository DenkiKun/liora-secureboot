# Liora Secure Boot

Secure Boot for [Liora Linux](https://github.com/DenkiKun), an Arch Linux based distribution: the pieces of the boot chain that must be signed, signed with Liora's key, and published as a pacman repository that updates itself.

| Package | What it is |
|---|---|
| `linux-liora` | Arch Linux's `linux` package, unchanged except that its EFI image is signed with the Liora key. Its modules keep Arch's signature (made with the key built into that kernel). |
| `nvidia-open-liora` | Arch Linux's `nvidia-open` modules, signed with the Liora key. Published only together with a matching `linux-liora`. |
| `liora-secureboot` | Fedora's shim (signed by Microsoft), a GRUB image signed with the Liora key, the `liora` certificate and the `liora-secureboot` command that installs them. |

The boot chain: UEFI firmware → shim (Microsoft UEFI CA) → GRUB (Liora key, enrolled as a MOK) → `linux-liora` (Liora key) → modules (Arch's build key, or the Liora key for NVIDIA).

## Signing keys

- Secure Boot certificate: [`keys/liora.pem`](keys/liora.pem) (`CN=liora, O=Liora Linux`), SHA-256 fingerprint `AA:39:27:58:88:34:55:36:2E:54:21:A5:DE:61:65:1F:F5:EE:B3:3C:09:CE:45:60:95:87:CA:D2:24:D5:A3:DB`.
- Package signing key: [`keys/liora-packages.asc`](keys/liora-packages.asc), fingerprint `58AE C268 281D B413 38EF 63B9 D0A7 9680 FBA6 7C8A`.

The private keys exist as repository secrets, used only by the workflow, and as an offline copy kept by the project owner.

## How it updates

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs [`build.sh`](build.sh) every six hours in an Arch Linux container. It downloads Arch's current `linux` and `nvidia-open` packages through pacman (which checks Arch's signatures), signs them, signs the packages and the database with the package key, and replaces the assets of the [`repo` release](../../releases/tag/repo). When Arch has released nothing new, it stops after comparing versions.

## Use

Liora's installer sets this up. By hand, on an Arch-based system with GRUB:

```sh
sudo pacman-key --add liora-packages.asc
sudo pacman-key --lsign-key 58AEC268281DB41338EF63B9D0A79680FBA67C8A
printf '\n[liora-secureboot]\nServer = https://github.com/DenkiKun/liora-secureboot/releases/download/repo\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Sy linux-liora liora-secureboot     # and nvidia-open-liora with an NVIDIA card
sudo liora-secureboot install
```

On the next boot MokManager asks to enroll the `liora` certificate: choose *Enroll MOK*, *Continue*, *Yes*, and type the password `liora`. Then turn on Secure Boot in the firmware settings. `liora-secureboot status` shows what is in place.

When GRUB starts under Secure Boot the kernel also gets `lockdown=integrity`, kexec is disabled, and the BPF LSM is active (Arch's default), the requirements of Easy Anti-Cheat for Linux v2.

## Licenses

The scripts and recipes are GPL-3.0-or-later. The packages carry the licenses of what they contain: the Linux kernel (GPL-2.0), NVIDIA's open modules (MIT/GPL-2.0), shim (BSD-2-Clause) and GRUB (GPL-3.0-or-later).
