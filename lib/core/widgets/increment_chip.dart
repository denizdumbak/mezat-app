import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../money.dart';

/// One of the seller's bid increments ("+₺50"). Selected: gold outline and
/// text on a darker ground. Not a gold fill, which belongs to the bid button
/// right below, the screen's one primary action.
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
          color: highlighted ? AppColors.stage : AppColors.stageRaised,
          borderRadius: AppRadius.smallAll,
          border: Border.all(
            color: highlighted ? AppColors.gold : AppColors.line,
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
                    color: highlighted
                        ? AppColors.gold
                        : enabled
                        ? AppColors.onStage
                        : AppColors.onStageMuted,
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
