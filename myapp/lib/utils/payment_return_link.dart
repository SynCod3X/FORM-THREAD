class PaymentReturnLink {
  static final RegExp _orderIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String? orderId(Uri uri) {
    if (uri.scheme != 'formandthread' || uri.host != 'payment-return') {
      return null;
    }
    final orderId = uri.queryParameters['order_id'];
    return orderId != null && _orderIdPattern.hasMatch(orderId)
        ? orderId
        : null;
  }
}
