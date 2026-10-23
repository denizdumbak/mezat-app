import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';

/// Title at the top of a tab, with an optional widget on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.edge,
        AppSpace.l,
        AppSpace.edge,
        AppSpace.m,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.m),
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small heading above a section of a list.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.edge,
        AppSpace.l,
        AppSpace.edge,
        AppSpace.m,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: AppSpace.s)],
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
