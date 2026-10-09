import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/register_screen.dart';

/// First screen for someone who is not signed in: what INTBank offers, then open an
/// account or sign in.
class WelcomeScreen extends StatefulWidget
{
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
{
  bool _loading = false;

  Future<void> _open(Widget screen) async
  {
    setState(() => _loading = true);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if(mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    const Center(child: AppLogo(height: 72)),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.xl),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.welcomeHeadline,
                        textAlign: TextAlign.center,
                        style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _Feature(
                      icon: Icons.bolt_rounded,
                      title: l10n.welcomeFeatureTransfers,
                      body: l10n.welcomeFeatureTransfersBody,
                    ),
                    _Feature(
                      icon: Icons.savings_outlined,
                      title: l10n.welcomeFeatureSavings,
                      body: l10n.welcomeFeatureSavingsBody,
                    ),
                    _Feature(
                      icon: Icons.verified_user_outlined,
                      title: l10n.welcomeFeatureSecurity,
                      body: l10n.welcomeFeatureSecurityBody,
                    ),
                    const Spacer(flex: 2),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: l10n.welcomeOpenAccount,
                      onPressed: _loading ? null : () => _open(const RegisterScreen()),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppButton(
                      label: l10n.welcomeHaveAccount,
                      variant: AppButtonVariant.outline,
                      onPressed: _loading ? null : () => _open(const LoginScreen()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget
{
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.brandSurface, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Icon(icon, color: c.brand),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
