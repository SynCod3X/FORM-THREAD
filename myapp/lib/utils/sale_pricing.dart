/// Calculates the customer-facing price in cents, rounding half cents up.
double? calculateSalePrice(double regularPrice, double discountPercent) {
  if (!regularPrice.isFinite ||
      !discountPercent.isFinite ||
      regularPrice <= 0 ||
      discountPercent <= 0 ||
      discountPercent >= 100 ||
      !hasAtMostTwoDecimals(regularPrice) ||
      !hasAtMostTwoDecimals(discountPercent)) {
    return null;
  }

  final regularCents = (regularPrice * 100).round();
  final discountHundredths = (discountPercent * 100).round();
  final saleCents =
      (regularCents * (10000 - discountHundredths) + 5000) ~/ 10000;
  return saleCents > 0 && saleCents < regularCents ? saleCents / 100 : null;
}

bool hasAtMostTwoDecimals(double value) =>
    (value * 100 - (value * 100).round()).abs() < 0.0000001;
