import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_account_screen.dart';
import '../services/auth_service.dart';
import 'staff_dashboard_screen.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isBusy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: _paper,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text(
        'FORM & THREAD',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brandMark(),
                  const SizedBox(height: 30),
                  const Text('Welcome back.', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: 9),
                  const Text(
                    'Sign in to pick up where you left off.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 27),
                  _label('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _emailController,
                    hint: 'you@example.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        value == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                  const SizedBox(height: 17),
                  _label('PASSWORD'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _passwordController,
                    hint: 'Your password',
                    icon: Icons.lock_outline,
                    obscureText: _hidePassword,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: _olive,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _primaryButton(
                    label: 'SIGN IN',
                    onPressed: _isBusy ? null : _submit,
                    isBusy: _isBusy,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New to Form & Thread?',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: _muted,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountScreen(),
                          ),
                        ),
                        child: const Text(
                          'Create account',
                          style: TextStyle(
                            fontFamily: 'Arial',
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _brandMark() => Container(
    height: 150,
    decoration: BoxDecoration(
      color: const Color(0xFFEAE8DF),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 53, color: _olive),
    ),
  );

  Widget _label(String value) => Text(
    value,
    style: const TextStyle(
      fontFamily: 'Arial',
      color: _muted,
      fontSize: 9,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    obscureText: obscureText,
    style: const TextStyle(fontFamily: 'Arial', fontSize: 14, color: _ink),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFAAA69D),
        fontFamily: 'Arial',
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, size: 19, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFFDDD9D0)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFFDDD9D0)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: _olive, width: 1.4),
      ),
      errorStyle: const TextStyle(fontFamily: 'Arial', fontSize: 11),
    ),
  );

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isBusy = false,
  }) => SizedBox(
    height: 51,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      onPressed: onPressed,
      child: isBusy
          ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AuthService.isConfigured) {
      _showMessage(
        'Supabase is not configured. Run the app with the Supabase URL and publishable key.',
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await AuthService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final profile = await AuthService.loadMyProfile();
      final role = (profile['role'] as String? ?? 'customer')
          .trim()
          .toLowerCase();
      if (!mounted) return;
      if (role == 'staff') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      final message = error.message.toLowerCase();
      _showMessage(
        message.contains('invalid login credentials')
            ? 'Email or password is incorrect. Check both and try again.'
            : error.message,
      );
    } catch (_) {
      if (mounted)
        _showMessage('Could not sign in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Enter your email address first, then tap Forgot password.');
      return;
    }
    if (!AuthService.isConfigured) {
      _showMessage(
        'Supabase is not configured. Run the app with the Supabase URL and publishable key.',
      );
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted)
        _showMessage(
          'If an account exists for this email, a reset link has been sent.',
        );
    } on AuthException catch (error) {
      if (!mounted) return;
      final message = error.message.toLowerCase();
      _showMessage(
        message.contains('error sending recovery email') ||
                message.contains('unexpected_failure')
            ? 'Supabase could not send the reset email. Configure and verify SMTP under Authentication → Emails, then try again.'
            : error.message,
      );
    } catch (_) {
      if (mounted) _showMessage('Could not send the reset email. Try again.');
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Arial')),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
