import '../../../theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../l10n/l10n.dart';

class NotificationCenterBottomSheet extends StatefulWidget {
  final int userId;

  const NotificationCenterBottomSheet({
    super.key,
    required this.userId,
  });

  static Future<void> show(BuildContext context, {required int userId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationCenterBottomSheet(userId: userId),
    );
  }

  @override
  State<NotificationCenterBottomSheet> createState() => _NotificationCenterBottomSheetState();
}

class _NotificationCenterBottomSheetState extends State<NotificationCenterBottomSheet> {
  final DioClient _client = DioClient();

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int _selectedFilter = 0;

  List<String> get _filters => [context.l10n.historyToate, context.l10n.notificationsTranzactii, context.l10n.notificationsSecuritate];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final response = await _client.get('/users/${widget.userId}/notifications');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['notifications'] != null) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(data['notifications']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _client.put('/users/${widget.userId}/notifications/read-all');
      setState(() {
        for (var n in _notifications) {
          n['read'] = true;
          n['isRead'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _markAsRead(int id, int index) async {
    try {
      await _client.put('/users/${widget.userId}/notifications/$id/read');
      setState(() {
        _notifications[index]['read'] = true;
        _notifications[index]['isRead'] = true;
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_selectedFilter == 1) {
      return _notifications.where((n) {
        final t = n['type'] ?? '';
        return t == 'TRANSFER_RECEIVED' || t == 'TRANSFER_SENT';
      }).toList();
    } else if (_selectedFilter == 2) {
      return _notifications.where((n) => (n['type'] ?? '') == 'SECURITY_ALERT').toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.notificationsCentruNotificari,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
              ),
              if (_notifications.any((n) => n['read'] == false || n['isRead'] == false))
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: Icon(Icons.done_all_rounded, size: 16, color: context.colors.brand),
                  label: Text(
                    context.l10n.notificationsMarcheazaCitite,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.brand),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_filters.length, (index) {
                final isSelected = _selectedFilter == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = index),
                    selectedColor: context.colors.brand,
                    backgroundColor: context.colors.surfaceMuted,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? context.colors.onBrand : context.colors.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide.none,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: context.colors.brand))
                : _filteredList.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 48, color: context.colors.border),
                  const SizedBox(height: 12),
                  Text(context.l10n.notificationsNicioNotificareDisponibila, style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredList.length,
              itemBuilder: (context, index) {
                final n = _filteredList[index];
                final isRead = n['read'] == true || n['isRead'] == true;
                final type = n['type'] ?? 'SYSTEM';
                final title = n['title'] ?? context.l10n.notificationsNotificare;
                final message = n['message'] ?? '';
                final id = n['id'] as int? ?? 0;

                return GestureDetector(
                  onTap: () {
                    if (!isRead && id > 0) _markAsRead(id, index);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? context.colors.surface : context.colors.brandSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRead ? context.colors.border : context.colors.brand.withValues(alpha: 0.3),
                        width: isRead ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTypeIcon(type),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: context.colors.brand,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'TRANSFER_RECEIVED':
        iconData = Icons.arrow_downward_rounded;
        iconColor = context.colors.positive;
        bgColor = context.colors.brandSurface;
        break;
      case 'TRANSFER_SENT':
        iconData = Icons.arrow_upward_rounded;
        iconColor = const Color(0xFF1E88E5);
        bgColor = iconColor.withValues(alpha: 0.14);
        break;
      case 'SECURITY_ALERT':
        iconData = Icons.shield_outlined;
        iconColor = context.colors.danger;
        bgColor = context.colors.dangerSurface;
        break;
      default:
        iconData = Icons.info_outline_rounded;
        iconColor = context.colors.brand;
        bgColor = context.colors.brandSurface;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Icon(iconData, color: iconColor, size: 18),
    );
  }
}
