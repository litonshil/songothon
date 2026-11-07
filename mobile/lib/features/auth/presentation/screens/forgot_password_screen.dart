import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

enum _ResetStep { email, code }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendCooldown = 30;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _sending = false;
  bool _resetting = false;
  bool _obscure = true;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppTheme.errorRed : null),
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !(_emailFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final message = await context.read<AuthRepository>().forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _sending = false;
        _step = _ResetStep.code;
      });
      _startCooldown();
      _showSnack(resend ? 'A new code has been sent.' : message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnack(e.toString(), error: true);
    }
  }

  void _changeEmail() {
    _cooldownTimer?.cancel();
    setState(() {
      _step = _ResetStep.email;
      _cooldown = 0;
      _codeController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _reset() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _resetting = true);
    try {
      await context.read<AuthRepository>().resetPassword(
            token: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      _showSnack('Password updated. Sign in with your new password.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      _showSnack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCodeStep = _step == _ResetStep.code;
    return PopScope(
      // On the code step, the back button returns to the email step first.
      canPop: !onCodeStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && onCodeStep) _changeEmail();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: onCodeStep ? _buildCodeStep() : _buildEmailStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({required IconData icon, required String title, required Widget subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 48, color: AppTheme.primaryNavy),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        subtitle,
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            icon: Icons.lock_reset_rounded,
            title: 'Forgot your password?',
            subtitle: const Text('Enter your account email and we will send you a reset code.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _sending ? null : _sendCode(),
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Enter your email address';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _sendCode,
            child: _sending ? _spinner() : const Text('Send Reset Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        key: const ValueKey('code-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            icon: Icons.mark_email_read_outlined,
            title: 'Check your email',
            subtitle: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
                children: [
                  const TextSpan(text: 'We sent an 8-character code to '),
                  TextSpan(
                    text: _emailController.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
                  ),
                  const TextSpan(text: '. It expires in 30 minutes. Check your spam folder if you don\'t see it.'),
                ],
              ),
            ),
          ),
          TextFormField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Reset code',
              hintText: 'ABCD-EFGH',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            validator: (v) {
              final code = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
              if (code.isEmpty) return 'Enter the code from your email';
              if (code.length != 8) return 'The code has 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetting ? null : _reset(),
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
            validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _resetting ? null : _reset,
            child: _resetting ? _spinner() : const Text('Update Password'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _resetting ? null : _changeEmail,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Change email'),
              ),
              TextButton(
                onPressed: (_sending || _resetting || _cooldown > 0) ? null : () => _sendCode(resend: true),
                child: _sending
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
