import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/split_type.dart';
import '../providers/expense_provider.dart';
import '../providers/group_provider.dart';
import '../utils/split_calculator.dart';
import '../utils/validators.dart';
import '../widgets/expense_tile.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = 'Food';
  SplitType _splitType = SplitType.uniform;

  // participantId -> included in this expense's split
  final Map<String, bool> _included = {};
  // participantId -> paid amount (multi-payer contributions)
  final Map<String, TextEditingController> _paidCtrls = {};
  // participantId -> specific amount / ratio percentage text controllers
  final Map<String, TextEditingController> _shareCtrls = {};

  String? _errorText;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    for (final c in _paidCtrls.values) c.dispose();
    for (final c in _shareCtrls.values) c.dispose();
    super.dispose();
  }

  void _ensureControllers(List<SimpleParticipant> participants) {
    for (final p in participants) {
      _included.putIfAbsent(p.id, () => true);
      _paidCtrls.putIfAbsent(p.id, () => TextEditingController());
      _shareCtrls.putIfAbsent(p.id, () => TextEditingController());
    }
  }

  double get _totalAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  List<String> get _includedIds =>
      _included.entries.where((e) => e.value).map((e) => e.key).toList();

  double get _totalPaid => SplitCalculator.sum(
        _paidCtrls.values.map((c) => double.tryParse(c.text.trim()) ?? 0),
      );

  Map<String, double> get _enteredShares {
    final map = <String, double>{};
    for (final id in _includedIds) {
      map[id] = double.tryParse(_shareCtrls[id]?.text.trim() ?? '') ?? 0;
    }
    return map;
  }

  Future<void> _save(GroupProvider groupProvider, ExpenseProvider expenseProvider) async {
    setState(() => _errorText = null);

    if (!_formKey.currentState!.validate()) return;

    final total = _totalAmount;
    final ids = _includedIds;

    final sizeErr = Validators.groupSize(ids.length);
    if (sizeErr != null) {
      setState(() => _errorText = sizeErr);
      return;
    }

    // Validate contributions: they must sum to the total amount (someone paid the whole bill).
    final paidSum = _totalPaid;
    if ((paidSum - total).abs() > 0.01) {
      setState(() => _errorText =
          'Contributions must add up to the total (₹${(total - paidSum).toStringAsFixed(2)} unaccounted for)');
      return;
    }

    Map<String, double> shares;
    switch (_splitType) {
      case SplitType.uniform:
        shares = SplitCalculator.uniform(ids, total);
        break;
      case SplitType.specific:
        final entered = _enteredShares;
        final err = Validators.specificSum(SplitCalculator.sum(entered.values), total);
        if (err != null) {
          setState(() => _errorText = err);
          return;
        }
        shares = entered;
        break;
      case SplitType.ratio:
        final entered = _enteredShares;
        final err = Validators.ratioSum(SplitCalculator.sum(entered.values));
        if (err != null) {
          setState(() => _errorText = err);
          return;
        }
        shares = SplitCalculator.ratio(entered, total);
        break;
    }

    final contributions = <String, double>{};
    for (final entry in _paidCtrls.entries) {
      final amt = double.tryParse(entry.value.text.trim()) ?? 0;
      if (amt > 0) contributions[entry.key] = amt;
    }

    await expenseProvider.addExpense(
      groupId: groupProvider.activeGroupId!,
      title: _titleCtrl.text,
      category: _category,
      totalAmount: total,
      splitType: _splitType,
      contributions: contributions,
      shares: shares,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final participants = groupProvider.activeParticipants;
    _ensureControllers(participants);

    return Scaffold(
      appBar: AppBar(title: const Text('Log an expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: Validators.title,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: categoryIcons.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total amount (₹)', border: OutlineInputBorder()),
              validator: Validators.amount,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            Text('Who paid? (multi-payer supported)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...participants.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.name)),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _paidCtrls[p.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(prefixText: '₹', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                )),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Paid so far: ₹${_totalPaid.toStringAsFixed(2)} / ₹${_totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: (_totalPaid - _totalAmount).abs() < 0.01 ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Split mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<SplitType>(
              segments: const [
                ButtonSegment(value: SplitType.uniform, label: Text('Equal')),
                ButtonSegment(value: SplitType.specific, label: Text('Custom')),
                ButtonSegment(value: SplitType.ratio, label: Text('Ratio')),
              ],
              selected: {_splitType},
              onSelectionChanged: (s) => setState(() => _splitType = s.first),
            ),
            const SizedBox(height: 12),

            Text('Split between', style: Theme.of(context).textTheme.titleMedium),
            ...participants.map((p) {
              final included = _included[p.id] ?? true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: included,
                      onChanged: (v) => setState(() => _included[p.id] = v ?? true),
                    ),
                    Expanded(child: Text(p.name)),
                    if (!included)
                      const SizedBox()
                    else if (_splitType == SplitType.uniform)
                      Text(
                        '₹${(SplitCalculator.uniform(_includedIds, _totalAmount)[p.id] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    else
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _shareCtrls[p.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: _splitType == SplitType.specific ? '₹' : '',
                            suffixText: _splitType == SplitType.ratio ? '%' : '',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                  ],
                ),
              );
            }),

            if (_splitType == SplitType.specific)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Unallocated: ₹${SplitCalculator.unallocated(_enteredShares, _totalAmount).toStringAsFixed(2)}',
                ),
              ),
            if (_splitType == SplitType.ratio)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${SplitCalculator.sum(_enteredShares.values).toStringAsFixed(1)}% / 100%',
                ),
              ),

            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _save(groupProvider, expenseProvider),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Save expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
