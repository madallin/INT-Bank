import '../../l10n/l10n.dart';
import 'formatters.dart';

/// Consecutive items that happened on the same calendar day. [day] is null for items
/// without a date.
class DayGroup<T>
{
  const DayGroup(this.day, this.items);

  final DateTime? day;
  final List<T> items;
}

/// Splits a newest-first list into runs of the same day, keeping the order.
List<DayGroup<T>> groupByDay<T>(Iterable<T> items, DateTime? Function(T item) dateOf)
{
  final groups = <DayGroup<T>>[];
  DateTime? currentDay;
  var started = false;
  for(final item in items)
  {
    final date = dateOf(item);
    final day = date == null ? null : DateTime(date.year, date.month, date.day);
    if(!started || day != currentDay)
    {
      groups.add(DayGroup<T>(day, <T>[]));
      currentDay = day;
      started = true;
    }
    groups.last.items.add(item);
  }
  return groups;
}

/// "Today", "Yesterday", otherwise the date, in the active language.
String dayLabel(DateTime day, {DateTime? now})
{
  final today = now ?? DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  final target = DateTime(day.year, day.month, day.day);
  final daysAgo = midnight.difference(target).inDays;
  if(daysAgo == 0) return AppL10n.current.dayToday;
  if(daysAgo == 1) return AppL10n.current.dayYesterday;
  return formatDate(target);
}
