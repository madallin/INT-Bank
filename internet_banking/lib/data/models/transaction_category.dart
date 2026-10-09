import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_tokens.dart';

/// What a transaction was for, as the bank classifies it (`category` on each transaction,
/// `categoryKey` in spending insights). Drives the icon, colour and name the app shows.
enum TransactionCategory
{
  groceries('ALIMENTE', Icons.shopping_cart_outlined),
  bills('UTILITATI', Icons.bolt_rounded),
  restaurants('RESTAURANTE', Icons.restaurant_rounded),
  transport('TRANSPORT', Icons.directions_car_filled_outlined),
  entertainment('DIVERTISMENT', Icons.movie_creation_outlined),
  other('ALTELE', Icons.arrow_upward_rounded),
  incoming('INCOMING', Icons.arrow_downward_rounded),
  ownAccounts('OWN_ACCOUNTS', Icons.swap_horiz_rounded);

  const TransactionCategory(this.key, this.icon);

  /// The bank's code for it.
  final String key;
  final IconData icon;

  static TransactionCategory? fromKey(Object? key)
  {
    for(final category in values)
    {
      if(category.key == key) return category;
    }
    return null;
  }

  /// A spending category (shown in insights), as opposed to money in or a move between accounts.
  bool get isSpending => this != incoming && this != ownAccounts;

  String label(AppLocalizations l10n) => switch(this)
  {
    groceries => l10n.categoryGroceries,
    bills => l10n.categoryBills,
    restaurants => l10n.categoryRestaurants,
    transport => l10n.categoryTransport,
    entertainment => l10n.categoryEntertainment,
    other => l10n.categoryOther,
    incoming => l10n.categoryIncoming,
    ownAccounts => l10n.categoryOwnAccounts,
  };

  /// Each theme has its own shade so the colour stays readable on its surfaces
  /// (checked in test/theme/contrast_test.dart).
  Color color(AppColors colors, Brightness brightness)
  {
    final dark = brightness == Brightness.dark;
    return switch(this)
    {
      groceries => colors.positive,
      bills => dark ? const Color(0xFFFF8A50) : const Color(0xFFE65100),
      restaurants => dark ? const Color(0xFFF06292) : const Color(0xFFC2185B),
      transport => dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
      entertainment => dark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
      other => colors.brand,
      incoming => colors.positive,
      ownAccounts => colors.brand,
    };
  }
}
