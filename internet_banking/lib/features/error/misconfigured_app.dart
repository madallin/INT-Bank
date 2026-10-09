import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_logo.dart';

/// Shown instead of the app when a release build has no certificate pins: rather than
/// talking to the bank over an unpinned connection, it explains and stops.
class MisconfiguredApp extends StatelessWidget
{
  const MisconfiguredApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'INTBank',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: AppL10n.resolve,
      home: const _SetupErrorScreen(),
    );
  }
}

class _SetupErrorScreen extends StatelessWidget
{
  const _SetupErrorScreen();

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(height: 56),
                const SizedBox(height: AppSpacing.xxl),
                Icon(Icons.gpp_bad_outlined, size: 56, color: c.danger),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(context.l10n.setupErrorTitle, textAlign: TextAlign.center, style: context.text.headlineSmall),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.l10n.setupErrorBody,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
