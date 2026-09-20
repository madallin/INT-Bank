import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Model & Filtering Tests', () {
    test('Notification items correctly differentiate read vs unread with both read and isRead keys', () {
      final item1 = {'id': 1, 'title': 'Transfer Primit', 'type': 'TRANSFER_RECEIVED', 'read': false};
      final item2 = {'id': 2, 'title': 'Transfer Trimis', 'type': 'TRANSFER_SENT', 'isRead': true};
      final item3 = {'id': 3, 'title': 'Alerta Securitate', 'type': 'SECURITY_ALERT', 'read': true};
      final item4 = {'id': 4, 'title': 'Transfer Primit', 'type': 'TRANSFER_RECEIVED', 'read': false, 'isRead': false};

      bool isRead(Map<String, dynamic> n) => n['read'] == true || n['isRead'] == true;

      expect(isRead(item1), false);
      expect(isRead(item2), true);
      expect(isRead(item3), true);
      expect(isRead(item4), false);
    });

    test('Filter logic filters transactions and security alerts properly', () {
      final list = [
        {'id': 1, 'type': 'TRANSFER_RECEIVED', 'title': 'Bani primiti: +150 RON', 'read': false},
        {'id': 2, 'type': 'TRANSFER_SENT', 'title': 'Transfer trimis: -150 RON', 'read': true},
        {'id': 3, 'type': 'SECURITY_ALERT', 'title': 'Card blocat', 'read': false},
        {'id': 4, 'type': 'SYSTEM', 'title': 'Mentenanta sistem', 'read': true},
      ];

      final transactions = list.where((n) {
        final t = n['type'] ?? '';
        return t == 'TRANSFER_RECEIVED' || t == 'TRANSFER_SENT';
      }).toList();

      final security = list.where((n) => (n['type'] ?? '') == 'SECURITY_ALERT').toList();
      final unreadCount = list.where((n) => !(n['read'] == true || n['isRead'] == true)).length;

      expect(transactions.length, 2);
      expect(security.length, 1);
      expect(security.first['title'], 'Card blocat');
      expect(unreadCount, 2);
    });

    test('Unread badge count calculation is accurate', () {
      final notifications = [
        {'id': 1, 'read': true},
        {'id': 2, 'read': false},
        {'id': 3, 'isRead': false},
        {'id': 4, 'read': true, 'isRead': true},
      ];

      int unread = notifications.where((n) => n['read'] == false || n['isRead'] == false).length;
      expect(unread, 2);
    });
  });
}
