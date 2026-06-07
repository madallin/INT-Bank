// lib/features/welcome/welcome_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_config.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;

  Future<void> conecteazaClient(BuildContext context) async {
    setState(() => _loading = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> inregistreazaClient(BuildContext context) async {
    setState(() => _loading = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if (mounted) setState(() => _loading = false);
  }

  Widget _buildRegisterButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(lightForestGreenColor),
              const Color(lightForestGreenColor).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(lightForestGreenColor).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : () => inregistreazaClient(context),
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Înregistrează-te',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Image.asset('assets/images/logo.png', height: 120, fit: BoxFit.contain),
              const SizedBox(height: 120),
              Text(
                'Salut și bine ai venit în INT Bank!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(darkGreyColor),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 300,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(lightForestGreenColor),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              const SizedBox(height: 50),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: 'Ești deja client '),
                      TextSpan(
                        text: 'INT Bank',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(lightForestGreenColor),
                        ),
                      ),
                      const TextSpan(text: '? Continuă cu '),
                      TextSpan(
                        text: 'Sunt client deja',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(lightForestGreenColor),
                        ),
                      ),
                      const TextSpan(text: '.\n\nDacă nu ai cont, '),
                      TextSpan(
                        text: 'poți deveni client direct din INT Bank',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(lightForestGreenColor),
                        ),
                      ),
                      const TextSpan(text: '.\n\nEste '),
                      TextSpan(
                        text: 'rapid și sigur',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(lightForestGreenColor),
                        ),
                      ),
                      const TextSpan(
                        text:
                            ', iar tu vei avea acces la toate funcționalitățile contului tău bancar ',
                      ),
                      TextSpan(
                        text: 'instant și de la distanță',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(lightForestGreenColor),
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
                  SizedBox(width: 310, child: _buildRegisterButton(context)),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: _loading ? null : () => conecteazaClient(context),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(lightForestGreenColor),
                          letterSpacing: 0.1,
                        ),
                        children: [
                          const TextSpan(text: 'Ai deja un cont? '),
                          TextSpan(
                            text: 'Conectează-te',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(lightForestGreenColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 52),
            ],
          ),
        ),
      ),
    );
  }
}
