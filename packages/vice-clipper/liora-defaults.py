"""Liora's defaults for Vice, applied to the installed vice package:

- Clip sharing off until the person turns it on in Vice's settings. Upstream
  starts a share server on every network interface and a Cloudflare tunnel
  that publishes it on the internet.
- On Wayland, the screen is recorded through the desktop's screencast portal
  instead of being read from the kernel (KMS capture, gpu-screen-recorder's
  "-w screen"): KMS capture polls the display 60 times a second underneath the
  compositor, and windows flickered on KDE Plasma while Vice ran (2026-11-22).
  The portal asks once which screen to record; the choice is remembered
  (-restore-portal-session). A display picked in Vice's settings, or a "-w"
  in recording.gsr_args, still wins.

Only defaults change: a config.toml the person already has is kept.

    python liora-defaults.py <path to the installed vice package directory>
"""
import re
import sys
from pathlib import Path

package = Path(sys.argv[1])


def fail(what):
    sys.exit(f"vice-clipper: {what} not found; review the recipe (liora-defaults.py)")


# Sharing off by default.
config = package / "config.py"
text = config.read_text()
block = re.search(r"class SharingConfig:\n(.*?)\n\n", text, re.S)
if not block:
    fail("SharingConfig in config.py")
old = block.group(1)
new = re.sub(r"(\n\s+enabled: bool = )True\b", r"\1False", "\n" + old, count=1)[1:]
new = re.sub(r"(\s+cloudflare_tunnel: bool = )True\b", r"\1False", new, count=1)
for field in ("enabled", "cloudflare_tunnel"):
    if not re.search(rf"\b{field}: bool = False\b", new):
        fail(f"SharingConfig.{field} default")
config.write_text(text.replace(old, new, 1))

# The portal on Wayland.
recorder = package / "recorder.py"
text = recorder.read_text()
patches = [
    (
        'def _default_gsr_capture_target() -> str:\n    return "screen"\n',
        'def _liora_target_args(target: str) -> list[str]:\n'
        '    """Liora: the portal asks once; the choice is remembered."""\n'
        '    if target == "portal":\n'
        '        return ["-w", target, "-restore-portal-session", "yes"]\n'
        '    return ["-w", target]\n'
        '\n'
        '\n'
        'def _default_gsr_capture_target() -> str:\n'
        '    # Liora: on Wayland, the desktop\'s screencast portal rather than KMS\n'
        '    # capture, which made windows flicker on KDE Plasma.\n'
        '    if os.environ.get("WAYLAND_DISPLAY") or os.environ.get("XDG_SESSION_TYPE") == "wayland":\n'
        '        return "portal"\n'
        '    return "screen"\n',
    ),
    (
        '    return ["-w", _gsr_capture_target(rc, override)]\n',
        '    return _liora_target_args(_gsr_capture_target(rc, override))\n',
    ),
    (
        '        "-w", _gsr_capture_target(rc, override),\n        "-o", str(out_path),\n',
        '        *_liora_target_args(_gsr_capture_target(rc, override)),\n        "-o", str(out_path),\n',
    ),
]
for old, new in patches:
    if text.count(old) != 1:
        fail(f"in recorder.py: {old.strip().splitlines()[0]!r}")
    text = text.replace(old, new)
recorder.write_text(text)
