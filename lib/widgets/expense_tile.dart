import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';

const Map<String, IconData> categoryIcons = {
  'Ride': Icons.directions_car_rounded,
  'Food': Icons.fastfood_rounded,
  'Subscription': Icons.subscriptions_rounded,
  'Printout': Icons.print_rounded,
  'Other': Icons.receipt_long_rounded,
};

class ExpenseTile extends StatelessWidget {
  final SimpleExpense expense;
  final VoidCallback onDelete;

  const ExpenseTile({super.key, required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final icon = categoryIcons[expense.category] ?? Icons.receipt_long_rounded;
    final timeFmt = DateFormat('MMM d, h:mm a').format(expense.timestamp);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${expense.category} • $timeFmt'),
          trailing: Text(
            '₹${expense.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
