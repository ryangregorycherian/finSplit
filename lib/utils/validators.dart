class Validators {
  /// Rejects empty, non-numeric, zero, or negative amounts.
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount cannot be empty';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  static String? title(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title cannot be empty';
    }
    if (value.trim().length > 60) {
      return 'Title is too long';
    }
    return null;
  }

  /// A valid group needs at least 2 participants to make splitting meaningful.
  static String? groupSize(int count) {
    if (count < 2) {
      return 'A group needs at least 2 participants';
    }
    if (count > 30) {
      return 'That is too many participants for one group';
    }
    return null;
  }

  static String? participantName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    return null;
  }

  /// Ratio-based split must add up to exactly 100 (within a small float tolerance).
  static String? ratioSum(double sum) {
    if ((sum - 100).abs() > 0.01) {
      return 'Percentages must add up to 100% (currently ${sum.toStringAsFixed(1)}%)';
    }
    return null;
  }

  /// Specific-value split must exactly account for the full expense amount.
  static String? specificSum(double sum, double total) {
    if ((sum - total).abs() > 0.01) {
      final diff = (total - sum);
      if (diff > 0) {
        return '₹${diff.toStringAsFixed(2)} still unallocated';
      }
      return 'Allocated ₹${(-diff).toStringAsFixed(2)} more than the total';
    }
    return null;
  }
}
