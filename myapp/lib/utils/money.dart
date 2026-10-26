/// Formats a stored amount without changing its numeric value.
String formatMoney(num amount, {String currency = 'PHP'}) {
  final fixed = amount.toStringAsFixed(2).split('.');
  final whole = fixed.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final symbol = currency == 'PHP' ? '₱' : '\$';
  return '$symbol$whole.${fixed.last}';
}

String formatPeso(num amount) => formatMoney(amount);

/// Orders created before the PHP catalog migration keep their original units.
String formatOrderMoney(num amount, Map<String, dynamic> order) =>
    formatMoney(amount, currency: order['currency'] as String? ?? 'USD');
