import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';

/// The four tabs around the signed-in app: Keşfet, Canlı, Yayın aç, Profil.
/// Each tab keeps its own navigation stack (go_router's indexed stack).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const tabs = [
    (label: 'Keşfet', icon: Icons.explore_outlined, active: Icons.explore),
    (label: 'Canlı', icon: Icons.sensors_outlined, active: Icons.sensors),
    (label: 'Yayın aç', icon: Icons.videocam_outlined, active: Icons.videocam),
    (label: 'Profil', icon: Icons.person_outline, active: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.stage,
          border: Border(
            top: BorderSide(color: AppColors.line, width: AppSize.line),
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
                      icon: index == shell.currentIndex ? tab.active : tab.icon,
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

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.onStageMuted;
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
            Icon(icon, color: color),
            const SizedBox(height: AppSpace.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall!.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
