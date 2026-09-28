#!/usr/bin/env python3
"""Installs an app build on a named simulator (created if missing, never any
other simulator), optionally seeds a fixture store, and launches it.

Usage: sim_seed.py <simulator-name> <path/to/Budgie.app> [fixture-input-dir]
Example: sim_seed.py Budgie-UI-A build/Budgie.app native/Fixtures/store/typical/input
Prints the simulator UDID.
"""
import json, shutil, subprocess, sys, time
from pathlib import Path

name, app = sys.argv[1], sys.argv[2]
fixture = Path(sys.argv[3]) if len(sys.argv) > 3 else None
BUNDLE = "com.khatruong.budgetbuddy"

def sh(*cmd):
    return subprocess.run(cmd, check=True, text=True, capture_output=True).stdout.strip()

devices = json.loads(sh("xcrun", "simctl", "list", "devices", "-j"))["devices"]
udid = next((d["udid"] for items in devices.values() for d in items if d["name"] == name and d.get("isAvailable", True)), None)
if not udid:
    runtimes = [r for r in json.loads(sh("xcrun", "simctl", "list", "runtimes", "-j"))["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
    udid = sh("xcrun", "simctl", "create", name, "iPhone 17 Pro", sorted(runtimes, key=lambda r: r["version"])[-1]["identifier"])
subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
sh("xcrun", "simctl", "bootstatus", udid, "-b")
sh("xcrun", "simctl", "install", udid, app)
if fixture:
    subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE], capture_output=True)
    store = Path(sh("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data")) / "Library/Application Support/financial_store"
    shutil.rmtree(store, ignore_errors=True)
    store.mkdir(parents=True)
    for item in fixture.iterdir():
        if item.is_file():
            shutil.copy2(item, store / item.name)
sh("xcrun", "simctl", "launch", udid, BUNDLE)
time.sleep(4)
print(udid)
