// Injected into the exported copy of budget_app by native/ParityHarness/run.sh.
// Never part of budget_app itself.

DateTime? parityClockOverride;

DateTime parityNow() => parityClockOverride ?? DateTime.now();
