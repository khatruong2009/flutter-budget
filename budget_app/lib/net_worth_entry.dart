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

DateTime netWorthMonthFromKey(String monthKey) {
  final parts = monthKey.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

String formatNetWorthMonth(DateTime date) {
  final normalized = DateTime(date.year, date.month);
  return DateFormat('MMMM y').format(normalized);
}

class NetWorthSnapshot {
  final String monthKey;
  final double amount;
  final DateTime updatedAt;

  const NetWorthSnapshot({
    required this.monthKey,
    required this.amount,
    required this.updatedAt,
  });

  factory NetWorthSnapshot.forMonth({
    required DateTime month,
    required double amount,
    DateTime? updatedAt,
  }) {
    return NetWorthSnapshot(
      monthKey: netWorthMonthKey(month),
      amount: amount,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory NetWorthSnapshot.fromJson(Map<String, dynamic> json) {
    return NetWorthSnapshot(
      monthKey: json['monthKey'] as String,
      amount: (json['amount'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'amount': amount,
        'updatedAt': updatedAt.toIso8601String(),
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
    final monthKey = netWorthMonthKey(month);
    for (final snapshot in snapshots) {
      if (snapshot.monthKey == monthKey) {
        return snapshot;
      }
    }
    return null;
  }

  NetWorthSnapshot? latestSnapshotThrough(DateTime month) {
    final targetMonthKey = netWorthMonthKey(month);
    NetWorthSnapshot? latest;

    for (final snapshot in snapshots) {
      if (snapshot.monthKey.compareTo(targetMonthKey) > 0) {
        continue;
      }

      if (latest == null ||
          snapshot.monthKey.compareTo(latest.monthKey) > 0 ||
          (snapshot.monthKey == latest.monthKey &&
              snapshot.updatedAt.isAfter(latest.updatedAt))) {
        latest = snapshot;
      }
    }

    return latest;
  }

  double? amountForMonth(DateTime month) {
    return latestSnapshotThrough(month)?.amount;
  }

  bool hasSnapshotForMonth(DateTime month) {
    return snapshotForMonth(month) != null;
  }

  NetWorthEntry withAmountForMonth({
    required DateTime month,
    required double amount,
  }) {
    final monthKey = netWorthMonthKey(month);
    final updatedSnapshot = NetWorthSnapshot.forMonth(
      month: month,
      amount: amount,
    );

    final updatedSnapshots = snapshots
        .where((snapshot) => snapshot.monthKey != monthKey)
        .toList()
      ..add(updatedSnapshot);

    updatedSnapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));

    return copyWith(snapshots: updatedSnapshots);
  }
}

class NetWorthMonthSummary {
  final DateTime month;
  final double assets;
  final double liabilities;

  const NetWorthMonthSummary({
    required this.month,
    required this.assets,
    required this.liabilities,
  });

  double get netWorth => assets - liabilities;
}
