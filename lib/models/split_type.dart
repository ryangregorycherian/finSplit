enum SplitType { uniform, specific, ratio }

extension SplitTypeLabel on SplitType {
  String get label {
    switch (this) {
      case SplitType.uniform:
        return 'Equal Split';
      case SplitType.specific:
        return 'Custom Amounts';
      case SplitType.ratio:
        return 'Ratio / Percentage';
    }
  }
}
