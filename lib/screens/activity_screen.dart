import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/expense_tile.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final groupId = groupProvider.activeGroupId;

    if (groupId == null) return const Center(child: Text('No active group'));

    final expenses = expenseProvider.all;

    if (expenses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No expenses logged yet.\nTap "+" to log your first ride, meal, or subscription split.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return ExpenseTile(
          expense: expense,
          onDelete: () async {
            await expenseProvider.deleteExpense(groupId, expense);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${expense.title}"'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () => expenseProvider.undoDelete(groupId),
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        );
      },
    );
  }
}
