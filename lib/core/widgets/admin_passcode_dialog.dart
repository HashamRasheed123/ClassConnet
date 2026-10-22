import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../../features/admin/admin_management_screen.dart';
import '../../providers/class_providers.dart';

Future<bool> showAdminPasscodeDialog(
  BuildContext context,
  WidgetRef ref, {
  bool autoOpenConsole = true,
}) async {
  final currentUser = ref.read(currentUserProvider);
  final isDesignatedAdmin = AuthService.isAdminEmail(currentUser.email);

  // Condition 1: Must be a designated Admin Google Account!
  if (!isDesignatedAdmin) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: Only designated Admin Google Accounts can access the Admin Panel.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return false;
  }

  // Condition 2: Prompt for Admin Password!
  final controller = TextEditingController();
  bool obscureText = true;
  bool isChecking = false;
  String? errorText;

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> submit() async {
          final passkey = controller.text.trim();
          if (passkey.isEmpty) {
            setState(() => errorText = 'Please enter the Admin Password.');
            return;
          }

          setState(() {
            isChecking = true;
            errorText = null;
          });

          final authResult = await ref
              .read(currentUserProvider.notifier)
              .elevateToAdmin(passkey);

          if (ctx.mounted) {
            if (authResult.success) {
              Navigator.of(ctx).pop(true);
            } else {
              setState(() {
                isChecking = false;
                errorText = authResult.message;
              });
            }
          }
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Authentication',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Admin Password Required',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User identity badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentUser.email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Verified Admin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Enter the administrator password to unlock console privileges:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: controller,
                obscureText: obscureText,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Enter Admin Password',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => obscureText = !obscureText),
                  ),
                  errorText: errorText,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isChecking ? null : () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton.icon(
              onPressed: isChecking ? null : submit,
              icon: isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded, size: 16),
              label: Text(isChecking ? 'Verifying...' : 'Unlock Console'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        );
      },
    ),
  );

  final unlocked = result ?? false;

  if (unlocked && autoOpenConsole && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminManagementScreen(),
      ),
    );
  }

  return unlocked;
}
