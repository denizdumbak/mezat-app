import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../money.dart';

/// One of the seller's bid increments ("+₺50"). Selected: gold fill.
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
    final foreground = selected
        ? AppColors.onGold
        : enabled
        ? AppColors.onStage
        : AppColors.onStageMuted;
    return Semantics(
      selected: selected,
      button: true,
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
          color: selected ? AppColors.gold : AppColors.stageRaised,
          borderRadius: AppRadius.smallAll,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.line,
            width: AppSize.line,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.smallAll,
            onTap: onSelected,
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                child: Text(
                  '+${increment.format()}',
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: foreground,
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
