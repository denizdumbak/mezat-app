import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../core/app_failure.dart';
import '../../core/money.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/states.dart';
import '../auctions/auction_validators.dart';
import '../auctions/feed_providers.dart';
import '../auctions/widgets/auction_visuals.dart';
import '../auctions/widgets/screen_header.dart';
import '../auth/auth_controller.dart';
import '../auth/session.dart';
import '../live_room/bid_safety.dart';

/// Profil: who you are, your daily spending limit, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(currentProfileProvider).value?.username ?? '';
    final limit = ref.watch(dailyLimitProvider).value;
    final committed = ref.watch(committedTodayProvider).value ?? Money.zero;
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
                  Text('Günlük harcama limiti', style: text.bodySmall),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    limit?.format() ?? '—',
                    key: const Key('profile.dailyLimit'),
                    style: AppTextStyles.price,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Bugün: ${committed.format()}',
                    style: text.bodySmall!.copyWith(
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    'Limiti aşacak teklif verilemez. Yüksek tutarlı '
                    'tekliflerde ayrıca onay istenir.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.l),
                  OutlinedButton(
                    onPressed: limit == null
                        ? null
                        : () => _changeLimit(context, ref, limit),
                    child: const Text('Limiti değiştir'),
                  ),
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
    Money current,
  ) async {
    final limit = await showModalBottomSheet<Money>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LimitSheet(current: current),
    );
    if (limit == null) return;
    try {
      await ref.read(dailyLimitProvider.notifier).change(limit);
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
      showAppMessage(
        context,
        'Günlük limitin ${limit.format()} oldu.',
        tone: AppMessageTone.success,
      );
    }
  }
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({required this.current});

  final Money current;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (widget.current.kurus ~/ 100).toString(),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
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
              Text('Günlük harcama limiti', style: text.titleLarge),
              const SizedBox(height: AppSpace.s),
              Text(
                'Bir günde önde olduğun ve kazandığın tekliflerin toplamı bu '
                'tutarı geçemez.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpace.l),
              TextFormField(
                key: const Key('profile.limitField'),
                controller: _amount,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Limit',
                  prefixText: '₺ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: validateAmount,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(label: 'Kaydet', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
