import 'dart:math';

/// Handles the math for all three split modes required by Phase 2.
class SplitCalculator {
  /// Uniform split: divides [total] evenly across [participantIds], and
  /// distributes any leftover paise/cents (from integer rounding) to the
  /// first N participants so the shares always sum exactly to [total].
  static Map<String, double> uniform(
    List<String> participantIds,
    double total,
  ) {
    if (participantIds.isEmpty) return {};
    final int totalPaise = (total * 100).round();
    final int n = participantIds.length;
    final int basePaise = totalPaise ~/ n;
    final int remainder = totalPaise - (basePaise * n);

    final Map<String, double> shares = {};
    for (int i = 0; i < n; i++) {
      // Distribute the leftover 1-paise units to the first `remainder` people.
      final paise = basePaise + (i < remainder ? 1 : 0);
      shares[participantIds[i]] = paise / 100.0;
    }
    return shares;
  }

  /// Specific value split: caller supplies exact per-person amounts directly.
  /// This helper just reports how much of [total] remains unallocated, so
  /// the UI can show a live running total as the user types.
  static double unallocated(Map<String, double> enteredAmounts, double total) {
    final entered = enteredAmounts.values.fold<double>(0, (a, b) => a + b);
    return double.parse((total - entered).toStringAsFixed(2));
  }

  /// Ratio/percentage split: converts percentages (must sum to ~100) into
  /// exact currency shares, again fixing rounding remainders precisely.
  static Map<String, double> ratio(
    Map<String, double> percentages,
    double total,
  ) {
    final ids = percentages.keys.toList();
    if (ids.isEmpty) return {};
    final int totalPaise = (total * 100).round();

    // First pass: floor each share.
    final List<int> floors = [];
    final List<double> remainders = [];
    for (final id in ids) {
      final exact = (percentages[id]! / 100.0) * totalPaise;
      floors.add(exact.floor());
      remainders.add(exact - exact.floor());
    }

    int distributed = floors.fold(0, (a, b) => a + b);
    int leftover = totalPaise - distributed;

    // Distribute leftover paise to whoever had the largest fractional remainder.
    final order = List<int>.generate(ids.length, (i) => i)
      ..sort((a, b) => remainders[b].compareTo(remainders[a]));

    for (int i = 0; i < leftover; i++) {
      floors[order[i % order.length]] += 1;
    }

    final Map<String, double> shares = {};
    for (int i = 0; i < ids.length; i++) {
      shares[ids[i]] = floors[i] / 100.0;
    }
    return shares;
  }

  static double sum(Iterable<double> values) =>
      values.fold(0, (a, b) => a + b);

  static double maxAbsDiff(double a, double b) => (a - b).abs();
}
