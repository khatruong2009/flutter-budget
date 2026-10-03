// Injected into the exported copy of budget_app by native/ParityHarness/run.sh.
// Never part of budget_app itself.

import 'dart:math';

import 'package:uuid/uuid.dart';

DateTime? parityClockOverride;

DateTime parityNow() => parityClockOverride ?? DateTime.now();

Random? _uuidRandom;

/// Makes every UUID the app generates deterministic (null restores random).
void seedParityUuids(int? seed) {
  _uuidRandom = seed == null ? null : Random(seed);
}

/// A version-4 UUID, lowercase, from the seeded generator when seeded.
String parityUuidV4() {
  final random = _uuidRandom;
  if (random == null) return const Uuid().v4();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
