import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_tokens.dart';

/// A row of the customer's saved recipients (their payment address book): one tap fills the name and IBAN. Shows
/// nothing when there are none or they cannot be loaded.
class SavedRecipients extends StatefulWidget
{
  const SavedRecipients({super.key, required this.userId, required this.onSelect, this.limit = 8});

  final int userId;
  final void Function(String name, String iban) onSelect;
  final int limit;

  @override
  State<SavedRecipients> createState() => _SavedRecipientsState();
}

class _SavedRecipientsState extends State<SavedRecipients>
{
  List<({String name, String iban})> _recipients = const [];

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
      final response = await DioClient().get('/users/${widget.userId}/beneficiaries');
      final data = response.data as Map<String, dynamic>;
      final list = <({String name, String iban})>[];
      for(final item in (data['beneficiaries'] as List? ?? const []))
      {
        final map = Map<String, dynamic>.from(item as Map);
        final name = (map['nickname'] ?? map['name'] ?? '').toString().trim();
        final iban = (map['iban'] ?? '').toString().trim();
        if(name.isNotEmpty && iban.isNotEmpty) list.add((name: name, iban: iban));
      }
      if(mounted) setState(() => _recipients = list.take(widget.limit).toList());
    }
    catch(_)
    {
      // Optional shortcut: the form works without it.
    }
  }

  static String _initials(String name)
  {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if(words.isEmpty) return '?';
    return (words.first[0] + (words.length > 1 ? words.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context)
  {
    if(_recipients.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(context.l10n.transferSavedRecipients, style: context.text.labelMedium)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recipients.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final r = _recipients[index];
              final firstName = r.name.split(RegExp(r'\s+')).first;
              return Semantics(
                button: true,
                label: context.l10n.transferToRecipient(r.name),
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () {
                    HapticFeedbackHelper.selection();
                    widget.onSelect(r.name, r.iban);
                  },
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: c.brandSurface,
                          child: Text(_initials(r.name), style: context.text.titleSmall?.copyWith(color: c.brand)),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
