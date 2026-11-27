import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class EducationalAgreementDialog extends StatefulWidget {
  const EducationalAgreementDialog({super.key});

  static const String _keyAccepted = 'key_has_accepted_educational_policy_2026';

  /// Shows the agreement dialog if the user has not accepted it yet.
  static Future<bool> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAccepted = prefs.getBool(_keyAccepted) ?? false;
    if (alreadyAccepted) return true;

    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const EducationalAgreementDialog(),
    );

    if (accepted == true) {
      await prefs.setBool(_keyAccepted, true);
      return true;
    }
    return false;
  }

  @override
  State<EducationalAgreementDialog> createState() =>
      _EducationalAgreementDialogState();
}

class _EducationalAgreementDialogState
    extends State<EducationalAgreementDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class Connect Charter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'By Kzynovex • Hasham Rasheed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Educational Clarification Cards
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCharterItem(
                        icon: Icons.school_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: 'Solely for Educational Purposes',
                        description:
                            'This application is built as an academic class project to organize lecture timetables, class alerts, and verified study notes.',
                      ),
                      const SizedBox(height: 12),
                      _buildCharterItem(
                        icon: Icons.shield_rounded,
                        iconColor: const Color(0xFF059669),
                        title: 'Zero Unnecessary Data Collection',
                        description:
                            'We collect ONLY your Name, Google Email, and Roll Number solely to display your student profile. We do not track your location, contacts, device identifiers, or sell any information.',
                      ),
                      const SizedBox(height: 12),
                      _buildCharterItem(
                        icon: Icons.warning_amber_rounded,
                        iconColor: const Color(0xFFDC2626),
                        title: 'Strict Vault Upload Rules',
                        description:
                            'Do NOT upload personal photos, private documents, copyrighted books, or sensitive data. Upload solely verified lecture slides, handwritten study guides, and past exams.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Checkbox Agreement
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (val) =>
                            setState(() => _agreed = val ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'I understand and accept the Educational Use & Academic Community Guidelines.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action button
              FilledButton(
                onPressed: _agreed ? () => Navigator.pop(context, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Accept & Continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharterItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
