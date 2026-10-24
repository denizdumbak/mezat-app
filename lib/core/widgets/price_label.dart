import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../money.dart';

/// An amount in a list, card or row: "₺1.250,50" with Turkish separators and
/// the lira sign a little smaller than the digits, so the number leads.
/// Tabular w800 ([AppTextStyles.price]) unless [style] says otherwise; the
/// colour comes from the surrounding text style.
class PriceLabel extends StatelessWidget {
  const PriceLabel(
    this.amount, {
    super.key,
    this.style = AppTextStyles.price,
    this.prefix,
  });

  final Money amount;
  final TextStyle style;

  /// Text before the amount in the caption style, e.g. "Açılış".
  final String? prefix;

  /// The lira sign's size relative to the digits.
  static const signScale = 0.8;

  @override
  Widget build(BuildContext context) {
    final formatted = amount.format();
    final digits = formatted.substring(1);
    final prefix = this.prefix;
    return Semantics(
      label: prefix == null ? formatted : '$prefix $formatted',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            if (prefix != null)
              TextSpan(
                text: '$prefix ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            TextSpan(
              text: formatted.substring(0, 1),
              style: style.copyWith(fontSize: style.fontSize! * signScale),
            ),
            TextSpan(text: digits, style: style),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
