import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../money.dart';

/// One of the seller's bid increments ("+₺50"), as a pill. Selected: a
/// heavier outline in the text colour. Never the accent, which belongs to the
/// bid button right below, the screen's one primary action.
class IncrementChip extends StatelessWidget {
  const IncrementChip({
    super.key,
    required this.increment,
    required this.selected,
    required this.onSelected,
  });

  final Money increment;
  final bool selected;

  /// Null disables the chip.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = onSelected != null;
    final highlighted = selected && enabled;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      label: '${increment.format()} artış',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.press,
        curve: AppCurves.enter,
        constraints: const BoxConstraints(
          minHeight: AppSize.touch,
          minWidth: AppSize.touch,
        ),
        decoration: BoxDecoration(
          color: context.palette.panel,
          borderRadius: AppRadius.pillAll,
          border: Border.all(
            color: highlighted ? scheme.onSurface : scheme.outlineVariant,
            width: highlighted ? AppSize.selectedLine : AppSize.line,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.pillAll,
            onTap: onSelected,
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                child: Text(
                  '+${increment.format()}',
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: enabled
                        ? scheme.onSurface
                        : context.palette.disabled,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
