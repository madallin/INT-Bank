import '../../widgets/app_logo.dart';
import '../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/app_button.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/register_screen.dart';
import '../../l10n/l10n.dart';

class WelcomeScreen extends StatefulWidget
{
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
{
  bool _loading = false;

  Future<void> conecteazaClient(BuildContext context) async
  {
    setState(() => _loading = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if(mounted) setState(() => _loading = false);
  }

  Future<void> inregistreazaClient(BuildContext context) async
  {
    setState(() => _loading = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if(mounted) setState(() => _loading = false);
  }

  Widget _buildContent(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const Spacer(),
          const AppLogo(height: 120),
          const SizedBox(height: 32),
          const Spacer(flex: 2),
          Text(
            context.l10n.welcomeSalutBineVenitInt,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 300,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.brand,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: context.colors.textSecondary,
                  height: 1.3,
                ),
                children: [
                  TextSpan(text: context.l10n.welcomeEstiDejaClient),
                  TextSpan(
                    text: 'INT Bank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.brand,
                    ),
                  ),
                  TextSpan(text: context.l10n.welcomeContinua),
                  TextSpan(
                    text: context.l10n.welcomeConecteaza,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.brand,
                    ),
                  ),
                  TextSpan(text: context.l10n.welcomeDacaCont),
                  TextSpan(
                    text: context.l10n.welcomePotiDeveniClientDirect,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.brand,
                    ),
                  ),
                  TextSpan(text: context.l10n.welcomeEste),
                  TextSpan(
                    text: context.l10n.welcomeRapidSigur,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.brand,
                    ),
                  ),
                  TextSpan(
                    text:
                        context.l10n.welcomeIarTuVeiAvea,
                  ),
                  TextSpan(
                    text: context.l10n.welcomeInstantDistanta,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.brand,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const Spacer(flex: 3),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AppButton(
                    label: context.l10n.welcomeInregistreaza,
                    onPressed: _loading ? null : () => inregistreazaClient(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : () => conecteazaClient(context),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.colors.brand,
                      letterSpacing: 0.1,
                    ),
                    children: [
                      TextSpan(text: context.l10n.welcomeDejaCont),
                      TextSpan(
                        text: context.l10n.welcomeConecteaza,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: context.colors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: _buildContent(context)),
            ),
          ),
        ),
      ),
    );
  }
}
