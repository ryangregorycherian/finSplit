class SettlementTransaction {
  final String fromId; // owes money
  final String toId; // is owed money
  final double amount;

  SettlementTransaction({
    required this.fromId,
    required this.toId,
    required this.amount,
  });
}

/// Greedy debt-simplification: repeatedly matches the largest debtor with
/// the largest creditor. This is the standard approach used by real
/// splitting apps to minimize the number of peer-to-peer transactions
/// needed to settle a whole group's balances (Phase 2 + Phase 3 requirement).
class SettlementService {
  static List<SettlementTransaction> simplify(Map<String, double> netBalances) {
    // Work in integer paise to avoid floating point drift.
    final Map<String, int> balances = {
      for (final e in netBalances.entries) e.key: (e.value * 100).round(),
    };
    balances.removeWhere((key, value) => value == 0);

    final List<SettlementTransaction> transactions = [];

    while (balances.isNotEmpty) {
      // Largest creditor (owed the most) and largest debtor (owes the most).
      String? maxCreditor;
      String? maxDebtor;
      int maxCredit = 0;
      int maxDebt = 0;

      balances.forEach((id, bal) {
        if (bal > maxCredit) {
          maxCredit = bal;
          maxCreditor = id;
        }
        if (bal < maxDebt) {
          maxDebt = bal;
          maxDebtor = id;
        }
      });

      if (maxCreditor == null || maxDebtor == null || maxCredit == 0) break;

      final int settled = maxCredit < -maxDebt ? maxCredit : -maxDebt;

      transactions.add(
        SettlementTransaction(
          fromId: maxDebtor!,
          toId: maxCreditor!,
          amount: settled / 100.0,
        ),
      );

      balances[maxCreditor!] = balances[maxCreditor!]! - settled;
      balances[maxDebtor!] = balances[maxDebtor!]! + settled;

      balances.removeWhere((key, value) => value == 0);
    }

    return transactions;
  }

  /// Combines net effects from every expense in a group into one balance
  /// map: participantId -> net amount (positive = owed to them, negative =
  /// they owe the group).
  static Map<String, double> aggregateNetBalances(
    List<Map<String, double>> allExpenseNetEffects,
  ) {
    final Map<String, double> totals = {};
    for (final effects in allExpenseNetEffects) {
      effects.forEach((id, amt) {
        totals[id] = (totals[id] ?? 0) + amt;
      });
    }
    return totals;
  }

  /// Applies already-completed settle-up transfers on top of the expense
  /// balances, so a paid debt stops showing up as outstanding.
  static Map<String, double> applySettlements(
    Map<String, double> balances,
    List<SettlementTransaction> completed,
  ) {
    final Map<String, double> result = Map.of(balances);
    for (final s in completed) {
      result[s.fromId] = (result[s.fromId] ?? 0) + s.amount;
      result[s.toId] = (result[s.toId] ?? 0) - s.amount;
    }
    return result;
  }
}
