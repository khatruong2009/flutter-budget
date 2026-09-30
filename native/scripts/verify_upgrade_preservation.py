#!/usr/bin/env python3
"""Check complete persisted data and safety-copy hashes after an upgrade rehearsal.

Usage: python3 native/scripts/verify_upgrade_preservation.py <rehearsal-directory>
The input must be a completed upgrade_rehearsal.py run with S1, S3, S4 and S5.
This reads synthetic rehearsal evidence only; it never accesses an installed app.
"""
import hashlib
import json
import plistlib
import sys
from pathlib import Path


def verify(root):
    issues = []
    checks = []

    def check(condition, label):
        (checks if condition else issues).append(label)

    def payload(folder):
        return json.loads((folder / "financial_store/financial_store_v2.json").read_bytes().split(b"\n", 1)[1])

    report = json.loads((root / "report.json").read_text())
    for scenario in ["s1_typical_roundtrip", "s3_legacy_only", "s4_locked_launch", "s5_corruption"]:
        check(scenario in report["scenarios"] and "error" not in report["scenarios"][scenario], scenario + " completed")
    check(bool(report["dartProblems"]) and all(not value for value in report["dartProblems"].values()), "Flutter accepted all pulled stores")
    check(bool(report["swiftVsDart"]) and all(not value for value in report["swiftVsDart"].values()), "Flutter and Swift totals, cursors and settings match")

    typical = root / "s1_typical_roundtrip"
    original = payload(typical / "1-flutter")
    upgraded = payload(typical / "2-swift")
    check(set(original).issubset(upgraded), "Every original financial section remains")
    for name, value in original.items():
        # Launch can materialise category definitions for old category labels.
        # Every pre-existing definition, field and order must still be intact.
        same = upgraded.get(name) == value if name != "categories" else upgraded.get(name, [])[:len(value)] == value
        check(same, name + ": every original value preserved after upgrade")
    source = typical / "1-flutter/financial_store"
    copies = list((typical / "2-swift/pre-native-migration").glob("*/financial_store"))
    check(any(all((copy / file.name).exists() and (copy / file.name).read_bytes() == file.read_bytes()
                  for file in source.iterdir() if file.is_file()) for copy in copies), "Pre-native safety copy equals original Flutter files byte for byte")
    edited = typical / "3-swift-edited/financial_store/financial_store_v2.json"
    rollback = typical / "4-flutter-back/financial_store/financial_store_v2.backup.json"
    check(edited.read_bytes() == rollback.read_bytes(), "Flutter rollback preserved Swift's saved file byte for byte")

    with open(typical / "1-flutter/preferences.plist", "rb") as file:
        before_prefs = plistlib.load(file)
    with open(typical / "2-swift/preferences.plist", "rb") as file:
        after_prefs = plistlib.load(file)
    for key in ["flutter.themeMode", "flutter.onboarding_completed"]:
        check(before_prefs.get(key) == after_prefs.get(key), key + " preserved")

    snapshots = list(root.glob("**/pre-native-migration/*/COMPLETE"))
    check(bool(snapshots), "Complete safety copies exist")
    for marker in snapshots:
        folder = marker.parent
        manifest = json.loads((folder / "manifest.json").read_text())
        for entry in manifest["files"]:
            data = (folder / "financial_store" / entry["name"]).read_bytes()
            check(len(data) == entry["size"] and hashlib.sha256(data).hexdigest() == entry["sha256"],
                  str(folder.relative_to(root)) + "/" + entry["name"] + " verified")
        for name, field in [("preferences.plist", "preferencesSha256"), ("app-group.plist", "appGroupSha256")]:
            check(hashlib.sha256((folder / name).read_bytes()).hexdigest() == manifest[field],
                  str(folder.relative_to(root)) + "/" + name + " verified")

    locked = report["scenarios"]["s4_locked_launch"]["whileLocked"]
    check(locked["nothingWrittenWhileLocked"] and bool(locked["firstWriteSecondsAfterLaunch"])
          and all(time >= locked["lockSeconds"] for time in locked["firstWriteSecondsAfterLaunch"].values()),
          "No observed store or safety-copy writes while simulated locked")
    damaged = root / "s5_corruption/2-blocked"
    names = [file.name for file in (damaged / "financial_store").iterdir()]
    check(len([name for name in names if ".corrupt-" in name]) == 2
          and "financial_store_v2.json" not in names and "financial_store_v2.backup.json" not in names
          and not (damaged / "swift-summary.json").exists(), "Both damaged files retained and app blocked")
    return {"checks": checks, "issues": issues, "physicalDeviceVerified": False, "releaseArchiveVerified": False}


if __name__ == "__main__":
    root = Path(sys.argv[1])
    try:
        result = verify(root)
    except (OSError, KeyError, ValueError, TypeError) as error:
        result = {"checks": [], "issues": ["Incomplete or invalid rehearsal evidence: " + str(error)]}
    (root / "preservation-audit.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"passed": len(result["checks"]), "issues": result["issues"]}, indent=2))
    sys.exit(1 if result["issues"] else 0)
