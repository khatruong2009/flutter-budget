# Voice expense entry — implementation plan

Self-contained spec for adding voice-based transaction entry to Budgie. Written 2026-07-07
against commit `8ae99db` (post "floating dock" UI revamp). All file:line references were
verified at that commit — re-verify any reference before editing if the file has changed since.

## Feature summary

The user taps a mic button (or a home-screen widget), speaks a phrase like
"twelve fifty for lunch at Chipotle yesterday", and the app records the audio, transcribes it
(OpenAI `gpt-4o-mini-transcribe`), parses it into a structured transaction
(OpenAI `gpt-5.4-nano`, JSON mode), and opens the **existing** add-transaction dialog prefilled
for the user to review, correct, and confirm. Nothing is ever saved without the user tapping Add.

Pipeline: `record` package captures ~10s AAC → `dart_openai` transcription → `dart_openai`
chat parse → prefilled `showTransactionForm` → existing `TransactionModel.addTransaction`.

Cost is negligible (~$0.001/entry). The OpenAI key ships in the app bundle via the existing
`.env` mechanism — accepted for v1, flagged for revisit before wide distribution.

## Verified constraints (do not "upgrade" these)

- Local toolchain: Flutter 3.38.5 / Dart 3.10.4.
- `record` MUST be `^6.2.1`. record 7.x requires Dart ^3.12 / Flutter >=3.44 and will fail
  `pub get` on this machine. The 6.x API is identical for our needs.
- `dart_openai` stays pinned `^4.0.0` (resolves 4.1.4). Do NOT upgrade to 6.x (breaking rewrite).
  - `OpenAI.instance.audio.createTranscription({required File file, required String model, String? prompt, OpenAIAudioResponseFormat? responseFormat, ...})` — model is a free string.
  - Transcription: OMIT `responseFormat` (server default json; `gpt-4o-mini-transcribe` supports
    ONLY json). dart_openai reads the json body's `text` field natively.
  - Chat parse: pass ONLY `model`, `messages`, and `responseFormat: {'type': 'json_object'}`.
    Never pass `maxTokens` or `temperature` — gpt-5.x models reject `max_tokens` and any
    temperature != 1, and dart_openai 4.x cannot send `max_completion_tokens`.
- Model IDs (live as of 2026-07-04, verify at implementation): `gpt-4o-mini-transcribe`
  (STT, ~$0.003/min), `gpt-5.4-nano` (parse, $0.20/M in / $1.25/M out).
- Android minSdk: leave `build.gradle` untouched — `flutter.minSdkVersion` is already 24,
  above record's 23 floor.
- Lint gate on this machine: use `dart analyze` (NOT `flutter analyze`, which crashes — known
  local SDK tool bug).

## Ordered implementation steps

### Step 1 — Dependencies, assets, CI, platform config

1. `pubspec.yaml`: add `record: ^6.2.1` to dependencies; add `- .env` under `flutter: assets:`.
   (This also fixes the existing broken Insights/chat feature: `lib/chat.dart` calls
   `dotenv.load('.env')` but `.env` was never a declared asset, so it throws at runtime today.)
2. `.github/workflows/main.yml`: `.env` is gitignored, and a declared-but-missing asset hard-fails
   `flutter test`. Add a step BEFORE format/analyze/test (working-directory `budget_app`):
   `echo "OPEN_AI_API_KEY=" > .env`
   Note: CI also runs `dart format --set-exit-if-changed .` — all new/edited files must be
   format-clean.
3. `ios/Runner/Info.plist`: add `NSMicrophoneUsageDescription` = "Budgie uses the microphone so
   you can add transactions by speaking." Do NOT add NSSpeechRecognitionUsageDescription —
   we never use SFSpeechRecognizer.
4. `android/app/src/main/AndroidManifest.xml` (currently has ZERO permissions): add
   `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` and
   `<uses-permission android:name="android.permission.INTERNET"/>` (INTERNET is missing in
   release builds today and also fixes chat there).
5. macOS build fix (record's pod requires 10.15; project pins 10.14): `macos/Podfile` →
   `platform :osx, '10.15'`; all three `MACOSX_DEPLOYMENT_TARGET` entries in
   `macos/Runner.xcodeproj/project.pbxproj` → `10.15`. No entitlement changes — the feature is
   gated to iOS/Android at runtime.

Gate: `flutter pub get` succeeds; `flutter build macos --debug` still builds.

### Step 2 — `lib/voice_expense_service.dart` (new)

Mirror `lib/chat.dart`'s key-loading pattern (`await dotenv.load(fileName: '.env')`,
`OpenAI.apiKey = dotenv.env['OPEN_AI_API_KEY']!`).

```dart
class VoiceExpenseException implements Exception {
  final String message;      // user-facing, e.g. "Didn't catch anything — try again"
  final String? transcript;  // set when parsing failed, so UI can show what was heard
}

class VoiceExpenseService {
  Future<String> transcribe(File audio);                      // throws VoiceExpenseException on empty transcript
  Future<Transaction> parse(String transcript, DateTime today);
  static Transaction parseVoiceJson(String llmOutput, String transcript, DateTime today); // pure, unit-testable
}
```

- `transcribe`: `createTranscription(file: audio, model: 'gpt-4o-mini-transcribe',
  prompt: 'Personal expense phrases with dollar amounts like $12.50 and merchant names.')`.
  Empty/whitespace result → throw.
- `parse` system prompt must include: today's date AND weekday (device local, for
  "yesterday"/"last Tuesday"); the exact category vocabularies (see below); required JSON shape
  `{"type","description","amount","category","date"}`; rules: default type expense unless
  explicit income wording ("got paid", "salary", "received"); "twelve fifty" → 12.50;
  date defaults to today, never future; if the speech is not a transaction at all return
  `{"error":"not_a_transaction"}`.
- Category vocabularies come from `lib/common.dart` (`expenseCategories.keys`,
  `incomeCategories.keys`). Current sets — expense (13): General, Eating Out, Groceries, Housing,
  Transportation, Travel, Clothing, Gift, Health, Entertainment, Pets, Family, Loan Payment;
  income (4): Salary, Investment, Gift, Other. Read them from the maps at runtime, don't
  hardcode.
- `parseVoiceJson` rules:
  - Strip markdown fences; `jsonDecode`; decode failure or `error` key → throw
    `VoiceExpenseException` carrying the transcript.
  - `type`: clamp to income/expense, default expense.
  - `category`: exact match against the parsed type's map keys; fallback `'General'`
    (expense) / `'Other'` (income).
  - `amount`: to double; missing/invalid → `0.0` (sentinel = unknown; form leaves field empty).
  - `description`: missing/empty → use the raw transcript.
  - `date`: ISO parse; invalid → today; clamp to `[DateTime(2000), today]`.
  - Returns the existing `Transaction` class (`lib/transaction.dart`) — no new model.
    Note the enum is spelled `TransactionTyp`.

### Step 3 — `lib/widgets/voice_recording_sheet.dart` (new)

`Future<Transaction?> showVoiceRecordingSheet(BuildContext context)` plus a shared entry helper
`Future<void> startVoiceExpenseFlow(BuildContext context)` that: guards reentry (module-level
bool — covers FAB + deep link both), opens the sheet, and on a non-null result opens the
prefilled form (Step 4) via
`showTransactionForm(context, draft.type, model.addTransaction, prefill: draft)` with a
`context.mounted` check after the await.

State machine: `recording → processing → error`, single StatefulWidget.

Lifecycle rules (all mandatory — each guards a verified failure mode):
- Recording starts when the sheet opens, after `AudioRecorder.hasPermission()` (it triggers the
  OS prompt itself). Permanent denial → message: "Microphone access is off. Enable it in
  Settings > Budgie." No permission_handler dependency.
- `RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 16000, numChannels: 1)`;
  path from `getTemporaryDirectory()` (pattern: `lib/transaction_model.dart` CSV export ~:795).
- Elapsed timer + 30s auto-stop.
- Stop is a no-op unless state == recording; transition state BEFORE the first await.
- `isDismissible: false, enableDrag: false` during processing; drag-dismiss/back during
  recording routes through cancel.
- `dispose()`: cancel timer, stop+dispose recorder, delete temp file.
- Every post-await continuation: `if (!mounted) return;` before setState/pop (otherwise a
  dismissed sheet pops the underlying page route).
- `WidgetsBindingObserver`: `AppLifecycleState.paused` during recording = implicit Stop.
- Retry semantics: temp file + transcript live until sheet close (deleted in dispose).
  Transcribe-failure Retry re-uploads the kept file; parse-failure Retry re-parses the kept
  transcript (show the transcript text in this state); "didn't catch anything" Retry restarts
  recording.
- Success: `Navigator.pop(context, transaction)`.

Visual spec (Budgie post-revamp language — every widget must branch on
`final isDark = Theme.of(context).brightness == Brightness.dark` and use
`AppColors.get*(isDark)`; the app is dual-theme):
- Sheet recipe cloned from the budget-limit sheet `lib/spending_page.dart:171-260`:
  `showModalBottomSheet(isScrollControlled: true, backgroundColor: Colors.transparent)`,
  container `AppColors.getCard(isDark)` + `Border.all(AppColors.getCardBorder(isDark))` +
  top radius 28, `SafeArea(top: false)`, 44x4 drag handle (`getTextTertiaryColor` @0.35,
  radius 999), `viewInsets.bottom` padding.
- "LISTENING" eyebrow label in `AppTypography.eyebrow`; pulsing mic: accent circle with
  `AppColors.glow(accent)` + the ping-ring pattern from `lib/widgets/glow_fab.dart:97-115`,
  skipped under `MediaQuery.disableAnimationsOf`.
- Processing: same layout, accent `CircularProgressIndicator`.
- Error: `Symbols.error_rounded` + message + paired 44px `PillButton`s
  (Cancel textSecondary / "Try again" accent filled) per `lib/savings_goals_page.dart:1156-1180`.
  Do NOT use the legacy `AppButton` here.
- Icons: `material_symbols_icons` `Symbols.mic_rounded` / `stop_rounded` / `error_rounded`,
  weight 500.
- Haptics via `MicroInteractions`: mediumImpact on record start, lightImpact on stop,
  vibrate() on error.

### Step 4 — `lib/transaction_form.dart` changes

Current signature (`:11-13`):
`showTransactionForm(BuildContext, TransactionTyp, Function addTransaction, [Transaction? transactionToEdit])`.

1. Convert the optional positional to named and add prefill:
   `{Transaction? transactionToEdit, Transaction? prefill}`. Exactly ONE call site passes the
   positional arg: `lib/transaction_page.dart:184` — update it to named. Other call sites
   (main.dart:249, main.dart:284, spending_page.dart:472/607/620, transaction_page.dart:61)
   pass 3 args and are unaffected. No tests reference the form.
2. Prefill branch beside the edit branch (`:35-42`): set description/category/amount/selectedDate
   from `prefill`; if `prefill.amount <= 0` leave the amount controller EMPTY (existing
   validation then forces user entry). Add semantics stay "Add" — the delete+re-add edit path
   keys strictly off `transactionToEdit`, which stays null for prefill.
3. New date row (ALWAYS visible — also for manual add and edit), inserted between the category
   picker (ends ~:243) and the action row (~:247). Clone `_DatePickerTile` from
   `lib/savings_goals_page.dart:1471`: `getChipSurface(isDark)` fill, radius 14,
   `getCardBorder` 1px border, `Symbols.event_rounded` 20/500 leading, 12px label "Date" over
   15/600 value (`DateFormat('MMM dd, yyyy')`), `chevron_right_rounded` trailing,
   `MicroInteractions.lightImpact` then `showDatePicker`.
   CRITICAL: `firstDate: DateTime(2000), lastDate: DateTime.now()` — do NOT copy the recurring
   form's `now-365d` firstDate (crashes editing transactions older than a year; also blocks
   future dates, capping LLM hallucinations).
4. Off-month SnackBar: in the Add handler after `addTransaction`, if
   `selectedDate`'s year+month != `transactionModel.selectedMonth`'s, show "Added to {MMMM}".
   Grab `ScaffoldMessenger.of(context)` BEFORE popping. Style: copy the helper at
   `lib/savings_goals_page.dart:604-614` (floating, `AppColors.getSuccess(isDark)`, radius 12).
   Rationale: `currentMonthTransactions` filters by selectedMonth, so a backdated add is
   otherwise invisible.
5. `barrierDismissible: prefill == null` (`:47`) — a stray outside tap must not discard a voice
   draft.
6. Hide the "Make this recurring" link (`:310-350`) when `prefill != null` (it pops and discards
   the draft).

### Step 5 — Mic trigger on SpendingPage

The primary add entry post-revamp is a single 54px `GlowFab` passed to `BudgiePageScaffold.fab`
(`lib/spending_page.dart:470-478`). Placement: a second, smaller mic FAB stacked above it.

1. `lib/widgets/glow_fab.dart`: add a `size` parameter (currently hardcoded 54 at :102/:117-118,
   icon 26 at :146; derive icon size ~= size * 0.48). Default 54 so existing usages
   (spending_page:471, net_worth_page:58/:92, savings_goals_page:100) are untouched.
2. `lib/spending_page.dart`: replace the `fab:` value with
   `Column(mainAxisSize: MainAxisSize.min, children: [GlowFab(size: 44, icon: Symbols.mic_rounded, semanticLabel: 'Add by voice', onPressed: () => startVoiceExpenseFlow(context)), SizedBox(height: 12), <existing GlowFab>])`,
   with the mic gated to `PlatformUtils.isMobile` (`lib/utils/platform_utils.dart:9-62`).
   The `Positioned` anchor in `budgie_page_scaffold.dart:23-28` makes the stack grow upward —
   no metric changes.
   The `semanticLabel` is load-bearing: widget tests locate FABs via `find.bySemanticsLabel`.

### Step 6 — Deep link + home-screen widget (iOS)

Native forwarding needs NO changes — `AppDelegate.swift:92` / `SceneDelegate.swift:80` forward
any `budgetapp://` URL to the `budget_app/deeplink` MethodChannel verbatim.

1. `lib/main.dart` `_handleDeepLink` (`:261-293`): add branch
   `action == 'voice-add' || action == 'voice_add'` → post-frame → `startVoiceExpenseFlow(targetContext)`.
   The handler already awaits `_initializationCompleter` (CRITICAL — adding a transaction before
   `getTransactions()` completes would overwrite all stored history, since persistence rewrites
   the whole list from memory) and dedups repeat links (2s window).
2. Optional 6-line rider: third quick-action `ShortcutItem` `action_voice_add`
   ("Add by Voice", icon `mic.circle.fill`) in `initState` (`:163-174`) + branch in
   `_handleQuickAction` (`:237-259`).
3. `ios/BudgetWidgets/BudgetWidgets.swift`: add `BudgetVoiceAddWidget` IN THE SAME FILE
   (avoids pbxproj target surgery), modeled on the existing `BudgetQuickActionsWidget`:
   `systemSmall`, `StaticConfiguration`, same `BackgroundForVersion` background, one centered
   `mic.fill` button tinted `Color(red: 0.51, green: 0.55, blue: 0.97)` (app accent #818CF8),
   whole-widget tap via `.widgetURL(URL(string: "budgetapp://voice-add")!)` (single-action
   widgets use widgetURL, not Link). Display name "Voice Add", description
   "Speak an expense and Budgie logs it."
4. `ios/BudgetWidgets/BudgetWidgetsBundle.swift`: register `BudgetVoiceAddWidget()`.

UX note: widgets cannot record audio (WidgetKit constraint) — the tap opens the app and the
recording sheet auto-opens listening. Recording must only start once the sheet is actually
visible (never hot-mic during launch).

### Step 7 — Tests and verification

Unit tests (`test/voice_expense_service_test.dart`) for `parseVoiceJson`: category
clamp/fallback per type, type default + income keywords, fence stripping, bad JSON throws with
transcript attached, `error` key throws, missing amount → 0.0, missing description → transcript,
future/ancient date clamping.

Widget test for the prefilled form: fields populated, empty amount field when amount unknown,
date row shows prefilled date, Add calls model with prefilled values. Provider pump pattern:
`test/widget_test.dart` (note it wraps `MyApp` in `AppContainer` post-revamp).

Small test for the `GlowFab` `size` param (three pages share the widget).

Gates, all must pass: `dart format .` (CI enforces `--set-exit-if-changed`),
`dart analyze` (NOT `flutter analyze` — crashes on this machine), `flutter test`,
plus one `flutter build macos --debug` and `flutter build web` sanity build.

Manual device checklist (real iPhone — simulator mic is unreliable):
happy path ("twelve fifty for lunch at Chipotle yesterday" → Eating Out, 12.50, yesterday);
income phrase ("got paid three thousand" → Add Income); missing amount → empty focused field;
silence → "Didn't catch" + retry; airplane mode → error + retry works; permission deny →
settings message; background mid-recording → treated as Stop; drag-dismiss during each state →
clean cancel, no stuck mic indicator; backdated entry → "Added to {month}" SnackBar;
widget tap cold start → app opens then sheet listens; widget tap warm start; light AND dark
theme for every new surface; VoiceOver reads "Add by voice".

## Design-language rules (apply to ALL new UI)

- Dual-theme: branch on `isDark`, use `AppColors.get*(isDark)` — never hardcode dark colors.
- Icons: `Symbols.*_rounded` weight 500 (material_symbols_icons). Leave `lib/common.dart`'s
  CupertinoIcons category maps alone.
- Type: `AppTypography` styles (Gabarito) — no raw TextStyles.
- Buttons: `PillButton` / `GlowFab` — `AppButton` is legacy (only inside the old form dialogs).
- Radius language: 999 pills, 14 fields, 26-28 cards/sheets.
- Haptics through `MicroInteractions`; respect `MediaQuery.disableAnimationsOf`.
- Accessibility (enforced by test/accessibility_test.dart): >=44px touch targets, semantic
  labels on interactive controls, 4.5:1 text contrast.

## Out of scope (v2)

Siri/App Intents, on-device `speech_to_text` offline fallback, in-form income/expense type
toggle, backend key proxy (key ships in bundle for v1), Android home-screen widget.

## Acceptance criteria

1. Speaking a plain expense produces a correctly prefilled Add Expense dialog in under ~5s
   on Wi-Fi; user taps Add and it appears in the list and totals.
2. No code path saves a transaction without the user tapping Add.
3. All failure modes (silence, network, permission, parse) end in a comprehensible sheet state
   with a working Retry or Cancel — never a crash, never a stuck recorder, never a lost route.
4. Existing manual add/edit flows work unchanged apart from the new (functional) date row.
5. CI green: format, analyze, tests, on a fresh clone (placeholder `.env` step).
6. Home-screen "Voice Add" widget opens the app into a listening sheet from cold and warm starts.
