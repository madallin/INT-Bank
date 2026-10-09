import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/privacy_mode_service.dart';
import '../../../core/services/push_notification_listener.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/helpers.dart';
import '../../../l10n/l10n.dart';
import '../../../services/jwt_api_service.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/error_banner.dart';
import '../../../widgets/list_section.dart';
import '../../../widgets/simple_app_bar.dart';
import '../../welcome/welcome_screen.dart';
import 'change_pin_screen.dart';

/// Profile tab: who you are, security and app preferences, and signing out.
class ProfileScreen extends StatefulWidget
{
  const ProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
{
  Map<String, dynamic>? _profile;
  String? _error;
  bool _signingOut = false;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  Future<void> _load() async
  {
    try
    {
      final response = await DioClient().get('/users/${widget.userId}');
      if(mounted) setState(() { _profile = Map<String, dynamic>.from(response.data as Map); _error = null; });
    }
    catch(e)
    {
      if(mounted) setState(() => _error = friendlyErrorMessage(e, fallback: context.l10n.profileLoadError));
    }
  }

  Future<void> _confirmSignOut() async
  {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.homeDeconectezi,
      message: l10n.homeVaTrebuiSaAutentifici,
      confirmLabel: l10n.homeDeconecteazaMa,
      destructive: true,
    );
    if(confirmed) await _signOut();
  }

  /// Ends the session on the server and forgets it on this phone.
  Future<void> _signOut() async
  {
    setState(() => _signingOut = true);
    PushNotificationListener().stop();
    await JwtApiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedUserId');
    if(!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<T?> _choose<T>({required String title, required T current, required List<(T, String)> options})
  {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
              child: Semantics(header: true, child: Text(title, style: sheet.text.titleMedium)),
            ),
            for(final (value, label) in options)
              Semantics(
                selected: value == current,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  title: Text(label),
                  trailing: value == current ? Icon(Icons.check_rounded, color: sheet.colors.brand) : null,
                  onTap: () => Navigator.of(sheet).pop(value),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch(mode)
  {
    ThemeMode.light => context.l10n.settingsThemeLight,
    ThemeMode.dark => context.l10n.settingsThemeDark,
    ThemeMode.system => context.l10n.settingsThemeSystem,
  };

  /// Language names are written in their own language.
  String _languageLabel(Locale? locale) => switch(locale?.languageCode)
  {
    'ro' => 'Română',
    'en' => 'English',
    _ => context.l10n.settingsLanguageSystem,
  };

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final l10n = context.l10n;
    final settings = AppSettings.instance;
    return Scaffold(
      backgroundColor: c.background,
      appBar: SimpleAppBar(title: l10n.profileTitle),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if(_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              _ProfileHeader(profile: _profile),
              if(_profile != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _PersonalDetails(profile: _profile!),
              ],
              const SizedBox(height: AppSpacing.lg),
              ListSection(
                title: l10n.settingsSecurity,
                children: [
                  ListRow(
                    icon: Icons.pin_outlined,
                    title: l10n.settingsChangePin,
                    subtitle: l10n.settingsChangePinBody,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChangePinScreen(userId: widget.userId),
                    )),
                  ),
                  ListRow(
                    icon: Icons.lock_clock_outlined,
                    title: l10n.settingsAutoLock,
                    subtitle: l10n.settingsAutoLockMinutes(settings.autoLockMinutes),
                    onTap: () async {
                      final minutes = await _choose<int>(
                        title: l10n.settingsAutoLock,
                        current: settings.autoLockMinutes,
                        options: [for(final m in AppSettings.autoLockChoices) (m, l10n.settingsAutoLockMinutes(m))],
                      );
                      if(minutes != null) await settings.setAutoLockMinutes(minutes);
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: PrivacyModeService().isPrivacyModeEnabled,
                    builder: (context, hidden, _) => MergeSemantics(
                      child: ListRow(
                        icon: Icons.visibility_off_outlined,
                        title: l10n.settingsHideAmounts,
                        subtitle: l10n.settingsHideAmountsBody,
                        onTap: () => PrivacyModeService().setPrivacyMode(!hidden),
                        trailing: Switch(
                          value: hidden,
                          onChanged: (value) => PrivacyModeService().setPrivacyMode(value),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ListSection(
                title: l10n.settingsPreferences,
                children: [
                  ListRow(
                    icon: Icons.contrast_rounded,
                    title: l10n.settingsAppearance,
                    subtitle: _themeLabel(settings.themeMode),
                    onTap: () async {
                      final mode = await _choose<ThemeMode>(
                        title: l10n.settingsAppearance,
                        current: settings.themeMode,
                        options: [for(final m in [ThemeMode.system, ThemeMode.light, ThemeMode.dark]) (m, _themeLabel(m))],
                      );
                      if(mode != null) await settings.setThemeMode(mode);
                    },
                  ),
                  ListRow(
                    icon: Icons.translate_rounded,
                    title: l10n.settingsLanguage,
                    subtitle: _languageLabel(settings.locale),
                    onTap: () async {
                      // '' stands for "phone language" (a sheet result of null means dismissed).
                      final code = await _choose<String>(
                        title: l10n.settingsLanguage,
                        current: settings.locale?.languageCode ?? '',
                        options: [('', _languageLabel(null)), ('ro', 'Română'), ('en', 'English')],
                      );
                      if(code != null) await settings.setLocale(code.isEmpty ? null : Locale(code));
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ListSection(
                title: l10n.settingsAbout,
                children: [
                  ListRow(
                    icon: Icons.info_outline_rounded,
                    title: l10n.settingsVersion,
                    trailing: Text(AppConfig.appVersion, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                  ),
                  ListRow(
                    icon: Icons.article_outlined,
                    title: l10n.settingsLicences,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'INTBank',
                      applicationVersion: AppConfig.appVersion,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: l10n.homeDeconectare,
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.danger,
                isLoading: _signingOut,
                onPressed: _signingOut ? null : _confirmSignOut,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget
{
  const _ProfileHeader({required this.profile});

  final Map<String, dynamic>? profile;

  String get _name
  {
    final p = profile;
    if(p == null) return '';
    return toTitleCase('${p['prenume'] ?? ''} ${p['nume'] ?? ''}'.trim());
  }

  String get _initials
  {
    final parts = _name.split(' ').where((w) => w.isNotEmpty).toList();
    if(parts.isEmpty) return '';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    final phone = profile?['nrTelefon']?.toString();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: c.brandSurface,
              child: _initials.isEmpty
                  ? Icon(Icons.person_rounded, color: c.brand, size: 30)
                  : Text(_initials, style: context.text.titleMedium?.copyWith(color: c.brand)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isEmpty ? context.l10n.homeClientIntbank : _name,
                  style: context.text.titleMedium,
                ),
                if(phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(formatPhoneDisplay(phone), style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalDetails extends StatelessWidget
{
  const _PersonalDetails({required this.profile});

  final Map<String, dynamic> profile;

  String? _text(String key)
  {
    final value = profile[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context)
  {
    final l10n = context.l10n;
    final address = [_text('adresa'), _text('localitate'), _text('judet')].whereType<String>().join(', ');
    final birth = DateTime.tryParse(_text('dataNasterii') ?? '');
    final rows = [
      if(_text('email') != null) (Icons.mail_outline_rounded, l10n.profileEmail, _text('email')!),
      if(address.isNotEmpty) (Icons.home_outlined, l10n.profileAddress, address),
      if(birth != null) (Icons.cake_outlined, l10n.profileBirthDate, formatDate(birth)),
    ];
    if(rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListSection(
          title: l10n.profilePersonalDetails,
          children: [
            for(final (icon, label, value) in rows)
              MergeSemantics(child: ListRow(icon: icon, title: label, subtitle: value)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Text(
            l10n.profileDetailsNote,
            style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
