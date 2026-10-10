# Blue bird release — October 10, 2026

Budgie 4.0.0 build 4 uses the approved blue bird Savings Pal branding. The
same icon and logo catalogs are installed in the Flutter app; the 4.0.0
release package is the native replacement app.

## Prepared artifacts

- Signed archive in Xcode Organizer:
  `/Users/khatruong/Library/Developer/Xcode/Archives/2026-10-10/Budgie 4.0.0 (4) Blue Bird.xcarchive`
- Locally exported App Store-signed IPA:
  `native/Release/Budgie-4.0.0-4/Budgie.ipa`
- Export settings, distribution summary and validation manifest live beside
  the IPA. `native/Release/` is ignored by Git.
- Main artwork: `native/Marketing/AppStore-4.0/`, also packaged as
  `native/Marketing/Budgie-AppStore-4.0.zip`.
- Largest iPhone screenshot set and custom page:
  `native/docs/appstore/custom-product-page-4.0/`.
- Approved masters and export instructions: `design/branding/README.md`.

## Verification

The Release archive built with zero warnings. App and widget versions both
read 4.0.0 (4). Archive and exported IPA signatures verified. Xcode Organizer
reported: "Budgie 4.0.0 (4) validated" and "Your app successfully passed all
validation checks." This was validation only; the build has not been
uploaded or submitted for review.

Flutter analysis is clean and all 390 Flutter tests passed. All 404
BudgieCore tests, cross-language parity in three time zones, `ui_flow.sh`
and `system_flow.sh` passed for the branding update. Financial behavior
was unchanged.

The approved blue bird is the sole brand mark in the repository. App
launcher icons, headers, splash images, widgets and release artwork use
it. Research and migration datasets and reports remain available; only
outdated branding screenshots were removed during cleanup.

## Re-exporting

Xcode's Apple `rsync` can invoke the Homebrew `rsync` server through PATH,
which rejects Apple's extended-attribute flag and causes "Copy failed".
Export using the system tool path:

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
  -archivePath '/Users/khatruong/Library/Developer/Xcode/Archives/2026-10-10/Budgie 4.0.0 (4) Blue Bird.xcarchive' \
  -exportPath /tmp/budgie-appstore-export \
  -exportOptionsPlist native/Release/Budgie-4.0.0-4/ExportOptions.plist \
  -allowProvisioningUpdates
```

## Next release step

Upload build 4 from Organizer or the IPA through Transporter, replace the
App Store Connect screenshot and creative slots with these refreshed
files, select the processed build, and submit for review. Apple review
approval is separate from successful archive validation.
