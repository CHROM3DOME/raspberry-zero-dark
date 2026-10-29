#!/usr/bin/env python3
"""
Pi Tin System Volume Combo Installer for GPIOnext
Registers hardware button combos in GPIOnext's SQLite database:
  - Hold Fn (BCM Pin 0) + Tap D-Pad Up   (BCM Pin 23) -> amixer set PCM 5%+
  - Hold Fn (BCM Pin 0) + Tap D-Pad Down (BCM Pin 17) -> amixer set PCM 5%-
"""

import argparse
import os
import sqlite3
import subprocess
import sys

sys.stdout.reconfigure(line_buffering=True, errors='replace')
sys.stderr.reconfigure(line_buffering=True, errors='replace')

DEFAULT_DB_PATHS = [
    "/home/pi/GPIOnext/config/config.db",
    "/home/pi/gpionext/config/config.db",
]


def find_db_path(custom_path=None):
    if custom_path:
        return custom_path if os.path.isfile(custom_path) else None
    for path in DEFAULT_DB_PATHS:
        if os.path.isfile(path):
            return path
    return None


def configure_volume_combos(db_path, fn_pin=0, up_pin=23, down_pin=17):
    conn = sqlite3.connect(db_path, timeout=10.0)
    try:
        cur = conn.cursor()
        combos = [
            ("Commands", "Volume Up", "COMMAND", "amixer set PCM 5%+", f"{fn_pin},{up_pin}"),
            ("Commands", "Volume Down", "COMMAND", "amixer set PCM 5%-", f"{fn_pin},{down_pin}"),
        ]
        for device, name, ctype, command, pins in combos:
            cur.execute(
                "DELETE FROM GPIOnext WHERE device = ? AND (name = ? OR pins = ?)",
                (device, name, pins),
            )
            cur.execute(
                "INSERT INTO GPIOnext (device, name, type, command, pins) VALUES (?, ?, ?, ?, ?)",
                (device, name, ctype, command, pins),
            )
            print(f"[+] Registered GPIOnext combo: {name} (pins={pins}) -> `{command}`", flush=True)
        conn.commit()
    finally:
        conn.close()


def restart_gpionext():
    try:
        res = subprocess.run(
            ["sudo", "-n", "systemctl", "restart", "gpionext"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if res.returncode == 0:
            print("[+] Restarted gpionext.service successfully.", flush=True)
        else:
            print(
                "[!] Note: Run `sudo systemctl restart gpionext` to apply the new volume combos.",
                flush=True,
            )
    except Exception as exc:
        print(f"[!] Could not auto-restart gpionext ({exc}). Run `sudo systemctl restart gpionext`.", flush=True)


def main():
    parser = argparse.ArgumentParser(description="Configure Pi Tin Fn + D-Pad Up/Down volume combos in GPIOnext.")
    parser.add_argument("--db", help="Path to GPIOnext config.db", default=None)
    parser.add_argument("--no-restart", action="store_true", help="Do not restart gpionext service")
    args = parser.parse_args()

    db_path = find_db_path(args.db)
    if not db_path:
        print(
            "[-] Error: Could not locate GPIOnext config.db. Specify it with `--db /path/to/config.db`.",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(1)

    print(f"[*] Updating GPIOnext database at: {db_path}", flush=True)
    configure_volume_combos(db_path)

    if not args.no_restart:
        restart_gpionext()


if __name__ == "__main__":
    main()
