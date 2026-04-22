import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_formatter.dart' show UzPhoneFormatter, phoneToRaw;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1=telefon, 2=OTP, 3=yangi parol
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _rawPhone => phoneToRaw(_phoneController.text);

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _nextStep(int next) {
    setState(() => _step = next);
    _animController
      ..reset()
      ..forward();
  }

  // ── Qadam 1: SMS yuborish ────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      _showSnack("To'liq telefon raqam kiriting");
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        _confirmationResult =
            await FirebaseAuth.instance.signInWithPhoneNumber(_rawPhone);
        _nextStep(2);
        setState(() => _isLoading = false);
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: _rawPhone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential cred) async {
            await _signInWithCred(cred);
          },
          verificationFailed: (FirebaseAuthException e) {
            _showSnack(e.message ?? 'SMS yuborishda xato');
            setState(() => _isLoading = false);
          },
          codeSent: (String vId, int? _) {
            _verificationId = vId;
            _nextStep(2);
            setState(() => _isLoading = false);
          },
          codeAutoRetrievalTimeout: (String vId) {
            _verificationId = vId;
          },
        );
      }
    } catch (e) {
      _showSnack(e.toString());
      setState(() => _isLoading = false);
    }
  }

  // ── Qadam 2: OTP tasdiqlash ──────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      _showSnack('6 raqamli kodni kiriting');
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        await _confirmationResult!.confirm(code);
        _nextStep(3);
        setState(() => _isLoading = false);
      } else {
        final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        await _signInWithCred(cred);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Tasdiqlashda xato';
      if (e.code == 'invalid-verification-code') msg = "Kod noto'g'ri";
      if (e.code == 'session-expired') {
        msg = "Kod muddati o'tdi. Qayta yuboring";
      }
      _showSnack(msg);
      setState(() => _isLoading = false);
    } catch (e) {
      _showSnack(e.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCred(PhoneAuthCredential cred) async {
    await FirebaseAuth.instance.signInWithCredential(cred);
    _nextStep(3);
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Qadam 3: Yangi parol ─────────────────────────────────────────────────
  Future<void> _updatePassword() async {
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPass.length < 6) {
      _showSnack("Parol kamida 6 ta belgi bo'lishi kerak");
      return;
    }
    if (newPass != confirm) {
      _showSnack("Parollar mos emas");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Foydalanuvchi topilmadi');

      // Akkaunt parol bilan ro'yxatdan o'tmagan
      final providers =
          user.providerData.map((p) => p.providerId).toList();
      if (!providers.contains('password')) {
        await FirebaseAuth.instance.signOut();
        _showSnack(
            "Bu raqam bilan hisob topilmadi yoki parol o'rnatilmagan");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _step = 1;
          });
        }
        return;
      }

      await user.updatePassword(newPass);
      _showSnack('Parol muvaffaqiyatli yangilandi!', isError: false);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Parol yangilashda xato';
      if (e.code == 'requires-recent-login') {
        msg = 'Qayta kirish talab qilinadi';
      }
      if (e.code == 'weak-password') msg = 'Parol juda oddiy';
      _showSnack(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF0F172A),
              Color(0xFF162032),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildCurrentStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() => switch (_step) {
        1 => _buildStep1(),
        2 => _buildStep2(),
        _ => _buildStep3(),
      };

  Widget _stepHeader(String title, String subtitle,
      {VoidCallback? onBack}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        IconButton(
          onPressed: onBack ?? () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 36),
      ],
    );
  }

  // ── Step 1: Telefon ──────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Parolni\ntiklash',
          "Ro'yxatdan o'tishda kiritgan telefon raqamingizni kiriting",
        ),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [UzPhoneFormatter()],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Telefon raqam',
            prefixText: '+998 ',
            prefixStyle: TextStyle(color: AppColors.textPrimary),
            hintText: '90 123-45-67',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.textSecondary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Faqat ro'yxatdan o'tishda telefon kiritgan foydalanuvchilar uchun mavjud.",
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendOtp,
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
              : const Text('SMS kod yuborish',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 2: OTP ──────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'SMS kodni\nkiriting',
          '+998 ${_phoneController.text} raqamiga\n6 raqamli kod yuborildi',
          onBack: () => _nextStep(1),
        ),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              letterSpacing: 12,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
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
              : const Text('Tasdiqlash',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : () => _nextStep(1),
            child: const Text('Qayta yuborish',
                style: TextStyle(color: AppColors.accent)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 3: Yangi parol ──────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Yangi parol\nkiriting',
          'Xavfsiz parol tanlang',
          onBack: () => _nextStep(2),
        ),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Yangi parol',
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Parolni tasdiqlang',
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _isLoading ? null : _updatePassword,
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
              : const Text('Parolni saqlash',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
