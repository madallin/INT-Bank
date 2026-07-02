import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

import '../../../config/app_config.dart';

class TransactionHistoryScreen extends StatefulWidget
{
  final int userId;
  final int accountId;

  const TransactionHistoryScreen({
    super.key,
    required this.userId,
    required this.accountId,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with TickerProviderStateMixin
{
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  String? clientToken;
  String? refreshToken;
  String _deviceId = 'dev-device';

  @override
  void initState()
  {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut);
    _fadeController!.forward();

    _initDeviceAndFetch();
  }

  @override
  void dispose()
  {
    _fadeController?.dispose();
    super.dispose();
  }

  Future<void> _initDeviceAndFetch() async
  {
    await _initDeviceId();
    await _getClientToken();
    await _fetchTransactions();
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
    catch (_)
{
      _deviceId = 'dev-device';
    }
  }

  http.Client _createHttpClient()
  {
    return IOClient(HttpClient());
  }

  Future<void> _getClientToken() async
  {
    try
    {
      final client = _createHttpClient();
      final response = await client.post(
        Uri.parse('https://${AppConfig.serverUrl}/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId}),
      );
      client.close();

      if(response.statusCode == 200)
{
        final data = jsonDecode(response.body);
        clientToken = data['client_token'];
        refreshToken = data['refresh_token'];
      }
    }
    catch (e)
{
      debugPrint('Error getting client token: $e');
    }
  }

  Future<bool> _refreshClientToken() async
  {
    if(refreshToken == null) return false;
    final client = _createHttpClient();
    try
    {
      final response = await client.post(
        Uri.parse('https://${AppConfig.serverUrl}/auth/refresh-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': _deviceId, 'refreshToken': refreshToken}),
      );
      if(response.statusCode == 200)
{
        final data = jsonDecode(response.body);
        if(mounted) setState(() => clientToken = data['client_token']);
        return true;
      }
      return false;
    }
    catch (_)
{
      return false;
    }
    finally
    {
      client.close();
    }
  }

  Future<void> _fetchTransactions() async
  {
    setState(() => _loading = true);
    try
    {
      final client = _createHttpClient();
      final uri = Uri.parse('https://${AppConfig.serverUrl}/users/${widget.userId}/accounts/${widget.accountId}/transactions');
      final response = await client.get(uri, headers: {
        'Content-Type': 'application/json',
        if(clientToken != null) 'Authorization': 'Bearer $clientToken',
      });
      client.close();

      if(response.statusCode == 200 && response.body.isNotEmpty)
{
        final data = jsonDecode(response.body);
        if(data['transactions'] != null)
{
          setState(() => _transactions = List<Map<String, dynamic>>.from(data['transactions']));
        }
      }
      else if(response.statusCode == 401)
{
        final refreshed = await _refreshClientToken();
        if(refreshed) await _fetchTransactions();
      }
    }
    catch (e)
{
      debugPrint('Error fetching transactions: $e');
    }
    finally
    {
      if(mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String dateStr)
  {
    final date = DateTime.parse(dateStr);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatAmount(Map<String, dynamic> transaction)
  {
    final type = transaction['type'];
    final double amount = (transaction['suma'] as num).toDouble();
    final displayAmount = type == 'received' ? amount : -amount;
    final absAmount = displayAmount.abs();
    final formatted = absAmount.toStringAsFixed(2).replaceAll('.', ',');
    final parts = formatted.split(',');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${displayAmount >= 0 ? '+' : '-'}$intPart,${parts[1]}';
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction)
  {
    final isPositive = transaction['type'] == 'received';
    final amountStr = _formatAmount(transaction);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['beneficiary'] ?? transaction['motiv'] ?? '',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(darkGreyColor)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(_formatDate(transaction['dataTransfer']), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amountStr, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isPositive ? const Color(lightForestGreenColor) : Colors.red.shade600)),
              const SizedBox(height: 2),
              Text(transaction['moneda'] ?? 'RON', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(darkGreyColor),
                  ),
                  Text('Istoric tranzacții', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(darkGreyColor), letterSpacing: 0.2)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FadeTransition(
                      opacity: _fadeAnimation!,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 46),
                                Text('Istoric tranzacții', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(darkGreyColor), letterSpacing: -0.5)),
                                const SizedBox(height: 12),
                                Text('Vizualizează ultimele tranzacții efectuate în contul tău', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w400, height: 1.5)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _transactions.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Text('Nu există tranzacții recente realizate în acest cont bancar.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                                    ),
                                  )
                                : ListView(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    children: [
                                      const SizedBox(height: 32),
                                      ..._transactions.map((t) => _buildTransactionCard(t)),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

