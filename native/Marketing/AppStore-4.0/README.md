# Budgie 4.0 App Store artwork

English artwork refreshed October 10, 2026 from the native Swift app, version 4.0.0 build 4, with the approved blue bird logo. Captured using an isolated iPhone 17 Pro simulator on iOS 27. All financial data is fictional. Original layouts created October 5, 2026.

## Upload files

| Placement | Folder | Size | Count |
| --- | --- | --- | --- |
| iPhone with Dynamic Island (medium display) | `screenshots/` | 1206 × 2622 | 7 |
| Product page header | `creative/header-3840x1646.png` | 3840 × 1646 | 1 |
| Search results | `creative/search-results-3840x2560.png` | 3840 × 2560 | 1 |
| Alternate search results, featuring goals | `creative/search-results-goals-3840x2560.png` | 3840 × 2560 | 1 |

Use screenshots in numerical order: dashboard, spending categories, goals, net worth, cash-flow trends, Paper theme, recurring transactions. Choose one of the two search-result options. These are dedicated header and search assets, not the universal 16:9 asset.

All upload files are PNG, sRGB, without an alpha channel. Actual interfaces are embedded intact in editable HTML layouts, with a stylized device frame and Dynamic Island. The original captures are in `raw/`. The screenshot capture flow passed its UI assertions; final images were visually reviewed and dimension/alpha/color checked. This is artwork verification, not a release-readiness audit.

Apple screenshot specifications rechecked October 10, 2026; creative specifications checked October 5, 2026:
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications

Creative assets appear on iOS/iPadOS 27 and later. App Store Connect's Header and Search Results preview should be used to confirm placement cropping before submission. If the app supports iPad, Apple also requires iPad screenshots; this pack covers the requested iPhone placement.

## Editable sources

`source/*.html` are self-contained layouts with the fonts and images embedded. Open them in a browser; text, colors and layout can be edited directly. `source/render-assets.cjs` generates all final images and the contact sheet using local Chrome. It references the repository's existing Gabarito fonts and Budgie logo. `source/demo-store/` contains only the fictional seed data used for the captures. The capture test and seed script are retained for reproduction; the temporary capture project did not change app source.

## Header and creative artwork

The header pairs the approved blue bird Savings Pal mascot with a real
Home dashboard capture. Its savings pocket and coin connect the brand to
the budgeting app. The full-resolution transparent master is retained in
`design/branding/budgie-mark.png`. Search creative uses real Home or Goals
screens on a clean Midnight background.
