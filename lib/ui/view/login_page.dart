import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_error.dart';
import '../view_model/auth_view_model.dart';
import '../view_model/login_view_model.dart';

/// Login and sign-up with e-mail/password (Firebase Auth).
///
/// Google sign-in (AP-25) lives here. The screen only talks to its ViewModel: the
/// ephemeral part of the form (controllers, focus, validation) stays here, as
/// `constitution.md` §1 requires.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isSigningUp = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final LoginViewModel vm = context.read<LoginViewModel>();
    final AuthViewModel auth = context.read<AuthViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isSigningUp) {
      await vm.signUp(_email.text, _password.text);
    } else {
      await vm.signIn(_email.text, _password.text);
    }

    if (!mounted) return;

    // An expired session is old news once she is trying again.
    auth.clearNotice();

    // "Esse e-mail já tem conta. Tente entrar." is an instruction: the button
    // under that sentence has to be the one it tells her to press.
    if (vm.typedError is EmailJaEmUsoError) {
      setState(() => _isSigningUp = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final LoginViewModel vm = context.read<LoginViewModel>();
    final AuthViewModel auth = context.read<AuthViewModel>();

    await vm.signInWithGoogle();
    if (!mounted) return;

    // "Esse e-mail já tem conta com senha. Entre com a sua senha." is an
    // instruction: the screen has to be showing the form it tells her to use.
    if (vm.typedError is ContaDeOutroMetodoError) {
      setState(() => _isSigningUp = false);
    }

    // An expired session is old news once she is trying again.
    auth.clearNotice();
  }

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) return 'Informe o e-mail';
    if (!email.contains('@') || !email.contains('.')) return 'Confira o e-mail digitado';
    return null;
  }

  String? _validatePassword(String? value) =>
      (value ?? '').length < 6 ? 'A senha precisa ter 6 caracteres ou mais' : null;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final LoginViewModel vm = context.watch<LoginViewModel>();
    final AuthViewModel auth = context.watch<AuthViewModel>();

    return Scaffold(
      // No AppBar here, so the `Scaffold` places the body at top = 0 and Android 15
      // (edge-to-edge) draws the form under the status bar: the `SafeArea` restores
      // the inset.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'AppSeries',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSigningUp
                              ? 'Crie sua conta para começar seu catálogo'
                              : 'Seu catálogo de séries e filmes',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        if (auth.notice != null) ...<Widget>[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              auth.notice!,
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: tema.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: _email,
                          enabled: !vm.isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateEmail,
                          // The sentence has to leave as soon as she fixes the field:
                          // with the default mode the old error stays until the next
                          // submit, and she is left guessing.
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) => vm.clearError(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          enabled: !vm.isSubmitting,
                          obscureText: !_passwordVisible,
                          autofillHints: <String>[
                            _isSigningUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              // The suffix does not inherit `enabled` from the field,
                              // so a disabled form must disable it by hand.
                              onPressed: vm.isSubmitting
                                  ? null
                                  : () =>
                                      setState(() => _passwordVisible = !_passwordVisible),
                              icon: Icon(
                                _passwordVisible ? Icons.visibility_off : Icons.visibility,
                              ),
                              tooltip: _passwordVisible ? 'Esconder senha' : 'Mostrar senha',
                            ),
                          ),
                          validator: _validatePassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) => vm.clearError(),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (vm.error != null) ...<Widget>[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              vm.error!,
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: tema.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: vm.isSubmitting ? null : _submit,
                          child: vm.isEmailInFlight
                              ? const _EntrandoSpinner()
                              : Text(_isSigningUp ? 'Criar conta' : 'Entrar'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: vm.isSubmitting
                              ? null
                              : () => setState(() {
                                    _isSigningUp = !_isSigningUp;
                                    vm.clearError();
                                  }),
                          child: Text(
                            _isSigningUp ? 'Já tenho conta' : 'Ainda não tenho conta',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: <Widget>[
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ou', style: tema.textTheme.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: vm.isSubmitting ? null : _signInWithGoogle,
                          child: vm.isGoogleInFlight
                              ? const _EntrandoSpinner()
                              : const Text('Entrar com Google'),
                        ),
                      ],
                    ),
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

/// The progress shown **inside the button that was pressed**, with a label so a
/// screen reader does not announce an unnamed button while the request is out.
class _EntrandoSpinner extends StatelessWidget {
  const _EntrandoSpinner();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Entrando...',
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}
