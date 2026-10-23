import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/form_layout.dart';
import 'auth_controller.dart';
import 'validators.dart';

class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() =>
      _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider(AuthForm.chooseUsername).notifier)
        .chooseUsername(_username.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthForm.chooseUsername));
    final signOutState = ref.watch(authControllerProvider(AuthForm.signOut));
    final busy = state.isLoading || signOutState.isLoading;

    return FormLayout(
      title: 'Kullanıcı adı seç',
      children: [
        const Text(
          'Mezatlarda teklif verirken diğer kullanıcılar seni bu adla görecek.',
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: TextFormField(
            key: const Key('chooseUsername.username'),
            controller: _username,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı adı',
              prefixText: '@',
              helperText: '3–20 karakter: küçük harf, rakam ve _',
            ),
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: validateUsername,
          ),
        ),
        FailureMessage(state: state),
        FailureMessage(state: signOutState),
        const SizedBox(height: 24),
        SubmitButton(label: 'Devam et', busy: busy, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () => ref
                    .read(authControllerProvider(AuthForm.signOut).notifier)
                    .signOut(),
          child: const Text('Çıkış yap'),
        ),
      ],
    );
  }
}
