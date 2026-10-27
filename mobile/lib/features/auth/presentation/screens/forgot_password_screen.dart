import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _sending = false;
  bool _resetting = false;
  bool _tokenSent = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestToken() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final token = await context.read<AuthRepository>().forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _sending = false;
        _tokenSent = true;
        _tokenController.text = token ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset token generated. Set a new password below.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _reset() async {
    if (_tokenController.text.trim().isEmpty || _passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the reset token and a password of at least 8 characters.')),
      );
      return;
    }
    setState(() => _resetting = true);
    try {
      await context.read<AuthRepository>().resetPassword(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Sign in with your new password.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset_rounded, size: 48, color: AppTheme.primaryNavy),
            const SizedBox(height: 16),
            const Text('Forgot your password?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Enter your account email to generate a reset token.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
            const SizedBox(height: 22),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _requestToken,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Reset Token'),
            ),
            if (_tokenSent) ...[
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Set a new password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Reset token',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: _tokenController.text)),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _resetting ? null : _reset,
                child: _resetting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
