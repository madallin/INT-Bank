import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/haptic_feedback_helper.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_tokens.dart';
import '../accounts/screens/accounts_screen.dart';
import '../home/screens/home_screen.dart';
import '../payments/screens/payments_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../vaults/screens/vaults_screen.dart';

enum AppTab { home, accounts, payments, savings, profile }

/// The signed-in app: five tabs behind a bottom navigation bar. A tab is built the first
/// time it is opened and then kept, so switching back keeps its scroll position.
class AppShell extends StatefulWidget
{
  const AppShell({super.key, required this.userId, this.initialTab = AppTab.home});

  final int userId;
  final AppTab initialTab;

  /// Switches tab from inside one (e.g. Home's savings banner). Returns false outside the shell.
  static bool selectTab(BuildContext context, AppTab tab)
  {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    shell?._select(tab);
    return shell != null;
  }

  /// The selected tab, for a tab screen that refreshes when it is shown again. Null outside the shell.
  static ValueListenable<AppTab>? currentTabOf(BuildContext context) =>
      context.findAncestorStateOfType<_AppShellState>()?._current;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// For a tab's screen: [onTabShown] runs each time the customer comes back to [tab], so
/// balances changed on another tab are not left stale.
mixin ReloadWhenTabShown<T extends StatefulWidget> on State<T>
{
  AppTab get tab;
  void onTabShown();

  ValueListenable<AppTab>? _currentTab;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    final current = AppShell.currentTabOf(context);
    if(current == _currentTab) return;
    _currentTab?.removeListener(_check);
    _currentTab = current?..addListener(_check);
  }

  void _check()
  {
    if(_currentTab?.value == tab && mounted) onTabShown();
  }

  @override
  void dispose()
  {
    _currentTab?.removeListener(_check);
    super.dispose();
  }
}

class _AppShellState extends State<AppShell>
{
  late final ValueNotifier<AppTab> _current = ValueNotifier(widget.initialTab);
  late final Set<AppTab> _opened = {widget.initialTab};

  AppTab get _tab => _current.value;

  void _select(AppTab tab)
  {
    if(tab == _tab) return;
    HapticFeedbackHelper.selection();
    setState(() => _opened.add(tab));
    _current.value = tab;
  }

  @override
  void dispose()
  {
    _current.dispose();
    super.dispose();
  }

  Widget _build(AppTab tab) => switch(tab)
  {
    AppTab.home => HomeScreen(userId: widget.userId),
    AppTab.accounts => AccountsScreen(userId: widget.userId),
    AppTab.payments => PaymentsScreen(userId: widget.userId),
    AppTab.savings => VaultsScreen(userId: widget.userId),
    AppTab.profile => ProfileScreen(userId: widget.userId),
  };

  @override
  Widget build(BuildContext context)
  {
    final l10n = context.l10n;
    final destinations = {
      AppTab.home: (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      AppTab.accounts: (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, l10n.navAccounts),
      AppTab.payments: (Icons.swap_horiz_rounded, Icons.swap_horiz_rounded, l10n.navPayments),
      AppTab.savings: (Icons.savings_outlined, Icons.savings_rounded, l10n.navSavings),
      AppTab.profile: (Icons.person_outline_rounded, Icons.person_rounded, l10n.navProfile),
    };
    // Android back on another tab goes to Home first instead of leaving the app.
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if(!didPop) _select(AppTab.home);
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: IndexedStack(
          index: _tab.index,
          children: [
            for(final tab in AppTab.values)
              _opened.contains(tab)
                  ? HeroMode(enabled: tab == _tab, child: _build(tab))
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.border))),
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) => _select(AppTab.values[index]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for(final tab in AppTab.values)
                NavigationDestination(
                  key: ValueKey('nav-${tab.name}'),
                  icon: Icon(destinations[tab]!.$1),
                  selectedIcon: Icon(destinations[tab]!.$2),
                  label: destinations[tab]!.$3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
