import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
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
          'الجهاز المربوط تدخل منه بالبصمة وتُحتسب بصمات حضورك منه مباشرة. الربط يحتاج موافقة مديرك المباشر.',
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.petrolDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.petrol, AppColors.petrolDark, Color(0xFF0F2A24)],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  18,
                  28,
                  18,
                  28 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x38151C1A),
                                  blurRadius: 60,
                                  offset: Offset(0, 20),
                                ),
                                BoxShadow(
                                  color: Color(0x0F151C1A),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Image.asset(
                                    'assets/images/monetizer-logo.png',
                                    height: 64,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stack) =>
                                        const SizedBox(height: 64),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'تسجيل الدخول',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.petrolDark,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (widget.controller.errorMessage !=
                                      null) ...[
                                    _ErrorBox(
                                      message: widget.controller.errorMessage!,
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  _LoginField(
                                    label: 'كود العميل',
                                    controller: _tenant,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    autofillHints: const [
                                      AutofillHints.organizationName,
                                    ],
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(50),
                                    ],
                                  ),
                                  _LoginField(
                                    label: 'اسم الدخول',
                                    controller: _username,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(80),
                                    ],
                                  ),
                                  _LoginField(
                                    label: 'كلمة المرور',
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
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                  ),
                                  if (widget.controller.mfaRequired)
                                    _LoginField(
                                      label: 'رمز التحقق',
                                      controller: _code,
                                      autofillHints: const [
                                        AutofillHints.oneTimeCode,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      onSubmitted: (_) => _submit(),
                                    ),
                                  const SizedBox(height: 6),
                                  FilledButton(
                                    onPressed: widget.controller.submitting
                                        ? null
                                        : _submit,
                                    child: widget.controller.submitting
                                        ? const SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
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
                                      onPressed: widget.controller.submitting
                                          ? null
                                          : widget
                                                .controller
                                                .loginWithBiometrics,
                                      icon: const Icon(
                                        LucideIcons.fingerprint,
                                        size: 20,
                                      ),
                                      label: const Text('الدخول ببصمة الجهاز'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
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
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            textCapitalization: textCapitalization,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            onFieldSubmitted: onSubmitted,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.petrolDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(suffixIcon: suffixIcon),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '$label مطلوب' : null,
          ),
        ],
      ),
    );
  }
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
