import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../constants/help_support_config.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';

const Color _kNavy = Color(0xFF14213D);
const Color _kPageBg = Color(0xFFF5F6F8);
const Color _kBorder = Color(0xFFE4E6EB);
const Color _kInputBorder = Color(0xFFD8DBE2);
const Color _kMuted = Color(0xFF9AA1AD);
const Color _kHairline = Color(0xFFEEF0F3);
const Color _kHeroBody = Color(0xFFC7CCD6);
const Color _kVersion = Color(0xFFB4B9C2);
const Color _kBlue = Color(0xFF185FA5);
const Color _kBlueBg = Color(0xFFE6F1FB);

/// Help centre: FAQs, mail/call shortcuts, and copy-paste diagnostics for IT/HR.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, this.adminView = false});

  final bool adminView;

  Uri? get _emailUri {
    final raw = HelpSupportConfig.supportEmail.trim();
    if (raw.isEmpty) return null;
    return Uri(
      scheme: 'mailto',
      path: raw,
      queryParameters: <String, String>{
        'subject': 'myRekod support request',
        'body': 'Please describe your issue below:\n\n',
      },
    );
  }

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
        content: Text(
          'Diagnostics copied. Share with HR/IT when you contact them.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_Faq> _faqs() {
    final admin = <_Faq>[
      const _Faq(
        q: 'Where do I approve leave and claims?',
        a:
            'From Admin Home, open Leave hub or Claims. Approve or reject with remarks. Employees see the update when it is done.',
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
            'Use the centre Clock tab. Clock in when you arrive and clock out when you leave. If HR turned on workplace location, you must be inside the set radius and allow GPS. Clock-out does not need location.',
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
            'Signed in: staff use Profile → Change password; admin use Home → Change password. Signed out: Login → Forgot password → open the email link → set and confirm a new password → sign in. Expired links need a new reset email. For account issues, call support.',
      ),
      const _Faq(
        q: 'The app feels slow or will not load',
        a:
            'Check your internet connection first. Try closing other tabs or apps, then reopen this app. If problems persist, copy diagnostics below and share them with HR/IT along with what you were doing.',
      ),
    ];

    if (adminView) return [...admin, ...everyone];
    return everyone;
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.06 * 11,
        color: _kMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailUri;
    final phone = _phoneUri;
    final faqItems = _faqs();
    final hasContact = email != null || phone != null;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: AppChrome.onBrand,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        title: const Text('Help & support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _introCard(),
            if (hasContact) ...[
              const SizedBox(height: 20),
              _sectionLabel('Contact'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (email != null)
                      _contactTile(
                        context,
                        icon: Icons.mail_outline_rounded,
                        title: 'Email HR / IT',
                        subtitle: HelpSupportConfig.supportEmail.trim(),
                        onTap: () => _openUri(context, email),
                      ),
                    if (email != null && phone != null)
                      const Divider(height: 1, thickness: 1, color: _kHairline),
                    if (phone != null)
                      _contactTile(
                        context,
                        icon: Icons.phone_rounded,
                        title: 'Call support',
                        subtitle: HelpSupportConfig.supportPhone.trim(),
                        onTap: () => _openUri(context, phone),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                HelpSupportConfig.officeHours,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                  color: _kMuted,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _sectionLabel('Common questions'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: _kNavy.withValues(alpha: 0.06),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < faqItems.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: _kHairline,
                        ),
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          14,
                        ),
                        iconColor: _kMuted,
                        collapsedIconColor: _kMuted,
                        title: Text(
                          faqItems[i].q,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kNavy,
                            height: 1.3,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              faqItems[i].a,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                                color: _kMuted,
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
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _copyDiagnostics(context),
                icon: const Icon(Icons.copy_rounded, size: 18, color: _kNavy),
                label: const Text(
                  'Copy diagnostics for support',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _kNavy,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _kNavy,
                  side: const BorderSide(color: _kInputBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'myRekod · v${HelpSupportConfig.appVersionLabel}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: _kVersion,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "We're here to help",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  adminView
                      ? 'Answers for admins. Contact HR or IT if you need account or system help.'
                      : 'Find answers below, or call HR / IT from Contact. If something looks wrong, copy diagnostics and share them with support.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: _kHeroBody,
                  ),
                ),
              ],
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _kBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: _kMuted,
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
