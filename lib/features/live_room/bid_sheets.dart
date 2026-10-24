import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../core/amount_suffix.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/spending_limit_repository.dart';

/// The second step for a high bid (PRODUCT.md, "Yüksek tutar onayı").
/// Resolves to true only when the user confirms.
Future<bool> confirmHighBid(
  BuildContext context, {
  required Money amount,
  required Money committedAfter,
}) => _ask(
  context,
  title: 'Yüksek tutarlı teklif',
  message: '${amount.format()} teklif vermek üzeresin.',
  detail: 'Kazanırsan limitine sayılan toplam ${committedAfter.format()} olur.',
  yes: 'Onaylıyorum',
  no: 'Vazgeç',
);

/// A bid past the spending limit. Resolves to true when the user wants to
/// raise the limit, false for "Kapat". Closing is the filled button: the
/// safe choice is the easy one.
Future<bool> offerLimitRaise(
  BuildContext context, {
  required SpendingLimit limit,
  required Money overage,
}) async {
  final raise = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetBody(
      title: 'Limit aşıldı',
      message: 'Bu teklif harcama limitini ${overage.format()} aşıyor.',
      detail:
          'Son ${formatPeriodIn(limit.period)} en fazla '
          '${limit.amount.format()} teklif verebilirsin.',
      actions: [
        PrimaryButton(
          label: 'Kapat',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: AppSpace.s),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Limiti artır'),
        ),
      ],
    ),
  );
  return raise ?? false;
}

/// The last step before raising the limit and bidding at once. Resolves to
/// true only for "Evet".
Future<bool> confirmLimitRaise(
  BuildContext context, {
  required Money from,
  required Money to,
  required Money amount,
}) => _ask(
  context,
  title: 'Limiti artır',
  message:
      'Limitin ${withAblative(from)} ${withDative(to)} çıkacak ve '
      '${amount.format()} pey verilecek. Emin misin?',
  yes: 'Evet',
  no: 'Hayır',
);

Future<bool> _ask(
  BuildContext context, {
  required String title,
  required String message,
  String? detail,
  required String yes,
  required String no,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    // Grows to its content (and scrolls on short screens or with large
    // text) instead of the default 9/16 cap.
    isScrollControlled: true,
    builder: (context) => _SheetBody(
      title: title,
      message: message,
      detail: detail,
      actions: [
        PrimaryButton(
          label: yes,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpace.s),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(no),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.message,
    this.detail,
    required this.actions,
  });

  final String title;
  final String message;
  final String? detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
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
            Text(title, style: text.titleLarge),
            const SizedBox(height: AppSpace.m),
            Text(message, style: text.bodyLarge),
            if (detail != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                detail,
                style: text.bodySmall!.copyWith(fontFeatures: AppFonts.tabular),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            ...actions,
          ],
        ),
      ),
    );
  }
}
