import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../utils/format.dart';

/// Required text field for a JOD amount, labelled the same way [formatMoney]
/// prints one. Read it back with [parseAmount]. Inside a [Form], it reports
/// an empty or non-positive amount when the form is validated, and then
/// what [check] says about the amount in fils (an error, or null if fine).
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, required this.label, this.autofocus = false, this.onSubmitted, this.helperText, this.check});

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final String? helperText;
  final String? Function(int fils)? check;

  @override
  Widget build(BuildContext context) {
    final affix = currencyAffix();
    final l = context.l10n;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      onFieldSubmitted: onSubmitted,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Only what parseAmount reads: Latin, Arabic-Indic and Persian digits,
      // and the Latin and Arabic decimal and thousands separators.
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹.,٫٬]'))],
      decoration: InputDecoration(
          labelText: label, prefixText: affix.prefix, suffixText: affix.suffix, helperText: helperText, errorMaxLines: 2),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return l.enterAmount;
        final fils = parseAmount(v) ?? 0;
        if (fils <= 0) return l.enterPositiveAmount(appCurrency.decimals);
        return check?.call(fils);
      },
    );
  }
}
