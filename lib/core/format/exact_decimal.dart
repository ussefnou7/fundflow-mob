/// Decimal arithmetic for financial inputs. Never round through a binary double.
class ExactDecimal {
  const ExactDecimal._(this.units, this.scale);
  final BigInt units;
  final int scale;
  static final zero = ExactDecimal._(BigInt.zero, 0);

  factory ExactDecimal.parse(String input) {
    var value = input.trim().replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      value = value
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
    }
    if (value.length > 80 || !RegExp(r'^[+-]?\d+(\.\d+)?$').hasMatch(value)) {
      throw const FormatException('Invalid decimal');
    }
    final parts = value.split('.');
    return ExactDecimal._(
      BigInt.parse(parts.join()),
      parts.length == 2 ? parts[1].length : 0,
    );
  }

  static ExactDecimal? tryParse(String input) {
    try {
      return ExactDecimal.parse(input);
    } on FormatException {
      return null;
    }
  }

  ExactDecimal operator +(ExactDecimal other) {
    final target = scale > other.scale ? scale : other.scale;
    return ExactDecimal._(
      units * BigInt.from(10).pow(target - scale) +
          other.units * BigInt.from(10).pow(target - other.scale),
      target,
    );
  }

  ExactDecimal operator -() => ExactDecimal._(-units, scale);
  ExactDecimal operator *(ExactDecimal other) =>
      ExactDecimal._(units * other.units, scale + other.scale);
  ExactDecimal get percent => ExactDecimal._(units, scale + 2);

  ExactDecimal rounded(int digits) {
    if (scale <= digits) {
      return ExactDecimal._(
        units * BigInt.from(10).pow(digits - scale),
        digits,
      );
    }
    final divisor = BigInt.from(10).pow(scale - digits);
    var result = units.abs() ~/ divisor;
    if ((units.abs() % divisor) * BigInt.two >= divisor) result += BigInt.one;
    return ExactDecimal._(units.isNegative ? -result : result, digits);
  }

  int compareTo(ExactDecimal other) {
    final target = scale > other.scale ? scale : other.scale;
    return (units * BigInt.from(10).pow(target - scale)).compareTo(
      other.units * BigInt.from(10).pow(target - other.scale),
    );
  }

  String money() {
    final fixed = rounded(2).toString().split('.');
    final whole = fixed.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$whole.${fixed.last}';
  }

  @override
  String toString() {
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    final sign = units.isNegative ? '-' : '';
    if (scale == 0) return '$sign$digits';
    return '$sign${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }
}
