import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isBusy = false;
  String? _formStatus;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE8DF),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.checkroom_outlined,
                        size: 48,
                        color: _olive,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Make yourself at home.',
                    style: TextStyle(fontSize: 29),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Create an account to save your favorite finds.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _label('NAME'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _nameController,
                    hint: 'Name',
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter your name.'
                        : null,
                  ),
                  const SizedBox(height: 15),
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
                  const SizedBox(height: 15),
                  _label('CONTACT NO.'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _contactController,
                    hint: 'Contact number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final digits =
                          value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                      return digits.length < 7
                          ? 'Enter a valid contact number.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 15),
                  _label('ADDRESS'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _addressController,
                    hint: 'Street, city, and postal code',
                    icon: Icons.location_on_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter your address.'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  _label('PASSWORD'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _passwordController,
                    hint: 'At least 8 characters',
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
                    validator: (value) => value == null || value.length < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  _label('CONFIRM PASSWORD'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _confirmPasswordController,
                    hint: 'Re-enter your password',
                    icon: Icons.lock_outline,
                    obscureText: _hideConfirmPassword,
                    suffix: IconButton(
                      onPressed: () => setState(
                        () => _hideConfirmPassword = !_hideConfirmPassword,
                      ),
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password.';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
        decoration: const BoxDecoration(
          color: _paper,
          border: Border(top: BorderSide(color: Color(0xFFE6E2D9))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_formStatus != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8DF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formStatus!,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 49,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: _isBusy ? null : _submit,
                child: _isBusy
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Sign in',
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AuthService.isConfigured) {
      setState(
        () => _formStatus = 'Supabase is not configured. Run the app with the Supabase URL and publishable key.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _formStatus = null;
    });
    try {
      final response = await AuthService.createAccount(
        name: _nameController.text,
        email: _emailController.text,
        contactNumber: _contactController.text,
        address: _addressController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(
          () => _formStatus = 'Account created, but Supabase still requires email confirmation. Turn off Confirm email in Supabase Auth settings, then try again with a new email address.',
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      final message = error.message.toLowerCase();
      setState(() {
        if (message.contains('database error saving new user') ||
            message.contains('unexpected_failure')) {
          _formStatus = 'Supabase could not save the account. Run the latest myapp/supabase/schema.sql in the Supabase SQL Editor, then check Authentication → Audit Logs if it still fails.';
        } else if (message.contains('email signups are disabled')) {
          _formStatus = 'Email signup is disabled in Supabase. Enable the Email provider and keep Allow new users to sign up on.';
        } else if (message.contains('already registered') ||
            message.contains('user already exists')) {
          _formStatus = 'An account already exists for this email. Sign in, or use Forgot password after email delivery is configured.';
        } else {
          _formStatus = error.message;
        }
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _formStatus = 'Could not create the account. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
