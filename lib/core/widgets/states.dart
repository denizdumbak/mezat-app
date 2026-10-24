import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import 'app_loader.dart';

/// The app's panel: the secondary surface with 16 dp corners and no frame.
/// In the live room it is the see-through scrim with a blur behind, so it
/// reads over the video. Never nested inside another panel.
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
    return BlurredPanel(
      borderRadius: AppRadius.cardAll,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// [AppPalette.panel] behind [child], blurring what is underneath when the
/// panel is see-through (the live room).
class BlurredPanel extends StatelessWidget {
  const BlurredPanel({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: borderRadius,
      ),
      child: child,
    );
    if (!palette.panelBlurred) return panel;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSize.panelBlur,
          sigmaY: AppSize.panelBlur,
        ),
        child: panel,
      ),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final message = this.message;
    final action = this.action;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: muted, size: AppSize.touch),
            const SizedBox(height: AppSpace.l),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpace.s),
              Text(
                message,
                style: text.bodyMedium!.copyWith(color: muted),
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

/// Shown on top of live content while the realtime connection is down. A
/// waiting state, so the warning colour, not the error colour.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  static const text = 'Bağlantı koptu. Yeniden bağlanıyor…';

  @override
  Widget build(BuildContext context) {
    final warning = context.palette.warning;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.panel,
          borderRadius: AppRadius.imageAll,
          border: Border.all(color: warning, width: AppSize.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.s,
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: warning, size: AppSize.iconSmall),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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
  // The snackbar is the inverse surface, so icons use colours that read on
  // it.
  final scheme = Theme.of(context).colorScheme;
  final (icon, color) = switch (tone) {
    AppMessageTone.info => (Icons.info_outline, scheme.onInverseSurface),
    AppMessageTone.success => (
      Icons.check_circle_outline,
      context.palette.success,
    ),
    AppMessageTone.error => (
      Icons.error_outline,
      context.palette.errorOnInverse,
    ),
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
      color: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
