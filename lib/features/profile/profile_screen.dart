import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../core/app_failure.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../core/widgets/price_label.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/states.dart';
import '../../data/spending_limit_repository.dart';
import '../auctions/auction_validators.dart';
import '../auctions/feed_providers.dart';
import '../auctions/widgets/auction_visuals.dart';
import '../auctions/widgets/screen_header.dart';
import '../auth/auth_controller.dart';
import '../auth/session.dart';
import '../live_room/bid_safety.dart';

/// Profil: who you are, your spending limit, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(currentProfileProvider).value?.username ?? '';
    final limit = ref.watch(spendingLimitProvider).value;
    final committed = ref.watch(committedProvider).value ?? Money.zero;
    final signOut = ref.watch(authControllerProvider(AuthForm.signOut));
    final text = Theme.of(context).textTheme;

    ref.listen(authControllerProvider(AuthForm.signOut), (_, next) {
      final error = next.error;
      if (error != null && !next.isLoading) {
        showAppMessage(
          context,
          failureMessage(error),
          tone: AppMessageTone.error,
        );
      }
    });

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xl),
        children: [
          const ScreenHeader(title: 'Profil'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
            child: Row(
              children: [
                InitialAvatar(username: username, size: AppSize.avatarLarge),
                const SizedBox(width: AppSpace.l),
                Expanded(
                  child: Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Usernames are always set in the body face.
                    style: text.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('Güvenlik'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
            child: AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Harcama limiti', style: text.bodySmall),
                  const SizedBox(height: AppSpace.xs),
                  switch (limit) {
                    SpendingLimit(enabled: true, :final amount) => PriceLabel(
                      amount,
                      key: const Key('profile.limit'),
                    ),
                    _ => Text(
                      limit == null ? 'Yükleniyor' : 'Kapalı',
                      key: const Key('profile.limit'),
                      style: AppTextStyles.price,
                    ),
                  },
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    limit == null || limit.enabled
                        ? 'Son ${formatPeriodIn((limit ?? SpendingLimit.defaults).period)}'
                              ' · şu an ${committed.format()}'
                        : 'Teklifler sınırlanmıyor.',
                    key: const Key('profile.limitWindow'),
                    style: text.bodySmall!.copyWith(
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    'Önde olduğun ve bu sürede kazandığın mezatların toplamı '
                    'limiti geçemez. Yüksek tutarlı tekliflerde ayrıca onay '
                    'istenir.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.l),
                  OutlinedButton(
                    onPressed: limit == null
                        ? null
                        : () => _changeLimit(context, ref, limit),
                    child: const Text('Limiti değiştir'),
                  ),
                  if (limit != null && limit.enabled) ...[
                    const SizedBox(height: AppSpace.s),
                    TextButton(
                      onPressed: () => _resetWindow(context, ref),
                      child: const Text('Sayacı sıfırla'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış yap'),
            enabled: !signOut.isLoading,
            onTap: () => ref
                .read(authControllerProvider(AuthForm.signOut).notifier)
                .signOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLimit(
    BuildContext context,
    WidgetRef ref,
    SpendingLimit current,
  ) async {
    final limit = await showModalBottomSheet<SpendingLimit>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LimitSheet(current: current),
    );
    if (limit == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(spendingLimitProvider.notifier).change(limit),
      success: limit.enabled
          ? 'Limitin son ${formatPeriodIn(limit.period)} en fazla '
                '${limit.amount.format()} oldu.'
          : 'Harcama limitin kapandı.',
    );
  }

  Future<void> _resetWindow(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ResetSheet(),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      () => ref.read(spendingLimitProvider.notifier).resetWindow(),
      success: 'Sayaç sıfırlandı.',
    );
  }

  /// Runs [action] and tells the user how it went.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        showAppMessage(
          context,
          failureMessage(error),
          tone: AppMessageTone.error,
        );
      }
      return;
    }
    if (context.mounted) {
      showAppMessage(context, success, tone: AppMessageTone.success);
    }
  }
}

/// The units offered for a custom period.
enum _PeriodUnit {
  hours('saat', Duration(hours: 1)),
  days('gün', Duration(days: 1)),
  weeks('hafta', Duration(days: 7));

  const _PeriodUnit(this.label, this.length);

  final String label;
  final Duration length;
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({required this.current});

  final SpendingLimit current;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  /// Selected segment: an index into [SpendingLimit.presetPeriods], or
  /// [_custom].
  static const _custom = -1;

  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (widget.current.amount.kurus ~/ 100).toString(),
  );
  late bool _enabled = widget.current.enabled;
  late int _segment = SpendingLimit.presetPeriods.indexOf(
    widget.current.period,
  );
  late final _PeriodUnit _initialUnit = _unitFor(widget.current.period);
  late _PeriodUnit _unit = _initialUnit;
  late final _customCount = TextEditingController(
    text: _segment == _custom
        ? (widget.current.period.inHours ~/ _initialUnit.length.inHours)
              .toString()
        : '',
  );

  static _PeriodUnit _unitFor(Duration period) => switch (period.inHours) {
    final hours when hours % (24 * 7) == 0 => _PeriodUnit.weeks,
    final hours when hours % 24 == 0 => _PeriodUnit.days,
    _ => _PeriodUnit.hours,
  };

  @override
  void dispose() {
    _amount.dispose();
    _customCount.dispose();
    super.dispose();
  }

  String? _validateCustom(String? raw) {
    final count = int.tryParse(raw?.trim() ?? '');
    if (count == null || count < 1) return 'Bir sayı gir.';
    final period = _unit.length * count;
    if (period < SpendingLimit.minPeriod || period > SpendingLimit.maxPeriod) {
      return 'En az 1 saat, en fazla 365 gün.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final period = _segment == _custom
        ? _unit.length * int.parse(_customCount.text.trim())
        : SpendingLimit.presetPeriods[_segment];
    Navigator.of(context).pop(
      widget.current.copyWith(
        enabled: _enabled,
        amount: _enabled ? Money.tryParse(_amount.text) : null,
        period: _enabled ? period : null,
      ),
    );
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
              Text('Harcama limiti', style: text.titleLarge),
              const SizedBox(height: AppSpace.s),
              Text(
                'Önde olduğun ve seçtiğin sürede kazandığın mezatların toplamı '
                'bu tutarı geçemez. İstediğin zaman değiştirebilir ya da '
                'kapatabilirsin.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpace.m),
              Row(
                children: [
                  Expanded(child: Text('Limit açık', style: text.bodyLarge)),
                  Switch(
                    key: const Key('profile.limitEnabled'),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              TextFormField(
                key: const Key('profile.limitField'),
                controller: _amount,
                enabled: _enabled,
                decoration: const InputDecoration(
                  labelText: 'En fazla',
                  prefixText: '₺ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _enabled ? validateAmount : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpace.l),
              Text('Süre', style: text.titleSmall),
              const SizedBox(height: AppSpace.s),
              SegmentedButton<int>(
                key: const Key('profile.limitPeriod'),
                showSelectedIcon: false,
                segments: [
                  for (final (i, period) in SpendingLimit.presetPeriods.indexed)
                    ButtonSegment(value: i, label: Text(formatPeriod(period))),
                  const ButtonSegment(value: _custom, label: Text('Özel')),
                ],
                selected: {_segment},
                onSelectionChanged: _enabled
                    ? (selection) => setState(() => _segment = selection.single)
                    : null,
              ),
              if (_segment == _custom) ...[
                const SizedBox(height: AppSpace.m),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('profile.customPeriodCount'),
                        controller: _customCount,
                        enabled: _enabled,
                        decoration: const InputDecoration(labelText: 'Son'),
                        keyboardType: TextInputType.number,
                        validator: _enabled ? _validateCustom : null,
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: DropdownButtonFormField<_PeriodUnit>(
                        key: const Key('profile.customPeriodUnit'),
                        initialValue: _unit,
                        isExpanded: true,
                        style: text.bodyLarge,
                        decoration: const InputDecoration(labelText: 'Birim'),
                        items: [
                          for (final unit in _PeriodUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: _enabled
                            ? (unit) => setState(() => _unit = unit!)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(label: 'Kaydet', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms a reset; resolves to true only when the user confirms.
class _ResetSheet extends StatelessWidget {
  const _ResetSheet();

  @override
  Widget build(BuildContext context) {
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
            Text('Sayacı sıfırla', style: text.titleLarge),
            const SizedBox(height: AppSpace.m),
            Text(
              'Şimdiye kadar kazandığın mezatlar limitine sayılmaz, sayaç '
              'şimdiden başlar. Önde olduğun mezatlar sayılmaya devam eder.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: 'Sıfırla',
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
  }
}
