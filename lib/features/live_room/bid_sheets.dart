import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../core/money.dart';
import '../../core/widgets/primary_button.dart';
import '../auctions/auction_validators.dart';

/// The second step for a high bid (PRODUCT.md, "Yüksek tutar onayı").
/// Resolves to true only when the user confirms.
Future<bool> confirmHighBid(
  BuildContext context, {
  required Money amount,
  required Money committedAfter,
  bool isMaxBid = false,
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
                isMaxBid
                    ? '${amount.format()} tutarına kadar senin adına teklif '
                          'verilecek.'
                    : '${amount.format()} teklif vermek üzeresin.',
                style: text.bodyLarge,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Kazanırsan bugünkü toplamın ${committedAfter.format()} olur.',
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

/// Asks for a maximum (proxy) bid. [validate] adds the room's own rules
/// (at least the next valid bid, within the daily limit).
Future<Money?> askMaxBid(
  BuildContext context, {
  required Money minimum,
  required Money step,
  Money? current,
  required String? Function(Money amount) validate,
}) => showModalBottomSheet<Money>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _MaxBidSheet(
    minimum: minimum,
    step: step,
    current: current,
    validate: validate,
  ),
);

class _MaxBidSheet extends StatefulWidget {
  const _MaxBidSheet({
    required this.minimum,
    required this.step,
    required this.current,
    required this.validate,
  });

  final Money minimum;
  final Money step;
  final Money? current;
  final String? Function(Money amount) validate;

  @override
  State<_MaxBidSheet> createState() => _MaxBidSheetState();
}

class _MaxBidSheetState extends State<_MaxBidSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.current == null
        ? ''
        : (widget.current!.kurus ~/ 100).toString(),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validator(String? raw) {
    final format = validateAmount(raw);
    if (format != null) return format;
    final amount = Money.tryParse(raw!)!;
    if (amount.kurus < widget.minimum.kurus) {
      return 'En az ${widget.minimum.format()} olmalı.';
    }
    return widget.validate(amount);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(Money.tryParse(_amount.text));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.edge,
          0,
          AppSpace.edge,
          AppSpace.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Maksimum teklif', style: text.titleLarge),
              const SizedBox(height: AppSpace.s),
              Text(
                'Teklifin geçildikçe ${widget.step.format()} artışla senin '
                'adına teklif verilir; bu tutarı aşmaz.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpace.l),
              TextFormField(
                key: const Key('maxBid.amount'),
                controller: _amount,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'En fazla',
                  prefixText: '₺ ',
                  helperText: 'En az ${widget.minimum.format()}',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validator,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(label: 'Maksimum teklifi kaydet', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
