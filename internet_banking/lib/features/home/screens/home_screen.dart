import '../../../theme/app_tokens.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/helpers.dart';
import '../../../data/models/transaction_entry.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/card_model.dart';
import '../../../services/currency_service.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/transaction_list_item.dart';
import '../../transfer/screens/transfer_screen.dart';
import '../../transactions/screens/transaction_history_screen.dart';
import '../../exchange/screens/exchange_screen.dart';
import '../../shell/app_shell.dart';
import '../../statement/screens/statement_screen.dart';
import '../../cards/screens/card_settings_screen.dart';
import '../../vaults/screens/vaults_screen.dart';
import '../../transactions/widgets/transaction_details_bottom_sheet.dart';
import '../widgets/account_details_bottom_sheet.dart';
import '../../notifications/widgets/notification_center_bottom_sheet.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/push_notification_listener.dart';
import '../widgets/open_currency_account_dialog.dart';
import '../../analytics/screens/spending_analytics_screen.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/services/privacy_mode_service.dart';
import '../widgets/home_action_buttons.dart';
import '../widgets/home_card.dart';
import '../widgets/home_exchange_preview.dart';
import '../widgets/home_vaults_banner.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/app_log.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  /// Card details stay visible this long, then the card turns back by itself.
  static const cardRevealDuration = Duration(seconds: 60);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, ReloadWhenTabShown {
  @override
  AppTab get tab => AppTab.home;

  @override
  void onTabShown() {
    _fetchCardsAndAccounts();
    _fetchUnreadNotifications();
  }

  final DioClient _client = DioClient();
  final List<CardModel> _cardList = [];
  CardModel? _selectedCard;
  int _currentCardIndex = 0;
  int? _currentAccountId;

  double _balance = 0.0;
  int? _balanceAccountId;
  bool _loading = true;
  bool _loadingBalance = true;

  late AnimationController _flipController;
  bool _cardShowingBack = false;
  Timer? _cardRevealTimer;

  late AnimationController _pageController;
  late Animation<Offset> _pageAnimation;


  Timer? _refreshTimer;

  List<Map<String, dynamic>> _recentTransactions = [];
  int? _transactionsAccountId;
  bool _loadingTransactions = false;
  int _unreadNotifications = 0;
  String? _currentIban;
  String _currentCurrency = 'RON';
  String? _firstName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pageController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _pageAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _pageController, curve: Curves.easeOut));
    _pageController.forward();

    PrivacyModeService().init();
    PrivacyModeService().isPrivacyModeEnabled.addListener(_onPrivacyChanged);
    _initialize();
    _startPeriodicRefresh();
  }

  void _onPrivacyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _initPushNotifications();
    _fetchFirstName();
    await _fetchCardsAndAccounts();
    await _fetchUnreadNotifications();
    await CurrencyService.instance.fetchRates();
    if (mounted) setState(() {});
  }

  Future<void> _initPushNotifications() async {
    try {
      await PushNotificationService().init(
        onNotificationClick: (payload) {
          NotificationCenterBottomSheet.show(context, userId: widget.userId);
          _fetchUnreadNotifications();
        },
      );
      await PushNotificationService().requestPermissions();

      PushNotificationListener().start(
        widget.userId,
        onNotificationReceived: () {
          if (mounted) {
            _fetchUnreadNotifications();
            _fetchBalance();
            _fetchRecentTransactions();
          }
        },
      );
    } catch (e) {
      AppLog.debug('Error initializing push notifications', e);
    }
  }

  /// Only used for the greeting; Home works without it.
  Future<void> _fetchFirstName() async {
    try {
      final response = await _client.get('/users/${widget.userId}');
      final name = (response.data as Map<String, dynamic>)['prenume']?.toString().trim();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _firstName = toTitleCase(name.split(RegExp(r'\s+')).first));
      }
    } catch (_) {}
  }

  String _greeting() {
    final l10n = context.l10n;
    final hour = DateTime.now().hour;
    final hello = hour < 5 || hour >= 18
        ? l10n.homeGreetEvening
        : hour < 12
            ? l10n.homeGreetMorning
            : l10n.homeGreetAfternoon;
    return _firstName == null ? l10n.homeBunVenit : '$hello, $_firstName';
  }

  Future<void> _fetchCardsAndAccounts() async {
    try {
      final response = await _client.get(
        '/users/${widget.userId}/cards',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['cards'] != null) {
          final cards = List<Map<String, dynamic>>.from(data['cards']);
          setState(() {
            _cardList.clear();
            for (final card in cards) {
              _cardList.add(CardModel.fromJson(card));
            }
            if (_cardList.isNotEmpty) {
              _selectedCard = _cardList[_currentCardIndex];
              _currentAccountId = _selectedCard!.accountId;
            }
          });
        }
      }
    } catch (e) {
      AppLog.debug('Error fetching cards', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (_selectedCard != null) {
      await _fetchBalance();
      await _fetchRecentTransactions();
    }
  }

  Future<void> _fetchBalance() async {
    int? accountId = _currentAccountId;
    if (_balanceAccountId == null || _balanceAccountId != accountId) {
      setState(() => _loadingBalance = true);
    }

    if (accountId == null) {
      try {
        final resp = await _client.get(
          '/users/${widget.userId}/cards',
          );

        if (resp.statusCode == 200) {
          final data = resp.data as Map<String, dynamic>;
          final cards = data['cards'] as List?;
          if (cards != null && cards.isNotEmpty) {
            accountId =
                (cards.first as Map<String, dynamic>)['accountId'] as int?;
          }
        }
      } catch (_) {}
      if (accountId == null) {
        setState(() => _loadingBalance = false);
        return;
      }
    }

    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/$accountId',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['account'] != null && mounted) {
          final account = data['account'] as Map<String, dynamic>;
          final sold = account['sold'];
          setState(() {
            if (account['iban'] != null) {
              _currentIban = account['iban'].toString();
            }
            if (account['moneda'] != null) {
              _currentCurrency = account['moneda'].toString();
            }
            if (sold != null) {
              _balance = sold is String
                  ? double.parse(sold)
                  : (sold as num).toDouble();
            }
            _balanceAccountId = accountId;
          });
        }
      }
    } catch (e) {
      AppLog.debug('Error fetching balance', e);
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _fetchRecentTransactions() async {
    if (_currentAccountId == null) return;
    final accountId = _currentAccountId;
    if (_transactionsAccountId != accountId) {
      setState(() => _loadingTransactions = true);
    }
    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/$_currentAccountId/transactions',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['transactions'] != null) {
          final all =
              List<Map<String, dynamic>>.from(data['transactions']);
          if (mounted && accountId == _currentAccountId) {
            setState(() {
              _recentTransactions = all.take(3).toList();
              _transactionsAccountId = accountId;
            });
          }
        }
      }
    } catch (e) {
      AppLog.debug('Error fetching recent transactions', e);
    } finally {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchCardsAndAccounts();
        _fetchUnreadNotifications();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PrivacyModeService().isPrivacyModeEnabled.removeListener(_onPrivacyChanged);
    PushNotificationListener().stop();
    _flipController.dispose();
    _pageController.dispose();
    _refreshTimer?.cancel();
    _cardRevealTimer?.cancel();
    super.dispose();
  }

  void _nextCard() {
    if (_currentCardIndex < _cardList.length - 1) {
      _cancelCardReveal();
      setState(() {
        _currentCardIndex++;
        _selectedCard = _cardList[_currentCardIndex];
        _currentAccountId = _selectedCard!.accountId;
        _currentIban = null;
      });
      _fetchBalance();
      _fetchRecentTransactions();
    }
  }

  void _prevCard() {
    if (_currentCardIndex > 0) {
      _cancelCardReveal();
      setState(() {
        _currentCardIndex--;
        _selectedCard = _cardList[_currentCardIndex];
        _currentAccountId = _selectedCard!.accountId;
        _currentIban = null;
      });
      _fetchBalance();
      _fetchRecentTransactions();
    }
  }

  void _cancelCardReveal() {
    _cardRevealTimer?.cancel();
    setState(() => _cardShowingBack = false);
    _flipController.value = 0;
  }

  Future<void> _onToggleCardReveal() async {
    if (_flipController.isAnimating) return;
    if (_cardShowingBack) {
      _cardRevealTimer?.cancel();
      setState(() => _cardShowingBack = false);
      await _flipController.animateTo(0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
    } else {
      if (_selectedCard == null) return;
      setState(() => _cardShowingBack = true);
      await _flipController.animateTo(1,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
      _startRevealTimer();
    }
  }

  // One timer for the whole reveal: nothing on screen counts down, so there is no
  // reason to rebuild Home every second while the details are shown.
  void _startRevealTimer() {
    _cardRevealTimer?.cancel();
    _cardRevealTimer = Timer(HomeScreen.cardRevealDuration, () {
      if (!mounted) return;
      setState(() => _cardShowingBack = false);
      _flipController.animateTo(0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
    });
  }

  void _toggleBalance() {
    HapticFeedbackHelper.selection();
    PrivacyModeService().togglePrivacyMode();
  }

  void _showAccountDataLoading() {
    showInfoSnackBar(context, context.l10n.homeSeIncarcaDateleContului);
  }

  void _goToTransfer() {
    if (_selectedCard == null) return;
    if (_currentIban == null) {
      _showAccountDataLoading();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TransferScreen(
                userId: widget.userId,
                userIban: _currentIban ?? '',
                currency: _currentCurrency,
                availableBalance: !_loadingBalance &&
                        _balanceAccountId == _currentAccountId
                    ? _balance
                    : null,
              )),
    ).then((_) {
      _fetchCardsAndAccounts();
      _fetchUnreadNotifications();
    });
  }

  void _goToHistory() {
    if (_currentAccountId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(
          userId: widget.userId,
          accountId: _currentAccountId!,
          currency: _currentCurrency,
        ),
      ),
    ).then((_) => _fetchRecentTransactions());
  }

  void _goToExchange() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ExchangeScreen(userId: widget.userId)),
    );
  }

  void _goToVaults() {
    if (AppShell.selectTab(context, AppTab.savings)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaultsScreen(userId: widget.userId),
      ),
    );
  }

  void _goToStatement() {
    if (_currentAccountId == null || _currentIban == null) {
      _showAccountDataLoading();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatementScreen(
          userId: widget.userId,
          accountId: _currentAccountId!,
          iban: _currentIban!,
          currency: _currentCurrency,
        ),
      ),
    );
  }

  void _goToCardSettings() {
    if (_selectedCard == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardSettingsScreen(
          userId: widget.userId,
          card: _selectedCard!,
        ),
      ),
    ).then((_) => _fetchCardsAndAccounts());
  }

  void _showAccountDetails() {
    if (_currentIban == null) {
      _showAccountDataLoading();
      return;
    }
    AccountDetailsBottomSheet.show(
      context,
      iban: _currentIban!,
      currency: _currentCurrency,
      balance: _balance,
      holderName: _selectedCard?.cardHolder ?? context.l10n.homeClientIntbank,
    );
  }

  void _goToAnalytics() {
    if (_currentAccountId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpendingAnalyticsScreen(
          userId: widget.userId,
          accountId: _currentAccountId!,
          currency: _currentCurrency,
        ),
      ),
    );
  }

  void _openCurrencyDialog() {
    OpenCurrencyAccountDialog.show(
      context,
      userId: widget.userId,
      onAccountCreated: () {
        _fetchCardsAndAccounts();
        _fetchUnreadNotifications();
      },
    );
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final resp = await _client.get('/users/${widget.userId}/notifications');
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _unreadNotifications = data['unreadCount'] as int? ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  String _txAmount(TransactionEntry entry) {
    final currency = entry.currency ?? _currentCurrency;
    if (PrivacyModeService().isPrivacyModeEnabled.value) {
      return maskedMoney(currency);
    }
    return formatMoney(entry.signedAmount, currency, showSign: true);
  }

  // ───────────────────── Build ─────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: _loading
            ? const HomeScreenSkeleton()
            : SlideTransition(
                position: _pageAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _fetchCardsAndAccounts();
                    await CurrencyService.instance.fetchRates();
                    if (mounted) setState(() {});
                  },
                  color: context.colors.brand,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildCardSection(),
                        const SizedBox(height: 20),
                        _buildBalanceRow(),
                        const SizedBox(height: 24),
                        HomeActionButtons(onTransfer: _goToTransfer, onHistory: _goToHistory, onExchange: _goToExchange, onAnalytics: _goToAnalytics),
                        const SizedBox(height: 20),
                        HomeVaultsBanner(onTap: _goToVaults),
                        const SizedBox(height: 20),
                        const HomeExchangePreview(),
                        const SizedBox(height: 20),
                        _buildRecentTransactions(),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.brand.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.account_balance_rounded,
                color: context.colors.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INTBank',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.3)),
                Text(_greeting(),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textMuted,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyModeService().isPrivacyModeEnabled,
            builder: (context, isPrivacy, _) => _HeaderIconButton(
              icon: isPrivacy ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              tooltip: isPrivacy ? context.l10n.homeArataSumele : context.l10n.homeAscundeSumele,
              active: isPrivacy,
              onTap: () {
                HapticFeedbackHelper.selection();
                PrivacyModeService().togglePrivacyMode();
              },
            ),
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.notifications_outlined,
            tooltip: context.l10n.homeNotificari,
            badgeCount: _unreadNotifications,
            onTap: () async {
              HapticFeedbackHelper.buttonTap();
              await NotificationCenterBottomSheet.show(context, userId: widget.userId);
              _fetchUnreadNotifications();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    if (_cardList.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: EmptyStatePlaceholder(
            icon: Icons.credit_card_off_outlined,
            title: context.l10n.homeCarduriDisponibile,
          ),
        ),
      );
    }

    final hasPrev = _currentCardIndex > 0;
    final hasNext = _currentCardIndex < _cardList.length - 1;
    return Column(
      children: [
        Semantics(
          label: context.l10n.homeCard(_currentCardIndex + 1, _cardList.length),
          onIncrease: hasNext ? _nextCard : null,
          onDecrease: hasPrev ? _prevCard : null,
          child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -250 && hasNext) {
              HapticFeedbackHelper.selection();
              _nextCard();
            } else if (velocity > 250 && hasPrev) {
              HapticFeedbackHelper.selection();
              _prevCard();
            }
          },
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedBuilder(
            animation: _flipController,
            builder: (context, _) {
              final angle = _flipController.value * math.pi;
              final showBack = _flipController.value > 0.5;

              final Widget face = showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: HomeCardBack(card: _selectedCard!, onToggleReveal: _onToggleCardReveal),
                    )
                  : HomeCardFront(card: _selectedCard!, onToggleReveal: _onToggleCardReveal, onOpenSettings: _goToCardSettings);

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(angle),
                child: face,
              );
            },
          ),
          ),
          ),
        ),
        if (_cardList.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: hasPrev ? _prevCard : null,
                tooltip: context.l10n.homeCardulAnterior,
                icon: Icon(Icons.chevron_left_rounded,
                    size: 26,
                    color: hasPrev
                        ? context.colors.brand
                        : context.colors.border),
              ),
              ...List.generate(_cardList.length, (i) {
                return ExcludeSemantics(child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentCardIndex ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _currentCardIndex
                        ? context.colors.brand
                        : context.colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ));
              }),
              IconButton(
                onPressed: hasNext ? _nextCard : null,
                tooltip: context.l10n.homeCardulUrmator,
                icon: Icon(Icons.chevron_right_rounded,
                    size: 26,
                    color: hasNext
                        ? context.colors.brand
                        : context.colors.border),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBalanceRow() {
    final hidden = PrivacyModeService().isPrivacyModeEnabled.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.commonSoldDisponibil,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            _loadingBalance
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(),
                    ),
                  )
                : Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hidden
                                ? maskedMoney(_currentCurrency)
                                : formatMoney(_balance, _currentCurrency),
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                                letterSpacing: -0.5),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleBalance,
                        tooltip: hidden ? context.l10n.homeArataSoldul : context.l10n.homeAscundeSoldul,
                        icon: Icon(
                          hidden
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBalanceAction(
                    Icons.add_rounded, context.l10n.homeValuta, _openCurrencyDialog),
                _buildBalanceAction(
                    Icons.description_outlined, context.l10n.homeExtras, _goToStatement),
                _buildBalanceAction(Icons.info_outline_rounded, context.l10n.homeDetaliiCont,
                    _showAccountDetails),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceAction(
      IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: context.colors.brand.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: context.colors.brand),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.brand)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.homeTranzactiiRecente,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary)),
              if (_currentAccountId != null)
                TextButton(
                  onPressed: _goToHistory,
                  child: Text(context.l10n.homeVeziToate,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color:
                              context.colors.brand,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingTransactions)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_recentTransactions.isEmpty)
            EmptyStatePlaceholder(
              icon: Icons.receipt_long_outlined,
              title: context.l10n.homeExistaTranzactiiRecente,
            )
          else
            ...(_recentTransactions.asMap().entries.map((entry) {
              final tx = entry.value;
              final parsed = TransactionEntry.fromJson(tx);
              return Padding(
                padding: EdgeInsets.only(
                    bottom: entry.key <
                            _recentTransactions.length - 1
                        ? 10
                        : 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => TransactionDetailsBottomSheet.show(context, tx),
                  child: TransactionListItem(
                    beneficiary: parsed.title,
                    date: parsed.date == null ? '' : formatDate(parsed.date!),
                    amount: _txAmount(parsed),
                    isPositive: parsed.isIncoming,
                    category: parsed.category,
                  ),
                ),
              );
            })),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: badgeCount > 0 ? context.l10n.homeNecitite(tooltip, badgeCount) : tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: active ? c.brand.withValues(alpha: 0.15) : c.surfaceMuted,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: kMinTapTarget,
                  height: kMinTapTarget,
                  child: Icon(icon, size: 20, color: active ? c.brand : c.textSecondary),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: TextStyle(color: c.onDanger, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
