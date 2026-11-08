import 'package:intl/intl.dart';

import 'currency_table.dart';
import 'util.dart';

class Currency {
  final String code;
  final String name;
  final String symbol;

  /// units of this currency for 1 USD (built-in reference)
  final double perUsd;
  const Currency(this.code, this.name, this.symbol, this.perUsd);
}

final Map<String, Currency> kCurrencyMap = {for (final c in kCurrencies) c.code: c};

String currencySymbol(String code) => kCurrencyMap[code]?.symbol ?? code;
String currencyName(String code) => kCurrencyMap[code]?.name ?? code;

final NumberFormat _fmt2 = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _fmt0 = NumberFormat('#,##0', 'en_US');

/// Same output as the web app: "Rs 1,234.50", "-Rf 20.00"
String money(num n, String cur, {bool sign = false, bool noDecimals = false}) {
  final neg = n < 0;
  final v = (noDecimals ? _fmt0 : _fmt2).format(n.abs());
  return '${neg ? '-' : (sign && n > 0 ? '+' : '')}${currencySymbol(cur)} $v';
}

/// Exchange rates, identical rules to the web app:
/// 1) a manual rate for the pair (or its inverse) in data.rates
/// 2) otherwise cross through USD (manual USD rate > live downloaded rate > built-in table)
class Rates {
  final List<Map<String, dynamic>> manual;
  final Map<String, dynamic>? live;
  Rates(this.manual, this.live);

  double? _manual(String from, String to) {
    for (final r in manual) {
      if (r['from'] == from && r['to'] == to && toD(r['rate']) != 0) return toD(r['rate']);
    }
    return null;
  }

  double usdRate(String c) {
    if (c == 'USD') return 1;
    final m = _manual('USD', c);
    if (m != null) return m;
    final mi = _manual(c, 'USD');
    if (mi != null) return 1 / mi;
    final l = live;
    if (l != null && l[c] != null && toD(l[c]) != 0) return toD(l[c]);
    return kCurrencyMap[c]?.perUsd ?? 0;
  }

  double rateOf(String from, String to) {
    if (from == to) return 1;
    final r = _manual(from, to);
    if (r != null) return r;
    final inv = _manual(to, from);
    if (inv != null) return 1 / inv;
    final f = usdRate(from), t = usdRate(to);
    if (f == 0 || t == 0) return 1;
    return t / f;
  }

  double conv(num amount, String from, String to) => amount.toDouble() * rateOf(from, to);
}
