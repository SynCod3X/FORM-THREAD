import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

const _paper = Color(0xFFF8F6F1);
const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _olive = Color(0xFF68715A);

typedef SaveCustomerProfile = Future<void> Function(
  String name,
  String contactNumber,
  String address,
);

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({
    super.key,
    required this.profile,
    this.saveProfile,
  });

  final Map<String, dynamic> profile;
  final SaveCustomerProfile? saveProfile;

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.profile['full_name'] as String? ?? '',
    );
    _phone = TextEditingController(
      text: widget.profile['contact_number'] as String? ?? '',
    );
    _address = TextEditingController(
      text: widget.profile['address'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.saveProfile != null) {
        await widget.saveProfile!(
          _name.text.trim(),
          _phone.text.trim(),
          _address.text.trim(),
        );
      } else {
        await AuthService.updateMyProfile(
          name: _name.text,
          contactNumber: _phone.text,
          address: _address.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.profile['email'] as String? ?? '';
    final initial = _name.text.trim().isEmpty
        ? '?'
        : _name.text.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        title: const Text('PROFILE DETAILS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 29,
                            backgroundColor: const Color(0xFFE9EDE2),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 24,
                                color: _olive,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile['full_name'] as String? ??
                                      'Your profile',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Arial',
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'PERSONAL INFORMATION',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Keep these details up to date for your deliveries.',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _profileField(
                      'FULL NAME',
                      _name,
                      Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                    ),
                    _profileField(
                      'CONTACT NUMBER',
                      _phone,
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    _profileField(
                      'DELIVERY ADDRESS',
                      _address,
                      Icons.location_on_outlined,
                      maxLines: 3,
                      keyboardType: TextInputType.streetAddress,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _olive,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_saving ? 'SAVING...' : 'SAVE CHANGES'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter ${label.toLowerCase()}.'
              : null,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: maxLines > 1 ? 48 : 0),
              child: Icon(icon, color: _olive, size: 20),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E2D9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _olive, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFAB5A4F)),
            ),
          ),
        ),
      ],
    ),
  );
}
