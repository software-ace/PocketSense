import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/format.dart';

/// Required text field for a JOD amount, labelled the same way [formatMoney]
/// prints one. Read it back with [parseAmount]. Inside a [Form], it reports
/// an empty or non-positive amount when the form is validated.
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, required this.label, this.autofocus = false, this.onSubmitted});

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final affix = currencyAffix();
    final l = context.l10n;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      onFieldSubmitted: onSubmitted,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: affix.prefix, suffixText: affix.suffix, errorMaxLines: 2),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return l.enterAmount;
        return (parseAmount(v) ?? 0) > 0 ? null : l.enterPositiveAmount;
      },
    );
  }
}
