import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/card_model.dart';
import '../../../services/currency_service.dart';
import '../../transfer/screens/transfer_screen.dart';
import '../../transactions/screens/transaction_history_screen.dart';
import '../../exchange/screens/exchange_screen.dart';
import '../../welcome/welcome_screen.dart';

class HomeScreen extends StatefulWidget
{
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver
{
  final DioClient _client = DioClient();
  final List<CardModel> _cardList = [];
  CardModel? _selectedCard;
  int _currentCardIndex = 0;
  int? _currentAccountId;

  double _balance = 0.0;
  bool _balanceVisible = true;
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
  bool _loadingTransactions = false;

  @override
  void initState()
  {
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
    ).animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOut));
    _pageController.forward();

    _initialize();
    _startPeriodicRefresh();
  }

  Future<void> _initialize() async
  {
    await _initDeviceId();
    await _getClientToken();
    await _fetchCardsAndAccounts();
    await CurrencyService.instance.fetchRates();
    if(mounted) setState(() {});
  }

  Future<void> _initDeviceId() async
  {
    final deviceInfo = DeviceInfoPlugin();
    try
    {
      if(Platform.isAndroid)
{
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      }
      else if(Platform.isIOS)
{
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'dev-device';
      }
    }
    catch(_)
{
      _deviceId = 'dev-device';
    }
  }

  Future<void> _getClientToken() async
  {
    try
    {
      final response = await _client.post(
        '/auth/get-client-token',
        data: {'deviceId': _deviceId},
      );

      if(response.statusCode == 200)
{
        final data = response.data as Map<String, dynamic>;
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
      }
    }
    catch(e)
{
      debugPrint('Error getting client token: $e');
    }
  }

  Future<bool> _refreshClientToken() async
  {
    if(refreshToken == null) return false;
    try
    {
      final response = await _client.post(
        '/auth/refresh-client-token',
        data: {'deviceId': _deviceId, 'refreshToken': refreshToken},
      );

      if(response.statusCode == 200)
{
        final data = response.data as Map<String, dynamic>;
        if(mounted) setState(() => clientToken = data['client_token']);
        return true;
      }
      return false;
    }
    catch(_)
{
      return false;
    }
  }

  Options _authOptions()
  {
    return Options(
      headers: clientToken != null
          ? {'Authorization': 'Bearer $clientToken'}
          : null,
    );
  }

  Future<void> _fetchCardsAndAccounts() async
  {
    setState(() => _loading = true);
    try
    {
      final response = await _client.get(
        '/users/${widget.userId}/cards',
        options: _authOptions(),
      );

      if(response.statusCode == 200 && response.data != null)
{
        final data = response.data as Map<String, dynamic>;
        if(data['cards'] != null)
{
          final cards = List<Map<String, dynamic>>.from(data['cards']);
          setState(() {
            _cardList.clear();
            for(final card in cards)
{
              _cardList.add(CardModel.fromJson(card));
            }
            if(_cardList.isNotEmpty)
{
              _selectedCard = _cardList[_currentCardIndex];
              _currentAccountId = _selectedCard!.accountId;
            }
          });
        }
      }
      else if(response.statusCode == 401)
{
        final refreshed = await _refreshClientToken();
        if(refreshed) await _fetchCardsAndAccounts();
      }
    }
    catch(e)
{
      debugPrint('Error fetching cards: $e');
    }
    finally
    {
      if(mounted) setState(() => _loading = false);
    }
    if(_selectedCard != null)
{
      await _fetchBalance();
      await _fetchRecentTransactions();
    }
  }

  Future<void> _fetchBalance() async
  {
    setState(() => _loadingBalance = true);
    if(clientToken == null)
{
      setState(() => _loadingBalance = false);
      return;
    }

    int? accountId = _currentAccountId;

    if(accountId == null)
{
      try
      {
        final resp = await _client.get(
          '/users/${widget.userId}/cards',
          options: _authOptions(),
        );

        if(resp.statusCode == 200)
{
          final data = resp.data as Map<String, dynamic>;
          final cards = data['cards'] as List?;
          if(cards != null && cards.isNotEmpty)
{
            accountId = (cards.first as Map<String, dynamic>)['accountId'] as int?;
          }
        }
      }
      catch(_)
{}
      if(accountId == null)
{
        setState(() => _loadingBalance = false);
        return;
      }
    }

    try
    {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/$accountId',
        options: _authOptions(),
      );

      if(response.statusCode == 200)
{
        final data = response.data as Map<String, dynamic>;
        if(data['account'] != null && data['account']['sold'] != null)
{
          final sold = data['account']['sold'];
          setState(() => _balance =
              (sold is String ? double.parse(sold) : (sold as num).toDouble()));
        }
      }
      else if(response.statusCode == 401)
{
        final refreshed = await _refreshClientToken();
        if(refreshed) await _fetchBalance();
      }
    }
    catch(e)
{
      debugPrint('Error fetching balance: $e');
    }
    finally
    {
      if(mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _fetchRecentTransactions() async
  {
    if(_currentAccountId == null || clientToken == null) return;
    setState(() => _loadingTransactions = true);
    try
    {
      final response = await _client.get(
        '/users/${widget.userId}/accounts/$_currentAccountId/transactions',
        options: _authOptions(),
      );

      if(response.statusCode == 200 && response.data != null)
{
        final data = response.data as Map<String, dynamic>;
        if(data['transactions'] != null)
{
          final all = List<Map<String, dynamic>>.from(data['transactions']);
          if(mounted) setState(() => _recentTransactions = all.take(3).toList());
        }
      }
    }
    catch(e)
{
      debugPrint('Error fetching recent transactions: $e');
    }
    finally
    {
      if(mounted) setState(() => _loadingTransactions = false);
    }
  }

  void _startPeriodicRefresh()
  {
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_)
    {
      if(mounted)
{
        _fetchBalance();
        _fetchCardsAndAccounts();
      }
    });
  }

  @override
  void dispose()
  {
    WidgetsBinding.instance.removeObserver(this);
    _flipController.dispose();
    _pageController.dispose();
    _refreshTimer?.cancel();
    _cardRevealTimer?.cancel();
    super.dispose();
  }

  void _nextCard()
  {
    if(_currentCardIndex < _cardList.length - 1)
{
      _cancelCardReveal();
      setState(() {
        _currentCardIndex++;
        _selectedCard = _cardList[_currentCardIndex];
        _currentAccountId = _selectedCard!.accountId;
      });
      _fetchBalance();
      _fetchRecentTransactions();
    }
  }

  void _prevCard()
  {
    if(_currentCardIndex > 0)
{
      _cancelCardReveal();
      setState(() {
        _currentCardIndex--;
        _selectedCard = _cardList[_currentCardIndex];
        _currentAccountId = _selectedCard!.accountId;
      });
      _fetchBalance();
      _fetchRecentTransactions();
    }
  }

  void _cancelCardReveal()
  {
    _cardRevealTimer?.cancel();
    setState(() {
      _revealCountdown = 60;
      _cardShowingBack = false;
    });
    _flipController.value = 0;
  }

  Future<void> _onToggleCardReveal() async
  {
    if(_flipController.isAnimating) return;
    if(_cardShowingBack)
{
      _cardRevealTimer?.cancel();
      setState(() {
        _revealCountdown = 60;
        _cardShowingBack = false;
      });
      await _flipController.animateTo(0,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    }
    else
{
      if(_selectedCard == null) return;
      setState(() => _cardShowingBack = true);
      await _flipController.animateTo(1,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      _startRevealTimer();
    }
  }

  void _startRevealTimer()
  {
    _cardRevealTimer?.cancel();
    setState(() => _revealCountdown = 60);
    _cardRevealTimer = Timer.periodic(const Duration(seconds: 1), (timer)
    {
      if(!mounted)
{
        timer.cancel();
        return;
      }
      setState(() {
        _revealCountdown--;
        if(_revealCountdown <= 0)
{
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

  void _toggleBalance()
  {
    setState(() => _balanceVisible = !_balanceVisible);
  }

  void _goToTransfer()
  {
    if(_selectedCard == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TransferScreen(userId: widget.userId, userIban: '')),
    );
  }

  void _goToHistory()
  {
    if(_currentAccountId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(
          userId: widget.userId,
          accountId: _currentAccountId!,
        ),
      ),
    ).then((_) => _fetchRecentTransactions());
  }

  void _goToExchange()
  {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExchangeScreen(userId: widget.userId)),
    );
  }

  void _goToStatement()
  {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Extras de cont – funcție disponibilă în curând',
            style: GoogleFonts.inter(fontSize: 14)),
        backgroundColor: const Color(lightForestGreenColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _logout() async
  {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'loggedUserIdKey');
    if(!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  String _formatBalance(double bal)
  {
    final parts = bal.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$intPart,${parts[1]}';
  }

  String _formatPan(String raw)
  {
    final clean = raw.replaceAll(' ', '');
    final buf = StringBuffer();
    for(int i = 0; i < clean.length; i++)
{
      if(i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(clean[i]);
    }
    return buf.toString();
  }

  String _txDate(String dateStr)
  {
    try
    {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    catch(_)
{
      return dateStr;
    }
  }

  String _txAmount(Map<String, dynamic> t)
  {
    final isIn = t['type'] == 'received';
    final double amt = (t['suma'] as num).toDouble();
    final str = amt.toStringAsFixed(2).replaceAll('.', ',');
    final parts = str.split(',');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${isIn ? '+' : '-'}$intPart,${parts[1]} RON';
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SlideTransition(
                position: _pageAnimation,
                child: RefreshIndicator(
                  onRefresh: () async
                  {
                    await _fetchCardsAndAccounts();
                    await CurrencyService.instance.fetchRates();
                    if(mounted) setState(() {});
                  },
                  color: const Color(lightForestGreenColor),
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
                        const SizedBox(height: 28),
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

  Widget _buildHeader()
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(lightForestGreenColor).withOpacity(0.12),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Color(lightForestGreenColor), size: 22),
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
                        color: const Color(darkGreyColor),
                        letterSpacing: -0.3)),
                Text('Bun venit!',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: Colors.grey[100]),
              child:
                  Icon(Icons.logout_rounded, size: 20, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection()
  {
    if(_cardList.isEmpty)
{
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Nu ai carduri disponibile',
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500])),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedBuilder(
            animation: _flipController,
            builder: (context, _)
            {
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
        if(_cardList.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _currentCardIndex > 0 ? _prevCard : null,
                child: Icon(Icons.chevron_left_rounded,
                    size: 26,
                    color: _currentCardIndex > 0
                        ? const Color(lightForestGreenColor)
                        : Colors.grey[300]),
              ),
              const SizedBox(width: 6),
              ...List.generate(_cardList.length, (i)
              {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentCardIndex ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _currentCardIndex
                        ? const Color(lightForestGreenColor)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _currentCardIndex < _cardList.length - 1
                    ? _nextCard
                    : null,
                child: Icon(Icons.chevron_right_rounded,
                    size: 26,
                    color: _currentCardIndex < _cardList.length - 1
                        ? const Color(lightForestGreenColor)
                        : Colors.grey[300]),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCardFront()
  {
    if(_selectedCard == null) return const SizedBox();
    return Container(
      key: const ValueKey('front'),
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F9D8E), Color(0xFF005F52)],
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
            padding: const EdgeInsets.all(22),
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
                    Image.asset('assets/images/visa.png', height: 22),
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
                      color: Colors.white60, size: 16),
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
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TITULAR',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white60,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 3),
                        Text(_selectedCard!.detinator.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('EXPIRĂ',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white60,
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

  Widget _buildCardBack()
  {
    if(_selectedCard == null) return const SizedBox();
    final pan = _selectedCard!.fullNumber;
    final cvv = _selectedCard!.cvv;
    final expiry = _selectedCard!.expiry;

    return Container(
      key: const ValueKey('back'),
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF005F52), Color(0xFF0F9D8E)],
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
                    Text('PAN  ',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white60,
                            letterSpacing: 1.5)),
                    Text(
                      _formatPan(pan),
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
                                  color: Colors.white.withOpacity(0.55),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(5),
                                    bottomLeft: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
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
                        Text('CVV',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white60,
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
                    Text('EXP: $expiry',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500)),
                    GestureDetector(
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
                                size: 12, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text('Ascunde',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8))),
                          ],
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

  Widget _buildBalanceRow()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sold disponibil',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                _loadingBalance
                    ? const SizedBox(
                        width: 120,
                        height: 18,
                        child: LinearProgressIndicator(),
                      )
                    : Row(
                        children: [
                          Text(
                            _balanceVisible
                                ? '${_formatBalance(_balance)} RON'
                                : '*****',
                            style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(darkGreyColor),
                                letterSpacing: -0.5),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _toggleBalance,
                            child: Icon(
                              _balanceVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 20,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
              ],
            ),
            GestureDetector(
              onTap: _goToStatement,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(lightForestGreenColor).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 16, color: Color(lightForestGreenColor)),
                    const SizedBox(width: 6),
                    Text('Extras',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(lightForestGreenColor))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildActionCard(IconData icon, String label, VoidCallback onTap)
  {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
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
                color: const Color(lightForestGreenColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(lightForestGreenColor), size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(darkGreyColor))),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangePreview()
  {
    final rates = CurrencyService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(lightForestGreenColor).withOpacity(0.08),
              const Color(darkForestGreenColor).withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(lightForestGreenColor).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 18, color: Color(lightForestGreenColor)),
                const SizedBox(width: 8),
                Text('Curs valutar',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(darkGreyColor))),
              ],
            ),
            const SizedBox(height: 12),
            if(!rates.hasRates)
              Center(
                child: Text('Se încarcă...',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[500])),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRateTile('EUR', rates.getRate('EUR', 'RON')),
                  _buildRateTile('USD', rates.getRate('USD', 'RON')),
                  _buildRateTile('GBP', rates.getRate('GBP', 'RON')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateTile(String currency, double? rate)
  {
    return Column(
      children: [
        Text(currency,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(darkGreyColor))),
        const SizedBox(height: 4),
        Text(
          rate != null ? rate.toStringAsFixed(4) : '---',
          style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(lightForestGreenColor)),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tranzacții recente',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(darkGreyColor))),
              if(_currentAccountId != null)
                GestureDetector(
                  onTap: _goToHistory,
                  child: Text('Vezi toate',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(lightForestGreenColor),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if(_loadingTransactions)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if(_recentTransactions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Nu există tranzacții recente',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[500])),
            )
          else
            ...(_recentTransactions.asMap().entries.map((entry)
            {
              return Padding(
                padding: EdgeInsets.only(bottom: entry.key < _recentTransactions.length - 1 ? 10 : 0),
                child: _buildTransactionItem(entry.value),
              );
            })),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx)
  {
    final isPositive = tx['type'] == 'received';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isPositive
                      ? const Color(lightForestGreenColor)
                      : Colors.red)
                  .withOpacity(0.1),
            ),
            child: Icon(
              isPositive
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: isPositive
                  ? const Color(lightForestGreenColor)
                  : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['beneficiary'] ?? tx['motiv'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(darkGreyColor)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _txDate(tx['dataTransfer'] ?? ''),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          Text(
            _txAmount(tx),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPositive
                  ? const Color(lightForestGreenColor)
                  : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
