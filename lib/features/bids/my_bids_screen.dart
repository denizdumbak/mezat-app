import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/states.dart';
import '../auctions/widgets/screen_header.dart';

/// Tekliflerim: the auctions the user has bid on and how each stands (Önde,
/// Geçildin, Kazandın, Kaybettin).
///
/// No repository reads a user's bids yet, so for now this is the empty
/// state, pointing at the live auctions. The list comes with the bid feed
/// work in M3 step 7 (NOTES.md).
class MyBidsScreen extends StatelessWidget {
  const MyBidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ScreenHeader(title: 'Tekliflerim'),
          Expanded(
            child: EmptyView(
              icon: Icons.gavel,
              title: 'Henüz teklif vermedin',
              message:
                  'Canlı mezatlarda verdiğin teklifler burada görünür; önde '
                  'misin, geçildin mi buradan takip edersin.',
              action: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.contentMaxWidth,
                ),
                child: PrimaryButton(
                  label: 'Canlı mezatlara göz at',
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
