import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_state.dart';
import 'face_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _usernameError;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _syntheticEmail =>
      '${_usernameCtrl.text.trim().toLowerCase()}@uyborapp.uz';

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Username uniqueness check ─────────────────────────────────────────────
  Future<bool> _isUsernameAvailable(String username) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  // ── Location (best-effort) ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));

      String city = '';
      try {
        final marks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          city = marks.first.locality ?? marks.first.administrativeArea ?? '';
        }
      } catch (_) {}

      return {'lat': pos.latitude, 'lng': pos.longitude, 'city': city};
    } catch (_) {
      return null;
    }
  }

  // ── Upload face photo (best-effort) ──────────────────────────────────────
  Future<String?> _uploadFace(XFile photo, String uid) async {
    try {
      final ref = FirebaseStorage.instance.ref('face_photos/$uid.jpg');
      final bytes = await photo.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // ── Main register flow ────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim().toLowerCase();

    // 1. Check username availability
    setState(() => _isLoading = true);
    final available = await _isUsernameAvailable(username);
    if (!mounted) return;
    if (!available) {
      setState(() {
        _isLoading = false;
        _usernameError = 'Bu username band';
      });
      return;
    }
    setState(() {
      _isLoading = false;
      _usernameError = null;
    });

    // 2. Face verification
    final faceResult = await Navigator.push<FaceVerificationResult>(
      context,
      MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
    );
    if (!mounted) return;

    // 3. Create account
    setState(() => _isLoading = true);
    try {
      final location = await _getLocation();

      AuthState.isRegistering = true;
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _syntheticEmail,
        password: _passwordCtrl.text,
      );
      final uid = cred.user!.uid;

      // Upload face if taken
      final facePhoto = faceResult?.photo;
      final isVerified = faceResult != null && !faceResult.skipped;
      String? facePhotoUrl;
      if (isVerified && facePhoto != null) {
        facePhotoUrl = await _uploadFace(facePhoto, uid);
      }

      // Optional phone normalization
      final rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      final phone = rawPhone.isEmpty ? null : '+$rawPhone';
      final email = _emailCtrl.text.trim().isEmpty
          ? null
          : _emailCtrl.text.trim();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameCtrl.text.trim(),
        'displayName': _nameCtrl.text.trim(),
        'username': username,
        'phone': phone,
        'email': email,
        'isVerified': isVerified,
        'facePhotoUrl': facePhotoUrl,
        'location': location,
        'role': 'user',
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'avatar': '',
      });

      AuthState.isRegistering = false;
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      AuthState.isRegistering = false;
      String msg = 'Xato yuz berdi';
      if (e.code == 'email-already-in-use') msg = 'Bu username allaqachon band';
      if (e.code == 'weak-password') msg = 'Parol juda oddiy';
      _showSnack(msg);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      AuthState.isRegistering = false;
      _showSnack('Xato: ${e.toString()}');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF0F172A), Color(0xFF162032)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: AppColors.textPrimary),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Ro'yxatdan\no'tish",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Yangi hisob yarating',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 32),

                      // ── To'liq ism ──
                      TextFormField(
                        controller: _nameCtrl,
                        style:
                            const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: "To'liq ism",
                          hintText: 'Javohir Toshmatov',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ismingizni kiriting';
                          }
                          if (v.trim().length < 3) {
                            return 'Ism kamida 3 ta harf';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Username ──
                      TextFormField(
                        controller: _usernameCtrl,
                        style:
                            const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'javohir_98',
                          prefixIcon:
                              const Icon(Icons.alternate_email_rounded),
                          errorText: _usernameError,
                        ),
                        onChanged: (_) {
                          if (_usernameError != null) {
                            setState(() => _usernameError = null);
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Username kiriting';
                          }
                          if (v.trim().length < 3) {
                            return 'Username kamida 3 ta belgi';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$')
                              .hasMatch(v.trim())) {
                            return "Faqat harf, raqam va _ belgisi";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Parol ──
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        style:
                            const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Parol',
                          hintText: '••••••••',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Parol kiriting';
                          }
                          if (v.length < 6) {
                            return 'Parol kamida 6 ta belgi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Parolni tasdiqlash ──
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        style:
                            const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Parolni tasdiqlang',
                          hintText: '••••••••',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Parolni tasdiqlang';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Parollar mos emas';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Ixtiyoriy bo'lim ──
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(color: AppColors.divider)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Ixtiyoriy',
                              style: TextStyle(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Telefon (optional) ──
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style:
                            const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Telefon raqam',
                          hintText: '+998 90 123-45-67',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Email (optional) ──
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style:
                            const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'example@mail.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            if (!v.contains('@') || !v.contains('.')) {
                              return "Email noto'g'ri formatda";
                            }
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Yuz tekshiruvi haqida ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.face_outlined,
                                color: AppColors.accent, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Keyingi qadamda yuz tekshiruvidan o'tishingiz so'raladi. "
                                "Bu ixtiyoriy — o'tkazib yuborishingiz mumkin.",
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Ro'yxatdan o'tish button ──
                      ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                "Ro'yxatdan o'tish",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Hisobingiz bormi? ',
                              style: TextStyle(
                                  color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Kirish',
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
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
