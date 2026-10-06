# Budgie 4.0 App Store artwork

English artwork captured from the native Swift app, built from commit `46e035a`, using an isolated iPhone 17 Pro simulator on iOS 27. All financial data is fictional. Created October 5, 2026.

## Upload files

| Placement | Folder | Size | Count |
| --- | --- | --- | --- |
| iPhone with Dynamic Island (medium display) | `screenshots/` | 1206 × 2622 | 7 |
| Product page header | `creative/header-3840x1646.png` | 3840 × 1646 | 1 |
| Search results | `creative/search-results-3840x2560.png` | 3840 × 2560 | 1 |
| Alternate search results, featuring goals | `creative/search-results-goals-3840x2560.png` | 3840 × 2560 | 1 |

Use screenshots in numerical order: dashboard, spending categories, goals, net worth, cash-flow trends, Paper theme, recurring transactions. Choose one of the two search-result options. These are dedicated header and search assets, not the universal 16:9 asset.

All upload files are PNG, sRGB, without an alpha channel. Actual interfaces are embedded intact in editable HTML layouts, with a stylized device frame and Dynamic Island. The original captures are in `raw/`. The screenshot capture flow passed its UI assertions; final images were visually reviewed and dimension/alpha/color checked. This is artwork verification, not a release-readiness audit.

Apple specifications verified October 5, 2026:
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications

Creative assets appear on iOS/iPadOS 27 and later. App Store Connect's Header and Search Results preview should be used to confirm placement cropping before submission. If the app supports iPad, Apple also requires iPad screenshots; this pack covers the requested iPhone placement.

## Editable sources

`source/*.html` are self-contained layouts with the fonts and images embedded. Open them in a browser; text, colors and layout can be edited directly. `source/render-assets.cjs` generates all final images and the contact sheet using local Chrome. It references the repository's existing Gabarito fonts and Budgie logo. `source/demo-store/` contains only the fictional seed data used for the captures. The capture test and seed script are retained for reproduction; the temporary capture project did not change app source.

## Generated background

The brand background was created with the built-in imagegen tool. All app interfaces come from simulator captures. Prompt:

> Use case: ads-marketing. Create a premium abstract brand background for Budgie, a calm personal budgeting app. Landscape 3:2 composition at highest resolution. Very dark midnight charcoal (#07090D) background with a sculptural arrangement of broad satin-finish circular ribbon arcs in pale mint (#5EE6B0), pale lilac (#B3ADFF) and restrained coral (#FF8B7B), recalling a spending donut chart and steady financial growth. Rings and arcs occupy only the rightmost 45% of the image, gently cropped at the right edge; leave the left 55% uniformly dark with generous empty space for a later headline and real app screens. Crisp elegant editorial composition, soft realistic studio shadow, sophisticated and understated. No text, no logos, no currency symbols, no coins, no devices, no interface, no people, no watermark. Opaque background.
