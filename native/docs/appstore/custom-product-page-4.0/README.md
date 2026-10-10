# Custom product page: Budgie 4.0, all new

For App Store Connect > Budgie > Custom Product Pages > (+).

## Reference name (internal only)

```
Budgie 4.0 - All-new native app
```

## Promotional text (170 / 170 characters)

```
Budgie 4.0 is all new: rebuilt as a fast, native iPhone app. Say what you spent, see what's safe to spend today, and watch your net worth grow. No account, no bank login.
```

Shorter alternative (131):

```
All-new Budgie 4.0, rebuilt natively for iPhone. Log expenses by voice, know what's safe to spend, and track net worth. No bank login.
```

## Screenshots: iPhone 6.9" display (1320 x 2868, RGB, no alpha)

Upload in this order. App Store Connect scales the 6.9" set down to every
smaller iPhone size, so this is the only set needed (the app is iPhone-only).

| # | File | Headline |
|---|---|---|
| 1 | `01-home.png` | Your money, made clearer. |
| 2 | `02-voice.png` | Just say what you spent. |
| 3 | `03-safe-to-spend.png` | Know what you can spend today. |
| 4 | `04-net-worth.png` | Watch your net worth grow. |
| 5 | `05-spending.png` | See where it all goes. |
| 6 | `06-goals.png` | Save for what matters. |
| 7 | `07-insights.png` | Stay ahead of your month. |
| 8 | `08-private.png` | No account. No bank login. |

The first three appear in search results and above the fold, so they carry
the "all new" message, the headline feature (voice) and the daily number.

## Keywords (optional)

Custom product pages can be assigned keywords so they show in search. Pick from
the keywords already on the main listing; good fits for this page: budget,
expense tracker, net worth, voice, savings goals, spending.

## Deep link (optional)

Leave empty. The app has no deep link that lands on a "what's new" screen, and
sending new users straight to Add Expense would skip onboarding.

## Before submitting

- Submit this page once 4.0 is live (or alongside it). It shows the 4.0 UI; if
  it went live while 3.4.0 is the current version, the screenshots would not
  match the app people download.
- Voice entry sends the recording to OpenAI (disclosed in onboarding and the
  privacy label). The page avoids claiming everything stays on the device.

## How these were made

Refreshed October 10, 2026 with the approved blue bird logo from version
4.0.0 build 4. Raw screens: native Debug build on an isolated iPhone 17 Pro
Max simulator (iOS 27.0), using the fictional demo store retained in
`native/Marketing/AppStore-4.0/source/demo-store/`, status bar overridden to
9:41. Light and dark screens were captured by the isolated XCUITest in
`source/CustomPageCaptureUITests.swift`; the recording screen uses the
existing Debug audio stub, with no real microphone or network requests.

Frames: HTML rendered with headless Chrome using the app's Gabarito and
Spline Sans Mono fonts and Paper / Midnight palettes. Original captures
are in `raw/`; `source/render-assets.cjs` regenerates the final images,
self-contained HTML layouts and `overview.jpg`. Run it with Node from
the repository root. Size, opacity and hashes are in `validation.json`.
