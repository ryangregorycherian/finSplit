import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/split_type.dart';
import '../services/firestore_service.dart';
import '../services/settlement_service.dart';

class SimpleExpense {
  final String id;
  final String title;
  final String category;
  final double totalAmount;
  final DateTime timestamp;
  final SplitType splitType;
  final Map<String, double> contributions;
  final Map<String, double> shares;

  SimpleExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.totalAmount,
    required this.timestamp,
    required this.splitType,
    required this.contributions,
    required this.shares,
  });

  Map<String, double> get netEffects {
    final Map<String, double> net = {};
    contributions.forEach((id, amt) => net[id] = (net[id] ?? 0) + amt);
    shares.forEach((id, amt) => net[id] = (net[id] ?? 0) - amt);
    return net;
  }

  factory SimpleExpense.fromDoc(String id, Map<String, dynamic> d) {
    return SimpleExpense(
      id: id,
      title: d['title'] as String,
      category: d['category'] as String,
      totalAmount: (d['totalAmount'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(d['timestampMillis'] as int),
      splitType: SplitType.values.firstWhere((s) => s.name == d['splitType']),
      contributions: (d['contributions'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      shares: (d['shares'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    );
  }
}

class PendingSettlement {
  final String id;
  final String fromId;
  final String toId;
  final double amount;
  PendingSettlement({required this.id, required this.fromId, required this.toId, required this.amount});
}

class ExpenseProvider extends ChangeNotifier {
  List<SimpleExpense> _expenses = [];
  List<SettlementTransaction> _confirmedSettlements = [];
  List<PendingSettlement> _pendingSettlements = [];

  SimpleExpense? _lastDeleted;
  SimpleExpense? get lastDeleted => _lastDeleted;

  List<PendingSettlement> get pendingSettlements => _pendingSettlements;

  void attachToGroup(String groupId) {
    FirestoreService.expensesStream(groupId).listen((snap) {
      _expenses = snap.docs
          .map((d) => SimpleExpense.fromDoc(d.id, d.data() as Map<String, dynamic>))
          .toList();
      notifyListeners();
    });

    FirestoreService.settlementsStream(groupId).listen((snap) {
      final confirmed = <SettlementTransaction>[];
      final pending = <PendingSettlement>[];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'confirmed'; // old records had no status
        final fromId = data['fromId'] as String;
        final toId = data['toId'] as String;
        final amount = (data['amount'] as num).toDouble();
        if (status == 'confirmed') {
          confirmed.add(SettlementTransaction(fromId: fromId, toId: toId, amount: amount));
        } else {
          pending.add(PendingSettlement(id: d.id, fromId: fromId, toId: toId, amount: amount));
        }
      }
      _confirmedSettlements = confirmed;
      _pendingSettlements = pending;
      notifyListeners();
    });
  }

  /// True if there's already an unconfirmed "I've paid" claim for this pair,
  /// so the dashboard doesn't let someone submit a duplicate request.
  bool hasPendingRequest(String fromId, String toId) {
    return _pendingSettlements.any((p) => p.fromId == fromId && p.toId == toId);
  }

  List<SimpleExpense> get all => _expenses;

  double get totalSpend => _expenses.fold(0.0, (sum, e) => sum + e.totalAmount);

  /// Net balance per participant, AFTER accounting for CONFIRMED settle-ups.
  /// Pending (unconfirmed) claims don't move the balance yet.
  Map<String, double> get netBalances {
    final raw = SettlementService.aggregateNetBalances(_expenses.map((e) => e.netEffects).toList());
    return SettlementService.applySettlements(raw, _confirmedSettlements);
  }

  List<SettlementTransaction> get settlementPlan => SettlementService.simplify(netBalances);

  Map<String, double> get categoryBreakdown {
    final Map<String, double> totals = {};
    for (final e in _expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.totalAmount;
    }
    return totals;
  }

  Map<String, double> get monthlyBreakdown {
    final Map<String, double> totals = {};
    for (final e in _expenses) {
      final label = '${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2, '0')}';
      totals[label] = (totals[label] ?? 0) + e.totalAmount;
    }
    return totals;
  }

  Future<void> addExpense({
    required String groupId,
    required String title,
    required String category,
    required double totalAmount,
    required SplitType splitType,
    required Map<String, double> contributions,
    required Map<String, double> shares,
  }) {
    return FirestoreService.addExpense(groupId, {
      'title': title.trim(),
      'category': category,
      'totalAmount': totalAmount,
      'timestampMillis': DateTime.now().millisecondsSinceEpoch,
      'splitType': splitType.name,
      'contributions': contributions,
      'shares': shares,
    });
  }

  Future<void> deleteExpense(String groupId, SimpleExpense expense) async {
    _lastDeleted = expense;
    await FirestoreService.deleteExpense(groupId, expense.id);
  }

  Future<void> undoDelete(String groupId) async {
    final e = _lastDeleted;
    if (e == null) return;
    await addExpense(
      groupId: groupId,
      title: e.title,
      category: e.category,
      totalAmount: e.totalAmount,
      splitType: e.splitType,
      contributions: e.contributions,
      shares: e.shares,
    );
    _lastDeleted = null;
  }

  /// Debtor claims they've paid — creates a pending request awaiting the
  /// creditor's confirmation. Does not move the balance yet.
  Future<void> requestSettlement(String groupId, SettlementTransaction t) {
    return FirestoreService.requestSettlement(
      groupId,
      fromId: t.fromId,
      toId: t.toId,
      amount: t.amount,
    );
  }

  /// Creditor confirms — this is what actually clears the debt.
  Future<void> confirmSettlement(String groupId, String settlementId) {
    return FirestoreService.confirmSettlement(groupId, settlementId);
  }

  /// Creditor disputes a claimed payment.
  Future<void> rejectSettlement(String groupId, String settlementId) {
    return FirestoreService.rejectSettlement(groupId, settlementId);
  }
}
