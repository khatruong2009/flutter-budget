import 'package:flutter/foundation.dart';

import 'atomic_financial_store.dart';

/// Tracks which sections of a model have in-memory changes that the store has
/// not yet confirmed on disk, and offers a retry.
///
/// A mutation updates memory first so the UI responds immediately, then
/// awaits the durable write. If that write fails the section is flagged as
/// unsaved, the failure is logged and exposed through [lastSaveError], and
/// listeners are notified so the app can show the state and offer a retry.
/// Every later successful save of any section also carries the flagged
/// sections, so one working write heals everything.
mixin PersistenceStatus on ChangeNotifier {
  final Set<String> _unsavedSections = <String>{};
  String? _lastSaveError;

  /// True while some change in memory is not yet on disk.
  bool get hasUnsavedChanges => _unsavedSections.isNotEmpty;

  /// The most recent persistence failure, cleared by the next success.
  String? get lastSaveError => _lastSaveError;

  /// Sections that are flagged as unsaved, for diagnostics and tests.
  Set<String> get unsavedSections => Set.unmodifiable(_unsavedSections);

  /// Serializes the current in-memory value of [section]. Used both for the
  /// initial write and for retries.
  @protected
  dynamic serializeSection(String section);

  /// Persists [sections] (already serialized) together with any sections
  /// still flagged as unsaved. Returns whether the write was verified on
  /// disk. Never throws: a failure flags the sections and notifies.
  @protected
  Future<bool> persistSections(Map<String, dynamic> sections) async {
    final payload = <String, dynamic>{
      for (final section in _unsavedSections)
        if (!sections.containsKey(section)) section: serializeSection(section),
      ...sections,
    };
    try {
      await AtomicFinancialStore.instance.updateSections(payload);
    } catch (error, stackTrace) {
      debugPrint(
        'Persistence failed for ${payload.keys.join(', ')}: $error\n$stackTrace',
      );
      _unsavedSections.addAll(payload.keys);
      _lastSaveError = error.toString();
      notifyListeners();
      return false;
    }
    final wasFlagged = _unsavedSections.isNotEmpty;
    _unsavedSections.removeAll(payload.keys);
    if (wasFlagged && _unsavedSections.isEmpty) {
      _lastSaveError = null;
      notifyListeners();
    }
    return true;
  }

  /// Re-attempts every flagged section. Returns true when nothing is left
  /// unsaved afterwards.
  Future<bool> retryPendingSaves() async {
    if (_unsavedSections.isEmpty) return true;
    return persistSections(<String, dynamic>{
      for (final section in _unsavedSections.toList())
        section: serializeSection(section),
    });
  }
}
