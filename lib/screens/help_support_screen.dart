import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../constants/help_support_config.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';

/// Help centre: FAQs, mail/call shortcuts, and copy-paste diagnostics for IT/HR.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, this.adminView = false});

  final bool adminView;

  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: HelpSupportConfig.supportEmail,
    queryParameters: <String, String>{
      'subject': 'myRekod — Support request',
      'body': 'Please describe your issue below:\n\n',
    },
  );

  Uri? get _phoneUri {
    final raw = HelpSupportConfig.supportPhone.trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    return Uri(scheme: 'tel', path: digits);
  }

  String _platformLabel() {
    if (kIsWeb) return 'Web';
    return defaultTargetPlatform.name;
  }

  String _diagnosticsLine(AppUser? u) {
    final role = u?.isAdmin == true ? 'Administrator' : 'Employee';
    final email = u?.email.trim() ?? '—';
    final name = u?.name.trim() ?? '';
    final who = name.isEmpty ? email : '$name · $email';
    return '''
myRekod · v${HelpSupportConfig.appVersionLabel}
Role: $role
Account: $who
Platform: ${_platformLabel()}'''.trim();
  }

  Future<void> _openUri(BuildContext context, Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No app available to open this link.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyDiagnostics(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    final text = _diagnosticsLine(user);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copied — paste into your email to HR/IT.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_Faq> _faqs() {
    final admin = <_Faq>[
      const _Faq(
        q: 'Where do I approve leave and claims?',
        a:
            'From Admin Home → open Leave hub or Claims. Pending counts appear on your dashboard cards. Approve or reject with remarks; employees see the outcome in real time.',
      ),
      const _Faq(
        q: 'How do payroll runs and salary settings work?',
        a:
            'Open Payroll from the admin workspace. Configure salary packages under employee salary settings, create or open a payroll run for the month, then review items and payslips. Manual recalculation is available per employee when needed.',
      ),
      const _Faq(
        q: 'How do I manage team attendance?',
        a:
            'Use the Attendance tab on the bottom bar for today’s overview, or open Employees to view profiles. Live updates refresh when attendance or requests change.',
      ),
    ];

    final everyone = <_Faq>[
      const _Faq(
        q: 'How do I clock in and out?',
        a:
            'Use the centre Clock tab on the bottom bar. Clock in when you arrive and clock out when you leave. If location is required, allow location access when prompted so your check-in can be verified.',
      ),
      const _Faq(
        q: 'Why is my leave or claim still pending?',
        a:
            'Managers review requests in Leave hub and Claims. You will be notified when the status changes. If it has been a long time, contact your supervisor or HR using the options below.',
      ),
      const _Faq(
        q: 'Where are my payslips?',
        a:
            'Open Payroll / My payslips from the home shortcuts or your Profile. You can view history and download PDFs when your administrator has published them.',
      ),
      const _Faq(
        q: 'How do I change my password?',
        a:
            'Go to Profile → Change password while signed in. If you cannot sign in, use your organisation’s password reset process or contact IT/HR — they can verify your account.',
      ),
      const _Faq(
        q: 'The app feels slow or will not load',
        a:
            'Check your internet connection first. Try closing other tabs or apps, then reopen this app. If problems persist, copy diagnostics below and email HR/IT with what you were doing.',
      ),
    ];

    if (adminView) return [...admin, ...everyone];
    return everyone;
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phoneUri;
    final faqItems = _faqs();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Help & support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _introCard(),
            const SizedBox(height: 18),
            Text(
              'Contact',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary.withValues(alpha: 0.85),
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 10),
            _contactTile(
              context,
              icon: Icons.mail_outline_rounded,
              title: 'Email HR / IT',
              subtitle: HelpSupportConfig.supportEmail,
              onTap: () => _openUri(context, _emailUri),
            ),
            if (phone != null) ...[
              const SizedBox(height: 8),
              _contactTile(
                context,
                icon: Icons.phone_in_talk_rounded,
                title: 'Call support',
                subtitle: HelpSupportConfig.supportPhone.trim(),
                onTap: () => _openUri(context, phone),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              HelpSupportConfig.officeHours,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Common questions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary.withValues(alpha: 0.85),
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: AppElevation.cardOnSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: AppColors.primary.withValues(alpha: 0.06),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < faqItems.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.divider.withValues(alpha: 0.85),
                        ),
                      ExpansionTile(
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        title: Text(
                          faqItems[i].q,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              faqItems[i].a,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _copyDiagnostics(context),
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text('Copy diagnostics for support'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'myRekod · v${HelpSupportConfig.appVersionLabel}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: adminView ? AppGradients.violet : AppGradients.primary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandHeaderBorder.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: (adminView ? AppColors.violet : AppColors.primaryDark)
                .withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandChipFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.brandChipBorder),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.onBrand.withValues(alpha: 0.95),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "We're here to help",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBrand,
                    letterSpacing: -0.35,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            adminView
                ? 'Quick answers for administrators, plus a direct line to HR or IT when you need backend or account help.'
                : 'Find answers below, or reach HR / IT using email or phone. If something looks wrong, copy diagnostics and send it with your message — that speeds things up.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: AppColors.onBrandMuted.withValues(alpha: 0.98),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: AppColors.textHint.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Faq {
  const _Faq({required this.q, required this.a});

  final String q;
  final String a;
}
