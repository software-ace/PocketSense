import 'package:flutter/material.dart';

import '../utils/format.dart';

/// Text field for a JOD amount, labelled the same way [formatMoney] prints
/// one. Read it back with [parseAmount].
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, required this.label, this.autofocus = false, this.onSubmitted});

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final affix = currencyAffix();
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: affix.prefix, suffixText: affix.suffix),
    );
  }
}
