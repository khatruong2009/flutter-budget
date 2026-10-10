#!/usr/bin/env python3
"""Export the approved Budgie artwork into the apps' existing asset slots.

Uses macOS sips for PNG size exports and the project's pinned launcher tool
for Android, web, Windows and macOS. Run from the repository root.
"""

import json
from pathlib import Path
import re
import subprocess


BRANDING = Path(__file__).resolve().parent
ROOT = BRANDING.parent.parent
ICON = BRANDING / 'budgie-icon.png'
MARK = BRANDING / 'budgie-mark.png'


def export(source, destination, width, height=None):
    subprocess.run(
        ['sips', '-z', str(height or width), str(width), str(source),
         '--out', str(destination)],
        check=True, stdout=subprocess.DEVNULL,
    )


def dimensions(path):
    output = subprocess.check_output(
        ['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(path)], text=True,
    )
    return tuple(int(re.search(rf'{key}: (\d+)', output)[1])
                 for key in ['pixelWidth', 'pixelHeight'])


def export_catalog(catalog, source):
    contents = json.loads((catalog / 'Contents.json').read_text())
    for image in contents['images']:
        destination = catalog / image['filename']
        if 'size' in image:
            scale = float(image['scale'].removesuffix('x'))
            width, height = (round(float(value) * scale)
                             for value in image['size'].split('x'))
        else:
            width, height = dimensions(destination)
        export(source, destination, width, height)


def main():
    flutter = ROOT / 'budget_app'
    export(ICON, flutter / 'assets/icon.png', 1024)
    export(MARK, flutter / 'assets/budgie_mark.png', 512)

    for assets in [
        ROOT / 'native/Budgie/Resources/Assets.xcassets',
        flutter / 'ios/Runner/Assets.xcassets',
    ]:
        export_catalog(assets / 'AppIcon.appiconset', ICON)
        export_catalog(assets / 'logo.imageset', MARK)
    export_catalog(flutter / 'ios/Runner/Assets.xcassets/LaunchImage.imageset', MARK)

    for assets in [ROOT / 'native/BudgetWidgets/Assets.xcassets',
                   flutter / 'ios/BudgetWidgets/Assets.xcassets']:
        export_catalog(assets / 'BudgieLogo.imageset', MARK)

    for destination in (flutter / 'android/app/src/main/res').glob('mipmap-*/launch_image.png'):
        export(MARK, destination, *dimensions(destination))

    mac_catalog = flutter / 'macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'
    mac_contents = mac_catalog.read_text()
    subprocess.run(['dart', 'run', 'flutter_launcher_icons'], cwd=flutter, check=True)
    # The generator uses the same slots; retain the checked-in JSON formatting.
    mac_catalog.write_text(mac_contents)
    for path in [flutter / 'web/manifest.json',
                 flutter / 'android/app/src/main/res/values/colors.xml']:
        path.write_text(path.read_text().rstrip() + '\n')

    # The pinned 0.13 launcher generator fills all 108dp of the adaptive
    # foreground. Inset our character so its tuft and wings fit round masks.
    adaptive = flutter / 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'
    adaptive.write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground>
    <inset android:drawable="@drawable/ic_launcher_foreground" android:inset="12%"/>
  </foreground>
</adaptive-icon>
''')
    print('Exported Budgie icons, launch marks and widget logos for both apps.')


if __name__ == '__main__':
    main()
