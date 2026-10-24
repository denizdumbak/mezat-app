import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';

/// The four tabs around the signed-in app: Keşfet, Sat, Tekliflerim, Profil.
/// Each tab keeps its own navigation stack (go_router's indexed stack).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const tabs = [
    (label: 'Keşfet', icon: Icons.explore_outlined, active: Icons.explore),
    (label: 'Sat', icon: Icons.sell_outlined, active: Icons.sell),
    (label: 'Tekliflerim', icon: Icons.gavel, active: Icons.gavel),
    (label: 'Profil', icon: Icons.person_outline, active: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      // Its own layer: scrolling a tab does not repaint the bar.
      bottomNavigationBar: RepaintBoundary(
        key: const Key('appShell.tabBar'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant,
                width: AppSize.line,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppSize.tabBar,
              child: Row(
                children: [
                  for (final (index, tab) in tabs.indexed)
                    Expanded(
                      child: _TabItem(
                        key: Key('tab.$index'),
                        label: tab.label,
                        icon: index == shell.currentIndex
                            ? tab.active
                            : tab.icon,
                        selected: index == shell.currentIndex,
                        // Tapping the open tab again returns to its first page.
                        onTap: () => shell.goBranch(
                          index,
                          initialLocation: index == shell.currentIndex,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// The selected tab is one of the three places the accent appears: as a
  /// pill behind the icon, with the icon and label in the text colour so
  /// they stay legible on white.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.press,
              curve: AppCurves.enter,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.l,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? scheme.primary : null,
                borderRadius: AppRadius.pillAll,
              ),
              child: Icon(icon, color: selected ? scheme.onPrimary : color),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
