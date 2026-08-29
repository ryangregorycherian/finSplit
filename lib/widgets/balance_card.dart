import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final String name;
  final double amount; // positive = owed to them, negative = they owe

  const BalanceCard({super.key, required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    final bool isOwed = amount >= 0;
    final color = amount == 0
        ? Colors.grey
        : (isOwed ? Colors.green.shade600 : Colors.red.shade400);
    final label = amount == 0
        ? 'settled up'
        : (isOwed ? 'is owed' : 'owes');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(label),
        trailing: Text(
          '₹${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
