import 'dart:ui' as ui;
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/widgets/sports_button.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onRegister});

  final VoidCallback? onRegister;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false; // متغير جديد لزر تذكرني

  @override
  void initState() {
    super.initState();
    _loadRememberMe(); // تحميل حالة تذكرني عند فتح الشاشة
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      
      // حفظ حالة تذكرني بشكل صحيح
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        // هنا يمكنك إضافة كود لحفظ البريد الإلكتروني إذا أردت
      } else {
        await prefs.remove('remember_me');
      }
      
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('أدخل بريدك الإلكتروني أولاً.');
      return;
    }

    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(_emailController.text);
      if (mounted) {
        _showMessage('أرسلنا رابط إعادة تعيين كلمة المرور إلى بريدك.');
      }
    } on AuthServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07120A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF0A2110),
                    Color(0xFF050807),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _PitchLinesPainter()),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.sports_soccer,
                            size: 72,
                            color: Color(0xFF00E676),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _glassInputDecoration(
                              label: 'البريد الإلكتروني',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty || !email.contains('@')) {
                                return 'أدخل بريداً إلكترونياً صالحاً.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: _glassInputDecoration(
                              label: 'كلمة المرور',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                color: Colors.white70,
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'أدخل كلمة المرور.'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          
                          // إضافة زر تذكرني هنا
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                                activeColor: const Color(0xFF00E676),
                                checkColor: Colors.black,
                              ),
                              const Text(
                                'تذكرني',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                child: const Text('نسيت كلمة المرور؟'),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          SportsButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('دخول'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading ? null : widget.onRegister,
                            child: const Text('ليس لديك حساب؟ أنشئ حساباً'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _glassInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    prefixIcon: Icon(icon, color: Colors.white70),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.07),
    enabledBorder: outline,
    focusedBorder: outline.copyWith(
      borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
    ),
    errorBorder: outline.copyWith(
      borderSide: const BorderSide(color: Color(0xFFFF8A80)),
    ),
    focusedErrorBorder: outline.copyWith(
      borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
    ),
  );
}

class _PitchLinesPainter extends CustomPainter {
  const _PitchLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final field = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.12,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRect(field, paint);
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      paint,
    );
    canvas.drawCircle(field.center, size.shortestSide * 0.17, paint);
    canvas.drawRect(
      Rect.fromLTRB(
        field.left,
        field.top + field.height * 0.3,
        field.left + field.width * 0.17,
        field.bottom - field.height * 0.3,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        field.right - field.width * 0.17,
        field.top + field.height * 0.3,
        field.right,
        field.bottom - field.height * 0.3,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter oldDelegate) => false;
}