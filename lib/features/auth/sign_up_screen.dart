import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/widgets/form_layout.dart';
import 'auth_controller.dart';
import 'validators.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider(AuthForm.signUp).notifier)
        .signUp(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthForm.signUp));
    final busy = state.isLoading;

    return FormLayout(
      title: 'Kayıt ol',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('signUp.email'),
                  controller: _email,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('signUp.password'),
                  controller: _password,
                  enabled: !busy,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    helperText: 'En az $minPasswordLength karakter',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Şifreyi göster'
                          : 'Şifreyi gizle',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 16),
                // A typo in a password nobody can see is a common cause of
                // "I cannot log in" right after signing up.
                TextFormField(
                  key: const Key('signUp.passwordAgain'),
                  controller: _passwordAgain,
                  enabled: !busy,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Şifre (tekrar)',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) =>
                      value == _password.text ? null : 'Şifreler eşleşmiyor.',
                ),
              ],
            ),
          ),
        ),
        FailureMessage(state: state),
        const SizedBox(height: 24),
        SubmitButton(label: 'Kayıt ol', busy: busy, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : () => context.go(AppRoutes.signIn),
          child: const Text('Zaten hesabın var mı? Giriş yap'),
        ),
      ],
    );
  }
}
