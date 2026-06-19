// lib/features/home/screens/home_screen.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, Platform, X509Certificate;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';
import '../../../data/models/card_model.dart';
import '../../../services/currency_service.dart';
import '../../transfer/screens/transfer_screen.dart';
import '../../transactions/screens/transaction_history_screen.dart';
import '../../exchange/screens/exchange_screen.dart';
import '../../welcome/welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Cards & Account
  final List<CardModel> _cardList = [];
  CardModel? _selectedCard;
  int _currentCardIndex = 0;
  int? _currentAccountId;

  // UI State
  double _balance = 0.0;
  bool _balanceVisible = true;
  bool _loading = true;
  bool _loadingBalance = true;
  bool _pageFlip = false;

  // Animations
  late AnimationController _balanceFadeController;
  late Animation<double> _balanceFadeAnimation;
  late AnimationController _pageController;
  late Animation<Offset> _pageAnimation;

  // Auth / Device
  String? clientToken;
  String? refreshToken;
  String _deviceId = 'dev-device';

  // SharedPreferences
  late SharedPreferences _prefs;

  // Controllere pentru refresh
  Timer? _refreshTimer;

  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initPrefs().then((_) => _initialize());

    _balanceFadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _balanceFadeAnimation = CurvedAnimation(
      parent: _balanceFadeController,
      curve: Curves.easeInOut,
    );

    _pageController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pageAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeInOut,
    ));
    _pageController.forward();

    _startPeriodicRefresh();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _initialize() async {
    await _initDeviceId();
    await _getClientToken();
    await _fetchCardsAndAccounts();

    // Fetch exchange rates in background
    CurrencyService.instance.fetchRates();
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

  http.Client _createHttpClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  Future<void> _getClientToken() async {
    try {
      final client = _createHttpClient();
      final response = await client.post(
        Uri.parse('https://$serverUrl/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId}),
      );
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
      }
    } catch (e) {
      debugPrint('Error getting client token: $e');
    }
  }

  Future<bool> _refreshClientToken() async {
    if (refreshToken == null) return false;
    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('https://$serverUrl/auth/refresh-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId, 'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() => clientToken = data['client_token']);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Future<void> _fetchCardsAndAccounts() async {
    setState(() => _loading = true);
    try {
      final client = _createHttpClient();
      final response = await client.get(
        Uri.parse('https://$serverUrl/users/${widget.userId}/cards'),
        headers: {
          'Content-Type': 'application/json',
          if (clientToken != null) 'Authorization': 'Bearer $clientToken',
        },
      );
      client.close();

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
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
    if (_selectedCard != null) await _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    setState(() => _loadingBalance = true);
    if (_currentAccountId == null || clientToken == null) {
      setState(() => _loadingBalance = false);
      return;
    }

    try {
      final client = _createHttpClient();
      final response = await client.get(
        Uri.parse('https://$serverUrl/users/${widget.userId}/accounts/$_currentAccountId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
      );
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['account'] != null && data['account']['sold'] != null) {
          setState(() => _balance = (data['account']['sold'] as num).toDouble());
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

  Future<void> _fetchCardDetails(CardModel card) async {
    if (clientToken == null) return;
    try {
      final client = _createHttpClient();
      final response = await client.get(
        Uri.parse('https://$serverUrl/users/${widget.userId}/cards/${card.id}/details'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
      );
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted && data['card'] != null) {
          setState(() {
            _selectedCard = card.copyWith(
              fullNumber: data['card']['pan'] ?? card.fullNumber,
              cvv: data['card']['cvv'] ?? card.cvv,
              expiry: data['card']['expiry'] ?? card.expiry,
            );
          });
        }
      } else if (response.statusCode == 401) {
        final refreshed = await _refreshClientToken();
        if (refreshed) await _fetchCardDetails(card);
      }
    } catch (e) {
      debugPrint('Error fetching card details: $e');
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) {
          _fetchBalance();
          _fetchCardsAndAccounts();
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _balanceFadeController.dispose();
    _pageController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ---- Card Page Handling ----
  void _nextCard() {
    if (_currentCardIndex < _cardList.length - 1) {
      setState(() {
        _currentCardIndex++;
        _selectedCard = _cardList[_currentCardIndex];
        _currentAccountId = _selectedCard!.accountId;
        _pageFlip = false;
        _pageController.reset();
        _pageController.forward();
      });
      _fetchBalance();
    }
  }

  void _prevCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _selectedCard = _cardList[_currentCardIndex];
        _currentAccountId = _selectedCard!.accountId;
        _pageFlip = false;
        _pageController.reset();
        _pageController.forward();
      });
      _fetchBalance();
    }
  }

  void _flipCard() {
    setState(() {
      _pageFlip = !_pageFlip;
      if (_pageFlip && _selectedCard != null &&
          (_selectedCard!.fullNumber == null || _selectedCard!.cvv == null)) {
        _fetchCardDetails(_selectedCard!);
      }
    });
  }

  void _toggleBalance() {
    setState(() => _balanceVisible = !_balanceVisible);
    if (_balanceVisible) _balanceFadeController.forward();
  }

  // ---- Navigation ----
  void _goToTransfer() {
    if (_selectedCard == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          userId: widget.userId,
          userIban: '',
        ),
      ),
    );
  }

  void _goToHistory() {
    if (_currentAccountId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(
          userId: widget.userId,
          accountId: _currentAccountId!,
        ),
      ),
    );
  }

  void _goToExchange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExchangeScreen(userId: widget.userId),
      ),
    );
  }

  Future<void> _logout() async {
    await _prefs.remove('loggedUserId');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // ---- Build UI ----
  String _formatBalance(double bal) {
    final parts = bal.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$intPart,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SlideTransition(
                position: _pageAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _fetchCardsAndAccounts();
                  },
                  color: const Color(lightForestGreenColor),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildCardCarousel(),
                        const SizedBox(height: 24),
                        _buildBalanceSection(),
                        const SizedBox(height: 24),
                        _buildExchangeRatesCard(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(lightForestGreenColor).withOpacity(0.1),
                ),
                child: Icon(Icons.account_balance_rounded, color: const Color(lightForestGreenColor), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'INT Bank',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(darkGreyColor),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                ),
                child: IconButton(
                  icon: Icon(Icons.logout_rounded, size: 20, color: Colors.grey[700]),
                  onPressed: _logout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardCarousel() {
    if (_cardList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nu ai carduri disponibile',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _flipCard,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 0, 0.001)
                  ..rotateY(animation.value * 3.14159),
                child: child,
              );
            },
            child: _pageFlip ? _buildCardBack() : _buildCardFront(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded, size: 28, color: _currentCardIndex > 0 ? const Color(lightForestGreenColor) : Colors.grey[300]),
              onPressed: _currentCardIndex > 0 ? _prevCard : null,
            ),
            ...List.generate(_cardList.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _currentCardIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentCardIndex ? const Color(lightForestGreenColor) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, size: 28, color: _currentCardIndex < _cardList.length - 1 ? const Color(lightForestGreenColor) : Colors.grey[300]),
              onPressed: _currentCardIndex < _cardList.length - 1 ? _nextCard : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFront() {
    if (_selectedCard == null) return const SizedBox();
    return Container(
      key: const ValueKey('front'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(lightForestGreenColor).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('INT Bank', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
              Image.asset('assets/images/visa.png', height: 24),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '**** **** **** ${_selectedCard!.last4}',
            style: GoogleFonts.spaceMono(fontSize: 18, color: Colors.white, letterSpacing: 3),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TITULAR', style: GoogleFonts.inter(fontSize: 9, color: Colors.white70, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(_selectedCard!.detinator.toUpperCase(), style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('EXPIRĂ', style: GoogleFonts.inter(fontSize: 9, color: Colors.white70, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(_selectedCard!.expiry ?? '12/28', style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    if (_selectedCard == null) return const SizedBox();
    return Container(
      key: const ValueKey('back'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(lightForestGreenColor), const Color(darkForestGreenColor)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(lightForestGreenColor).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            height: 40,
            color: Colors.black38,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedCard!.cvv ?? '***',
                      style: GoogleFonts.spaceMono(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('CVV', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sold disponibil', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              GestureDetector(
                onTap: _toggleBalance,
                child: Icon(
                  _balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _loadingBalance
                ? const SizedBox(
                    width: 24,
                    height: 32,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                : _balanceVisible
                    ? FadeTransition(
                        opacity: _balanceFadeAnimation,
                        child: Text(
                          '${_formatBalance(_balance)} RON',
                          key: ValueKey('balance_$_balance'),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(darkGreyColor),
                            letterSpacing: -0.5,
                          ),
                        ),
                      )
                    : Text('••••••••', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(darkGreyColor))),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRatesCard() {
    final service = CurrencyService.instance;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange_rounded, size: 20, color: const Color(lightForestGreenColor)),
              const SizedBox(width: 8),
              Text('Curs valutar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
              const Spacer(),
              if (service.hasRates)
                Text('1 RON', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 16),
          if (!service.hasRates)
            SizedBox(
              height: 60,
              child: Center(
                child: Text('Se încarcă...', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400])),
              ),
            )
          else
            ...service.rates!.entries.map((entry) {
              final currency = entry.key;
              final rate = entry.value;

              String symbol;
              String name;
              switch (currency) {
                case 'EUR':
                  symbol = '€';
                  name = 'Euro';
                  break;
                case 'USD':
                  symbol = r'$';
                  name = 'Dolar american';
                  break;
                case 'GBP':
                  symbol = '£';
                  name = 'Liră sterlină';
                  break;
                default:
                  symbol = '';
                  name = currency;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(lightForestGreenColor).withOpacity(0.08),
                      ),
                      child: Center(
                        child: Text(symbol, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(darkForestGreenColor))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currency, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
                          Text(name, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Text(
                      rate.toStringAsFixed(4),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(darkGreyColor)),
                    ),
                  ],
                ),
              );
            }),
          if (service.hasRates && service.lastCached.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Actualizat: ${_formatLastCached(service.lastCached)}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatLastCached(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day.$month.$hour:$minute';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _buildActionCard(Icons.send_rounded, 'Transfer', _goToTransfer)),
          const SizedBox(width: 12),
          Expanded(child: _buildActionCard(Icons.receipt_long_rounded, 'Istoric', _goToHistory)),
          const SizedBox(width: 12),
          Expanded(child: _buildActionCard(Icons.currency_exchange_rounded, 'Schimb', _goToExchange)),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(lightForestGreenColor).withOpacity(0.1),
              ),
              child: Icon(icon, color: const Color(lightForestGreenColor), size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(darkGreyColor))),
          ],
        ),
      ),
    );
  }
}
