import '../../../widgets/confirm_dialog.dart';
import '../../../theme/app_tokens.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';

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
import '../../welcome/welcome_screen.dart';
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
import '../../../l10n/l10n.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  int _revealCountdown = 60;

  late AnimationController _pageController;
  late Animation<Offset> _pageAnimation;

  String? clientToken;
  String? refreshToken;
  String _deviceId = 'dev-device';

  Timer? _refreshTimer;

  List<Map<String, dynamic>> _recentTransactions = [];
  int? _transactionsAccountId;
  bool _loadingTransactions = false;
  int _unreadNotifications = 0;
  String? _currentIban;
  String _currentCurrency = 'RON';

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
    await _initDeviceId();
    await _initPushNotifications();
    await _getClientToken();
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
      debugPrint('Error initializing push notifications: $e');
    }
  }

  Future<void> _initDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'dev-device';
      }
    } catch (_) {
      _deviceId = 'dev-device';
    }
  }

  Future<void> _getClientToken() async {
    try {
      final response = await _client.post(
        '/auth/get-client-token',
        data: {'deviceId': _deviceId},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
      }
    } catch (e) {
      debugPrint('Error getting client token: $e');
    }
  }

  Future<bool> _refreshClientToken() async {
    if (refreshToken == null) return false;
    try {
      final response = await _client.post(
        '/auth/refresh-client-token',
        data: {'deviceId': _deviceId, 'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (mounted) setState(() => clientToken = data['client_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Options _authOptions() {
    return Options(
      headers: clientToken != null
          ? {'Authorization': 'Bearer $clientToken'}
          : null,
    );
  }

  Future<void> _fetchCardsAndAccounts() async {
    try {
      final response = await _client.get(
        '/users/${widget.userId}/cards',
        options: _authOptions(),
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
      } else if (response.statusCode == 401) {
        final refreshed = await _refreshClientToken();
        if (refreshed) await _fetchCardsAndAccounts();
      }
    } catch (e) {
      debugPrint('Error fetching cards: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (_selectedCard != null) {
      await _fetchBalance();
      await _fetchRecentTransactions();
    }
  }

  Future<void> _fetchBalance() async {
    if (clientToken == null) {
      setState(() => _loadingBalance = false);
      return;
    }

    int? accountId = _currentAccountId;
    if (_balanceAccountId == null || _balanceAccountId != accountId) {
      setState(() => _loadingBalance = true);
    }

    if (accountId == null) {
      try {
        final resp = await _client.get(
          '/users/${widget.userId}/cards',
          options: _authOptions(),
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
        options: _authOptions(),
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
      } else if (response.statusCode == 401) {
        final refreshed = await _refreshClientToken();
        if (refreshed) await _fetchBalance();
      }
    } catch (e) {
      debugPrint('Error fetching balance: $e');
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _fetchRecentTransactions() async {
    if (_currentAccountId == null || clientToken == null) return;
    final accountId = _currentAccountId;
    if (_transactionsAccountId != accountId) {
      setState(() => _loadingTransactions = true);
    }
    try {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/$_currentAccountId/transactions',
        options: _authOptions(),
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
      debugPrint('Error fetching recent transactions: $e');
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
    setState(() {
      _revealCountdown = 60;
      _cardShowingBack = false;
    });
    _flipController.value = 0;
  }

  Future<void> _onToggleCardReveal() async {
    if (_flipController.isAnimating) return;
    if (_cardShowingBack) {
      _cardRevealTimer?.cancel();
      setState(() {
        _revealCountdown = 60;
        _cardShowingBack = false;
      });
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

  void _startRevealTimer() {
    _cardRevealTimer?.cancel();
    setState(() => _revealCountdown = 60);
    _cardRevealTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _revealCountdown--;
        if (_revealCountdown <= 0) {
          timer.cancel();
          _revealCountdown = 60;
          _cardShowingBack = false;
          _flipController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }
      });
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

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.homeDeconectezi,
      message: context.l10n.homeVaTrebuiSaAutentifici,
      confirmLabel: context.l10n.homeDeconecteazaMa,
    );
    if (confirmed) _logout();
  }

  Future<void> _logout() async {
    PushNotificationListener().stop();
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'loggedUserIdKey');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
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
                        _buildActionButtons(),
                        const SizedBox(height: 20),
                        _buildVaultsBanner(),
                        const SizedBox(height: 20),
                        _buildExchangePreview(),
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
              color: context.colors.brand.withOpacity(0.12),
            ),
            child: Icon(Icons.account_balance_rounded,
                color: context.colors.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INT Bank',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.3)),
                Text(context.l10n.homeBunVenit,
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
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.logout_rounded,
            tooltip: context.l10n.homeDeconectare,
            onTap: _confirmLogout,
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
                      child: _buildCardBack(),
                    )
                  : _buildCardFront();

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

  Widget _buildCardFront() {
    if (_selectedCard == null) return const SizedBox();
    return Container(
      key: const ValueKey('front'),
      width: double.infinity,
      // Grows with large text instead of clipping; 200 at normal size.
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.cardGradientStart, context.colors.cardGradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.5),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: -18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            // Vertical padding leaves room for the 48dp settings target.
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('INT Bank',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3)),
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: context.l10n.homeSetariCard,
                          excludeSemantics: true,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _goToCardSettings,
                          child: Container(
                            width: kMinTapTarget,
                            height: kMinTapTarget,
                            alignment: Alignment.center,
                            child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                          ),
                          ),
                        ),
                        ),
                        const SizedBox(width: 8),
                        Image.asset('assets/images/visa.png', height: 22),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: 38,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1),
                  ),
                  child: const Icon(Icons.memory_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  '**** **** **** ${_selectedCard!.last4}',
                  style: GoogleFonts.spaceMono(
                      fontSize: 15,
                      color: Colors.white,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.homeTitular,
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 3),
                        Text(
                            _selectedCard!.detinator.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.l10n.homeExpira,
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 3),
                        Text(_selectedCard!.expiry,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    if (_selectedCard == null) return const SizedBox();
    final pan = _selectedCard!.fullNumber;
    final cvv = _selectedCard!.cvv;
    final expiry = _selectedCard!.expiry;

    return Container(
      key: const ValueKey('back'),
      width: double.infinity,
      // Grows with large text instead of clipping; 200 at normal size.
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [context.colors.cardGradientEnd, context.colors.cardGradientStart],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.5),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            margin: const EdgeInsets.only(top: 24),
            color: Colors.black54,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(context.l10n.homePan,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white,
                            letterSpacing: 1.5)),
                    Text(
                      groupInFours(pan),
                      style: GoogleFonts.spaceMono(
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(5),
                                    bottomLeft: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              child: Text(
                                cvv,
                                style: GoogleFonts.spaceMono(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.homeCvv,
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(cvv,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.homeExp(expiry),
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                    Semantics(
                      button: true,
                      label: context.l10n.homeAscundeDateleCardului,
                      excludeSemantics: true,
                      child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onToggleCardReveal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 12,
                                color: Colors.white),
                            const SizedBox(width: 4),
                            Text(context.l10n.homeAscunde,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
              color: Colors.black.withOpacity(0.04),
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
      color: context.colors.brand.withOpacity(0.08),
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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
              child: _buildActionCard(
                  Icons.send_rounded, context.l10n.commonTransfer, _goToTransfer)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildActionCard(Icons.receipt_long_rounded,
                  context.l10n.homeIstoric, _goToHistory)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildActionCard(Icons.currency_exchange_rounded,
                  context.l10n.homeSchimb, _goToExchange)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildActionCard(Icons.pie_chart_outline_rounded,
                  context.l10n.homeStatistici, _goToAnalytics)),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
      onTap: () {
        HapticFeedbackHelper.buttonTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.brand
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: context.colors.brand,
                  size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary)),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildVaultsBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Semantics(
        button: true,
        container: true,
        child: GestureDetector(
        onTap: () {
          HapticFeedbackHelper.buttonTap();
          _goToVaults();
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.colors.heroStart, context.colors.heroEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                          context.l10n.homeSeifuriRoundUp,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.brand.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.l10n.homeNou,
                            style: GoogleFonts.inter(
                              color: context.colors.brand,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.homeEconomisesteAutomatMaruntisulTranzactiilor,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildExchangePreview() {
    final rates = CurrencyService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.colors.brand.withOpacity(0.08),
              context.colors.brandStrong.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  context.colors.brand.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 18, color: context.colors.brand),
                const SizedBox(width: 8),
                Text(context.l10n.homeCursValutar,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            if (!rates.hasRates)
              Center(
                child: Text(context.l10n.homeSeIncarca,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: context.colors.textMuted)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _buildRateTile('EUR', rates.getRate('EUR', 'RON'))),
                  Expanded(child: _buildRateTile('USD', rates.getRate('USD', 'RON'))),
                  Expanded(child: _buildRateTile('GBP', rates.getRate('GBP', 'RON'))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateTile(String currency, double? rate) {
    return Column(
      children: [
        Text(currency,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          rate != null ? formatRate(rate) : '---',
          style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.colors.brand),
        ),
      ],
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
