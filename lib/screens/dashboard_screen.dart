import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/group_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/balance_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final myUid = FirebaseService.uid;
    final groupId = groupProvider.activeGroupId;

    if (groupId == null) return const Center(child: Text('No active group'));

    final total = expenseProvider.totalSpend;
    final balances = expenseProvider.netBalances;
    final plan = expenseProvider.settlementPlan;

    // Confirmations only YOU (the creditor) can action.
    final myConfirmations = expenseProvider.pendingSettlements.where((p) => p.toId == myUid).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(groupProvider.activeGroupName ?? '', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Total group spend', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    final code = groupProvider.activeJoinCode ?? '';
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Join code "$code" copied — share it with your group')),
                    );
                  },
                  child: Chip(
                    avatar: const Icon(Icons.copy, size: 16),
                    label: Text('Join code: ${groupProvider.activeJoinCode ?? '...'}'),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (myConfirmations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Awaiting your confirmation', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...myConfirmations.map((p) {
            final fromName = groupProvider.participantName(p.fromId) ?? '?';
            final scheme = Theme.of(context).colorScheme;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fromName says they paid you ₹${p.amount.toStringAsFixed(2)}',
                      style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => expenseProvider.confirmSettlement(groupId, p.id),
                          child: const Text('Confirm received'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => expenseProvider.rejectSettlement(groupId, p.id),
                          style: TextButton.styleFrom(foregroundColor: scheme.onTertiaryContainer),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('Net standing', style: Theme.of(context).textTheme.titleMedium),
        ),
        ...groupProvider.activeParticipants.map(
          (p) => BalanceCard(name: p.name, amount: balances[p.id] ?? 0),
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('Settle up (fewest transfers)', style: Theme.of(context).textTheme.titleMedium),
        ),
        if (plan.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Everyone is settled up. 🎉'),
          )
        else
          ...plan.map((t) {
            final fromName = groupProvider.participantName(t.fromId) ?? '?';
            final toName = groupProvider.participantName(t.toId) ?? '?';
            final iAmDebtor = t.fromId == myUid;
            final alreadyClaimed = expenseProvider.hasPendingRequest(t.fromId, t.toId);

            Widget trailingAction;
            if (iAmDebtor) {
              trailingAction = alreadyClaimed
                  ? Text('Waiting for $toName', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                  : TextButton(
                      onPressed: () => expenseProvider.requestSettlement(groupId, t),
                      child: const Text("I've paid"),
                    );
            } else if (alreadyClaimed) {
              trailingAction = const Text('Pending confirmation', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12));
            } else {
              trailingAction = const SizedBox();
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: const Icon(Icons.arrow_forward_rounded),
                title: Text('$fromName → $toName'),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text('₹${t.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailingAction,
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }
}
