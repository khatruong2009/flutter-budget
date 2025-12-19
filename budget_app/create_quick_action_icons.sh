#!/bin/bash

# Script to create simple + and - icons for iOS quick actions
# Requires ImageMagick (install with: brew install imagemagick)

echo "Creating quick action icons..."

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Install it with: brew install imagemagick"
    exit 1
fi

# Create plus icons
convert -size 35x35 xc:none -gravity center -stroke white -strokewidth 3 -draw "line 17,8 17,27 line 8,17 26,17" ios/Runner/Assets.xcassets/plus.imageset/plus.png
convert -size 70x70 xc:none -gravity center -stroke white -strokewidth 6 -draw "line 35,16 35,54 line 16,35 54,35" ios/Runner/Assets.xcassets/plus.imageset/plus@2x.png
convert -size 105x105 xc:none -gravity center -stroke white -strokewidth 9 -draw "line 52,24 52,81 line 24,52 81,52" ios/Runner/Assets.xcassets/plus.imageset/plus@3x.png

# Create minus icons
convert -size 35x35 xc:none -gravity center -stroke white -strokewidth 3 -draw "line 8,17 26,17" ios/Runner/Assets.xcassets/minus.imageset/minus.png
convert -size 70x70 xc:none -gravity center -stroke white -strokewidth 6 -draw "line 16,35 54,35" ios/Runner/Assets.xcassets/minus.imageset/minus@2x.png
convert -size 105x105 xc:none -gravity center -stroke white -strokewidth 9 -draw "line 24,52 81,52" ios/Runner/Assets.xcassets/minus.imageset/minus@3x.png

echo "✅ Icons created successfully!"
echo "Now run: flutter clean && flutter run"
