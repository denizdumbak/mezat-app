import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_failure.dart';
import '../../core/money.dart';
import '../../core/photo_picker.dart';
import '../../core/widgets/form_layout.dart';
import '../../data/auction_repository.dart';
import 'auction_validators.dart';
import 'create_auction_controller.dart';

class CreateAuctionScreen extends ConsumerStatefulWidget {
  const CreateAuctionScreen({super.key});

  @override
  ConsumerState<CreateAuctionScreen> createState() =>
      _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends ConsumerState<CreateAuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _startPrice = TextEditingController();
  final _minIncrement = TextEditingController();

  PickedPhoto? _photo;
  int _durationMinutes = defaultDurationMinutes;
  bool _startNow = true;
  DateTime? _scheduledAt;
  String? _startError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _startPrice.dispose();
    _minIncrement.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await ref.read(photoPickerProvider).pick();
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AppFailure
                ? error.message
                : 'Fotoğraf seçilemedi. Tekrar dene.',
          ),
        ),
      );
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(maxScheduleAhead),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _startError = null;
    });
  }

  Future<void> _submit() async {
    final now = DateTime.now();
    setState(() {
      _startError = _startNow
          ? null
          : validateScheduledStart(_scheduledAt, now: now);
    });
    final fieldsValid = _formKey.currentState!.validate();
    if (!fieldsValid || _startError != null) return;
    FocusScope.of(context).unfocus();

    await ref
        .read(createAuctionControllerProvider.notifier)
        .submit(
          NewAuction(
            title: _title.text.trim(),
            description: _description.text.trim(),
            // Validated above, so parsing cannot fail here.
            startPrice: Money.tryParse(_startPrice.text)!,
            minIncrement: Money.tryParse(_minIncrement.text)!,
            durationMinutes: _durationMinutes,
            startsAt: _startNow ? now : _scheduledAt!,
          ),
          photo: _photo,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createAuctionControllerProvider);
    final busy = state.isLoading;

    ref.listen(createAuctionControllerProvider, (_, next) {
      if (next case AsyncData(value: _?)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mezat oluşturuldu.')));
        context.pop();
      }
    });

    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return FormLayout(
      title: 'Mezat oluştur',
      children: [
        _PhotoField(
          photo: _photo,
          enabled: !busy,
          onPick: _pickPhoto,
          onRemove: () => setState(() => _photo = null),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('createAuction.title'),
                controller: _title,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Başlık'),
                maxLength: maxTitleLength,
                textInputAction: TextInputAction.next,
                validator: validateTitle,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('createAuction.description'),
                controller: _description,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (isteğe bağlı)',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                maxLength: maxDescriptionLength,
                validator: validateDescription,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AmountField(
                      fieldKey: const Key('createAuction.startPrice'),
                      controller: _startPrice,
                      label: 'Başlangıç fiyatı',
                      enabled: !busy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AmountField(
                      fieldKey: const Key('createAuction.minIncrement'),
                      controller: _minIncrement,
                      label: 'Minimum artış',
                      enabled: !busy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('createAuction.duration'),
                initialValue: _durationMinutes,
                decoration: const InputDecoration(labelText: 'Süre'),
                items: [
                  for (final minutes in durationOptions)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(durationLabel(minutes)),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => _durationMinutes = value!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Başlangıç', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          key: const Key('createAuction.startMode'),
          segments: const [
            ButtonSegment(value: true, label: Text('Hemen')),
            ButtonSegment(value: false, label: Text('İleri tarih')),
          ],
          selected: {_startNow},
          onSelectionChanged: busy
              ? null
              : (selection) => setState(() {
                  _startNow = selection.single;
                  _startError = null;
                }),
        ),
        if (!_startNow) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('createAuction.startAt'),
            icon: const Icon(Icons.event),
            label: Text(
              _scheduledAt == null
                  ? 'Tarih ve saat seç'
                  : formatDateTime(_scheduledAt!),
            ),
            onPressed: busy ? null : _pickStart,
          ),
        ],
        if (_startError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_startError!, style: TextStyle(color: colors.error)),
          ),
        const SizedBox(height: 8),
        Text(
          'Mezat, sen yayını başlattığında açılır ve seçtiğin süre boyunca '
          'sürer. Planlanan zaman izleyicilere gösterilir.',
          style: textTheme.bodySmall,
        ),
        FailureMessage(state: state),
        const SizedBox(height: 24),
        SubmitButton(label: 'Mezatı oluştur', busy: busy, onPressed: _submit),
      ],
    );
  }
}

/// "30 dakika", "1 saat", "1 saat 30 dakika".
String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes dakika';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours saat' : '$hours saat $rest dakika';
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, suffixText: '₺'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: validateAmount,
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.photo,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final PickedPhoto? photo;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = this.photo;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('createAuction.photo'),
          onTap: enabled ? onPick : null,
          child: photo == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: colors.primary),
                    const SizedBox(height: 8),
                    const Text('Fotoğraf ekle (isteğe bağlı)'),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(photo.bytes, fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton.filledTonal(
                        tooltip: 'Fotoğrafı kaldır',
                        icon: const Icon(Icons.close),
                        onPressed: enabled ? onRemove : null,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
