import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../core/money.dart';
import '../../core/widgets/primary_button.dart';

/// The second step for a high bid (PRODUCT.md, "Yüksek tutar onayı").
/// Resolves to true only when the user confirms.
Future<bool> confirmHighBid(
  BuildContext context, {
  required Money amount,
  required Money committedAfter,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    // Grows to its content (and scrolls on short screens or with large
    // text) instead of the default 9/16 cap.
    isScrollControlled: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.edge,
            0,
            AppSpace.edge,
            AppSpace.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Yüksek tutarlı teklif', style: text.titleLarge),
              const SizedBox(height: AppSpace.m),
              Text(
                '${amount.format()} teklif vermek üzeresin.',
                style: text.bodyLarge,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Kazanırsan limitine sayılan toplam '
                '${committedAfter.format()} olur.',
                style: text.bodySmall!.copyWith(fontFeatures: AppFonts.tabular),
              ),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                label: 'Onaylıyorum',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpace.s),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
