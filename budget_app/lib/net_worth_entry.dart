import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

enum NetWorthEntryType {
  asset,
  liability,
}

String netWorthMonthKey(DateTime date) {
  final normalized = DateTime(date.year, date.month);
  return DateFormat('yyyy-MM').format(normalized);
}

String netWorthDayKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return DateFormat('yyyy-MM-dd').format(normalized);
}

DateTime netWorthMonthFromKey(String monthKey) {
  final parts = monthKey.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

DateTime netWorthDayFromKey(String dayKey) {
  final parts = dayKey.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String formatNetWorthMonth(DateTime date) {
  final normalized = DateTime(date.year, date.month);
  return DateFormat('MMMM y').format(normalized);
}

DateTime endOfNetWorthMonth(DateTime month) {
  return DateTime(month.year, month.month + 1)
      .subtract(const Duration(milliseconds: 1));
}

DateTime endOfNetWorthDay(DateTime date) {
  return DateTime(date.year, date.month, date.day + 1)
      .subtract(const Duration(milliseconds: 1));
}

class NetWorthSnapshot {
  final DateTime recordedAt;
  final double amount;

  String get monthKey => netWorthMonthKey(recordedAt);
  String get dayKey => netWorthDayKey(recordedAt);

  const NetWorthSnapshot({
    required this.recordedAt,
    required this.amount,
  });

  factory NetWorthSnapshot.forDate({
    required DateTime date,
    required double amount,
    DateTime? recordedAt,
  }) {
    return NetWorthSnapshot(
      recordedAt: recordedAt ?? date,
      amount: amount,
    );
  }

  factory NetWorthSnapshot.fromJson(Map<String, dynamic> json) {
    final recordedAtValue = json['recordedAt'] as String?;
    final legacyMonthKey = json['monthKey'] as String?;
    final legacyUpdatedAt = json['updatedAt'] as String?;

    late final DateTime recordedAt;
    if (recordedAtValue != null && recordedAtValue.isNotEmpty) {
      recordedAt = DateTime.parse(recordedAtValue);
    } else if (legacyMonthKey != null && legacyMonthKey.isNotEmpty) {
      final month = netWorthMonthFromKey(legacyMonthKey);
      final parsedUpdatedAt = legacyUpdatedAt == null || legacyUpdatedAt.isEmpty
          ? null
          : DateTime.tryParse(legacyUpdatedAt);
      recordedAt = parsedUpdatedAt != null &&
              parsedUpdatedAt.year == month.year &&
              parsedUpdatedAt.month == month.month
          ? parsedUpdatedAt
          : month;
    } else {
      recordedAt = legacyUpdatedAt == null || legacyUpdatedAt.isEmpty
          ? DateTime.now()
          : DateTime.parse(legacyUpdatedAt);
    }

    return NetWorthSnapshot(
      recordedAt: recordedAt,
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'recordedAt': recordedAt.toIso8601String(),
        'amount': amount,
      };
}

class NetWorthEntry {
  final String id;
  final String name;
  final NetWorthEntryType type;
  final DateTime createdAt;
  final List<NetWorthSnapshot> snapshots;

  NetWorthEntry({
    String? id,
    required this.name,
    required this.type,
    DateTime? createdAt,
    List<NetWorthSnapshot>? snapshots,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        snapshots = List<NetWorthSnapshot>.from(snapshots ?? const []);

  factory NetWorthEntry.fromJson(Map<String, dynamic> json) {
    return NetWorthEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      type: (json['type'] as String) == 'liability'
          ? NetWorthEntryType.liability
          : NetWorthEntryType.asset,
      createdAt: DateTime.parse(json['createdAt'] as String),
      snapshots: (json['snapshots'] as List<dynamic>? ?? const [])
          .map(
            (snapshot) =>
                NetWorthSnapshot.fromJson(snapshot as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type == NetWorthEntryType.asset ? 'asset' : 'liability',
        'createdAt': createdAt.toIso8601String(),
        'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
      };

  NetWorthEntry copyWith({
    String? name,
    NetWorthEntryType? type,
    DateTime? createdAt,
    List<NetWorthSnapshot>? snapshots,
  }) {
    return NetWorthEntry(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      snapshots: snapshots ?? this.snapshots,
    );
  }

  NetWorthSnapshot? snapshotForMonth(DateTime month) {
    NetWorthSnapshot? latest;

    for (final snapshot in snapshots) {
      if (snapshot.recordedAt.year != month.year ||
          snapshot.recordedAt.month != month.month) {
        continue;
      }

      if (latest == null || snapshot.recordedAt.isAfter(latest.recordedAt)) {
        latest = snapshot;
      }
    }

    return latest;
  }

  NetWorthSnapshot? latestSnapshotThrough(DateTime date) {
    NetWorthSnapshot? latest;

    for (final snapshot in snapshots) {
      if (snapshot.recordedAt.isAfter(date)) {
        continue;
      }

      if (latest == null || snapshot.recordedAt.isAfter(latest.recordedAt)) {
        latest = snapshot;
      }
    }

    return latest;
  }

  double? amountAt(DateTime date) {
    return latestSnapshotThrough(date)?.amount;
  }

  double? amountForMonth(DateTime month) {
    return amountAt(endOfNetWorthMonth(month));
  }

  bool hasSnapshotForMonth(DateTime month) {
    return snapshotForMonth(month) != null;
  }

  NetWorthEntry withSnapshot({
    required DateTime date,
    required double amount,
  }) {
    final updatedSnapshot = NetWorthSnapshot.forDate(
      date: date,
      amount: amount,
    );

    final updatedSnapshots = snapshots
        .where((snapshot) => snapshot.recordedAt != updatedSnapshot.recordedAt)
        .toList()
      ..add(updatedSnapshot);

    updatedSnapshots.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    return copyWith(snapshots: updatedSnapshots);
  }
}

enum NetWorthHistoryGranularity {
  day,
  month,
}

class NetWorthHistoryPoint {
  final DateTime date;
  final double assets;
  final double liabilities;
  final int assetCount;
  final int liabilityCount;
  final NetWorthHistoryGranularity granularity;

  const NetWorthHistoryPoint({
    required this.date,
    required this.assets,
    required this.liabilities,
    required this.assetCount,
    required this.liabilityCount,
    this.granularity = NetWorthHistoryGranularity.day,
  });

  double get netWorth => assets - liabilities;
}
