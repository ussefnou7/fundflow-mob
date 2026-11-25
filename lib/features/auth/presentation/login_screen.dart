import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/public_links.dart';
import '../application/auth_controller.dart';
import '../data/biometric_auth_coordinator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tenant;
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tenant = TextEditingController(text: widget.controller.savedTenant);
  }

  @override
  void dispose() {
    _tenant.dispose();
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await widget.controller.login(
      tenant: _tenant.text,
      username: _username.text,
      password: _password.text,
      code: widget.controller.mfaRequired ? _code.text : null,
    );
    if (!success && mounted) {
      setState(() {});
      return;
    }
    final offer = widget.controller.biometricOffer;
    if (offer != null && mounted) {
      final (title, message, action) = switch (offer.reason) {
        BindingReason.phoneOfOtherAccount => (
          'هذا الجهاز مربوط بحساب آخر',
          'تقدر تدخل فقط من غير ربط، أو تربط الجهاز بحسابك فيُلغى ربطه بالحساب الآخر بعد موافقة مديرك المباشر.',
          'ربط الجهاز بحسابي',
        ),
        BindingReason.accountOnOtherPhone => (
          'حسابك مربوط بجهاز آخر',
          'تقدر تدخل فقط من غير ربط، أو تربط هذا الجهاز بحسابك بدل جهازك السابق بعد موافقة مديرك المباشر.',
          'ربط الجهاز بحسابي',
        ),
        BindingReason.unbound => (
          'ربط هذا الجهاز بحسابك',
          'الجهاز المربوط تدخل منه ببصمة الجهاز بدل كلمة المرور. الربط يحتاج موافقة مديرك المباشر.',
          'ربط الجهاز بحسابي',
        ),
        BindingReason.renew => (
          'تفعيل الدخول بالبصمة',
          'هذا الجهاز مربوط بحسابك. فعّل الدخول ببصمة الجهاز بدل كلمة المرور.',
          'تفعيل',
        ),
      };
      final bind = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('دخول فقط'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      );
      if (bind == true) {
        final awaiting = await widget.controller.bindOfferedDevice();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(switch (awaiting) {
                null => widget.controller.errorMessage ?? 'تعذر ربط الجهاز',
                true => 'تم إرسال طلب ربط الجهاز لمديرك المباشر',
                false => 'تم ربط الجهاز بحسابك',
              }),
            ),
          );
        }
      }
      widget.controller.completeLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The header under the status bar is light, so its icons stay dark even
    // when the phone is in dark mode.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.petrolDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Color(0xFF236B5B),
                    AppColors.petrolDark,
                    Color(0xFF0C2923),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x30030F0C),
                  ],
                  stops: [0, .58, 1],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final insets = MediaQuery.paddingOf(context);
                // The wave header scrolls with the form: with the keyboard up
                // nothing slides over the logo, and under a notch the logo sits
                // below the status bar.
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        _LoginHeader(topInset: insets.top),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            6,
                            18,
                            20 + insets.bottom,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'مرحبًا بعودتك',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      height: 1.2,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'إدارة أعمال شركتك تبدأ من هنا',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xCFFFFFFF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFCFFFFFF),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: const Color(0x33FFFFFF),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x4206110E),
                                          blurRadius: 50,
                                          offset: Offset(0, 22),
                                        ),
                                        BoxShadow(
                                          color: Color(0x0D06110E),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEAF3F0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  LucideIcons.shieldCheck,
                                                  size: 19,
                                                  color: AppColors.petrol,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'بيانات الدخول',
                                                      style: TextStyle(
                                                        color: AppColors
                                                            .petrolDark,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    Text(
                                                      'أدخل بيانات حساب شركتك',
                                                      style: TextStyle(
                                                        color: AppColors.muted,
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          if (widget.controller.errorMessage !=
                                              null) ...[
                                            _ErrorBox(
                                              message: widget
                                                  .controller
                                                  .errorMessage!,
                                            ),
                                            const SizedBox(height: 18),
                                          ],
                                          _LoginField(
                                            label: 'كود العميل',
                                            icon: LucideIcons.building2,
                                            controller: _tenant,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            autofillHints: const [
                                              AutofillHints.organizationName,
                                            ],
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(
                                                50,
                                              ),
                                            ],
                                          ),
                                          _LoginField(
                                            label: 'اسم الدخول',
                                            icon: LucideIcons.userRound,
                                            controller: _username,
                                            autofillHints: const [
                                              AutofillHints.username,
                                            ],
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(
                                                80,
                                              ),
                                            ],
                                          ),
                                          _LoginField(
                                            label: 'كلمة المرور',
                                            icon: LucideIcons.lockKeyhole,
                                            controller: _password,
                                            obscureText: _obscurePassword,
                                            suffixIcon: IconButton(
                                              tooltip: _obscurePassword
                                                  ? 'إظهار كلمة المرور'
                                                  : 'إخفاء كلمة المرور',
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                              icon: Icon(
                                                _obscurePassword
                                                    ? LucideIcons.eye
                                                    : LucideIcons.eyeOff,
                                                size: 19,
                                              ),
                                            ),
                                            autofillHints: const [
                                              AutofillHints.password,
                                            ],
                                            textInputAction:
                                                TextInputAction.done,
                                            onSubmitted: (_) => _submit(),
                                          ),
                                          if (widget.controller.mfaRequired)
                                            _LoginField(
                                              label: 'رمز التحقق',
                                              icon: LucideIcons.shieldCheck,
                                              controller: _code,
                                              autofillHints: const [
                                                AutofillHints.oneTimeCode,
                                              ],
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  6,
                                                ),
                                              ],
                                              onSubmitted: (_) => _submit(),
                                            ),
                                          const SizedBox(height: 2),
                                          FilledButton(
                                            onPressed:
                                                widget.controller.submitting
                                                ? null
                                                : _submit,
                                            style: FilledButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(54),
                                              backgroundColor: AppColors.petrol,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor: AppColors
                                                  .petrol
                                                  .withValues(alpha: .5),
                                              side: BorderSide.none,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              textStyle: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            child: widget.controller.submitting
                                                ? const SizedBox.square(
                                                    dimension: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.4,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text('تسجيل الدخول'),
                                                      SizedBox(width: 9),
                                                      Icon(
                                                        LucideIcons.arrowLeft,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                          if (widget
                                              .controller
                                              .biometricLoginAvailable) ...[
                                            const SizedBox(height: 10),
                                            OutlinedButton.icon(
                                              onPressed:
                                                  widget.controller.submitting
                                                  ? null
                                                  : widget
                                                        .controller
                                                        .loginWithBiometrics,
                                              icon: const Icon(
                                                LucideIcons.fingerprint,
                                                size: 20,
                                              ),
                                              label: const Text(
                                                'الدخول ببصمة الجهاز',
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        LucideIcons.shieldCheck,
                                        size: 15,
                                        color: Color(0xD9FFFFFF),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'اتصال آمن ومشفّر',
                                        style: TextStyle(
                                          color: Color(0xD9FFFFFF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const PublicLinks(color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The light wave with the wordmark. It grows by the status-bar inset so
/// the logo always sits below the notch or Dynamic Island.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final height = topInset + 132;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: const _LoginWaveShadowPainter()),
          ClipPath(
            clipper: const _LoginWaveClipper(),
            child: ColoredBox(
              color: const Color(0xFFF5F9F7),
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: Align(
                  alignment: const Alignment(0, -.38),
                  child: Image.asset(
                    'assets/images/monetizer-logo.png',
                    width: 236,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => const SizedBox.shrink(),
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

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onSubmitted,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onSubmitted,
      scrollPadding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: AppColors.petrolDark,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelAlignment: FloatingLabelAlignment.start,
        labelStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.petrol,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FBFA),
        prefixIcon: Icon(icon, size: 19, color: AppColors.petrol),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFCADDD7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.petrol, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.7),
        ),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label مطلوب' : null,
    ),
  );
}

class _LoginWaveClipper extends CustomClipper<Path> {
  const _LoginWaveClipper();

  @override
  Path getClip(Size size) => _loginWavePath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path _loginWavePath(Size size) => Path()
  ..lineTo(size.width, 0)
  ..lineTo(size.width, size.height * .68)
  ..quadraticBezierTo(
    size.width * .76,
    size.height * .98,
    size.width * .48,
    size.height * .78,
  )
  ..quadraticBezierTo(size.width * .2, size.height * .58, 0, size.height * .84)
  ..close();

class _LoginWaveShadowPainter extends CustomPainter {
  const _LoginWaveShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(_loginWavePath(size), const Color(0x8A061A15), 18, false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.circleAlert,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
