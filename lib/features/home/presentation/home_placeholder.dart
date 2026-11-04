import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';

class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.petrolDark,
        foregroundColor: Colors.white,
        title: const SizedBox(
          width: 88,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: Image(image: AssetImage('assets/images/monetizer-logo.png')),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: controller.submitting ? null : controller.logout,
            icon: const Icon(LucideIcons.logOut),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wallet, size: 48, color: AppColors.petrol),
              const SizedBox(height: 18),
              Text(
                'أهلًا، ${user.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'تم تسجيل الدخول بنجاح. شاشة العهدة هي المرحلة التالية.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
