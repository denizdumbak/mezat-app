import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import 'app_loader.dart';

/// A flat raised surface: the app's card. stageRaised, 16 dp corners, a
/// 1 dp line instead of a shadow. Never nested inside another panel.
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.l),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.stageRaised,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AppColors.line, width: AppSize.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoader(),
          if (message != null) ...[
            const SizedBox(height: AppSpace.m),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Nothing to show yet: what is missing and, if possible, what to do.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = this.message;
    final action = this.action;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.onStageMuted, size: AppSize.touch),
            const SizedBox(height: AppSpace.l),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpace.s),
              Text(
                message,
                style: text.bodyMedium!.copyWith(color: AppColors.onStageMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.xl),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Something failed: the reason and a retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.error_outline,
      title: 'Bir sorun oldu',
      message: message,
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('Tekrar dene'),
      ),
    );
  }
}

/// Shown on top of live content while the realtime connection is down.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  static const text = 'Bağlantı koptu. Yeniden bağlanıyor…';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.stageRaised,
          borderRadius: AppRadius.smallAll,
          border: Border.all(color: AppColors.urgent, width: AppSize.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.s,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: AppColors.urgent,
                size: AppSize.iconSmall,
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: AppColors.onStage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AppMessageTone { info, success, error }

/// The app's snackbar: flat, with an icon that says what kind of message it
/// is. Replaces any message already showing.
void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageTone tone = AppMessageTone.info,
}) {
  final (icon, color) = switch (tone) {
    AppMessageTone.info => (Icons.info_outline, AppColors.onStageMuted),
    AppMessageTone.success => (Icons.check_circle_outline, AppColors.success),
    AppMessageTone.error => (Icons.error_outline, AppColors.urgent),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: AppSize.icon),
            const SizedBox(width: AppSpace.m),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Pull down to reload. A non-scrollable [child] (an empty or error view) is
/// made scrollable and stretched to the screen so the gesture works there
/// too; pass [scrollable] for lists, which must then use
/// `AlwaysScrollableScrollPhysics` so short lists can be pulled.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.scrollable = false,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.stageRaised,
      // A failed reload shows its own error view; the gesture just ends.
      onRefresh: () async {
        try {
          await onRefresh();
        } catch (_) {}
      },
      child: scrollable
          ? child
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: child,
                ),
              ),
            ),
    );
  }
}
