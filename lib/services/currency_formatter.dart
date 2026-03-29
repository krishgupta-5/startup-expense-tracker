/// Standardized currency formatting service for the startup expense tracker
///
/// Ensures consistent currency formatting across all UI components
/// and eliminates formatting inconsistencies that can cause confusion.
library;
import 'currency_preference_service.dart';

class CurrencyFormatter {
  // Private constructor to prevent instantiation
  CurrencyFormatter._();

  // Currency mapping based on country codes
  static const Map<String, String> _countryCurrencies = {
    '+1': '\$', // United States - USD
    '+91': '₹', // India - INR
    '+44': '£', // United Kingdom - GBP
    '+61': 'A\$', // Australia - AUD
    '+81': '¥', // Japan - JPY
    '+49': '€', // Germany - EUR
    '+33': '€', // France - EUR
    '+971': 'د.إ', // UAE - AED
    '+65': 'S\$', // Singapore - SGD
  };

  // Currency decimal places mapping
  static const Map<String, int> _currencyDecimals = {
    '+1': 2, // USD
    '+91': 2, // INR
    '+44': 2, // GBP
    '+61': 2, // AUD
    '+81': 0, // JPY (no decimal places)
    '+49': 2, // EUR
    '+33': 2, // EUR
    '+971': 2, // AED
    '+65': 2, // SGD
  };

  // Get currency symbol from country code
  static String getCurrencySymbol(String countryCode) {
    return _countryCurrencies[countryCode] ?? '\$'; // Default to USD
  }

  // Get decimal places for currency
  static int getDecimalPlaces(String countryCode) {
    return _currencyDecimals[countryCode] ?? 2; // Default to 2 decimal places
  }

  /// Get the current user's preferred currency code
  /// Uses the currency preference service to get user's selection
  static Future<String> getCurrentCurrencyCode() async {
    return await CurrencyPreferenceService.getCurrencyPreference();
  }

  /// Get the current user's preferred currency code synchronously
  /// Uses cached value from currency preference service
  static String getCurrentCurrencyCodeSync() {
    return CurrencyPreferenceService.getCurrencyPreferenceSync();
  }

  /// Format currency value with proper formatting based on country code
  ///
  /// [value] - The monetary value to format
  /// [countryCode] - Country code for currency symbol and formatting (default: user's preferred currency)
  /// [includeSymbol] - Whether to include currency symbol (default: true)
  /// [decimalPlaces] - Number of decimal places (default: based on currency)
  /// Returns formatted currency string
  static String format(
    double value, {
    String? countryCode,
    bool includeSymbol = true,
    int? decimalPlaces,
  }) {
    // Use user's preferred currency if no country code is provided
    final effectiveCountryCode = countryCode ?? getCurrentCurrencyCodeSync();

    // Get decimal places for the currency if not specified
    final places = decimalPlaces ?? getDecimalPlaces(effectiveCountryCode);

    // Round to avoid floating point precision issues
    final roundedValue = double.parse(value.toStringAsFixed(places));

    // Convert to string and add commas for thousands
    String formatted = roundedValue.toStringAsFixed(places);

    // Format based on country
    if (effectiveCountryCode == '+91') {
      // Indian format: 1,00,000
      if (places == 0) {
        formatted = formatted.replaceAllMapped(
          RegExp(r'(\d)(?=(\d\d)+\d$)'),
          (match) => '${match[1]},',
        );
      } else {
        // For decimal values, format the integer part
        final parts = formatted.split('.');
        final integerPart = parts[0].replaceAllMapped(
          RegExp(r'(\d)(?=(\d\d)+\d$)'),
          (match) => '${match[1]},',
        );
        formatted = '$integerPart.${parts[1]}';
      }
    } else {
      // International format: 1,000,000
      final parts = formatted.split('.');
      final integerPart = _formatWithCommas(int.parse(parts[0]));
      formatted = places == 0 ? integerPart : '$integerPart.${parts[1]}';
    }

    // Add currency symbol if requested
    if (includeSymbol) {
      return '${getCurrencySymbol(effectiveCountryCode)}$formatted';
    }

    return formatted;
  }

  /// Extension method for international number formatting
  static String _formatWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  /// Format currency with symbol and no decimal places (most common use case)
  /// Uses user's preferred currency automatically
  static Future<String> formatWithUserPreference(double value) async {
    final currencyCode = await getCurrentCurrencyCode();
    return format(
      value,
      countryCode: currencyCode,
      includeSymbol: true,
      decimalPlaces: 0,
    );
  }

  /// Format currency with symbol and no decimal places (synchronous version)
  /// Uses cached user's preferred currency
  static String formatWithUserPreferenceSync(double value) {
    return format(
      value,
      includeSymbol: true,
      decimalPlaces: 0,
    ); // Will use user preference by default
  }

  /// Format currency with symbol and appropriate decimal places
  /// Uses user's preferred currency automatically
  static Future<String> formatFinancialWithUserPreference(double value) async {
    final currencyCode = await getCurrentCurrencyCode();
    return format(
      value,
      countryCode: currencyCode,
      includeSymbol: true,
      decimalPlaces: 2,
    );
  }

  /// Format currency with symbol and appropriate decimal places (synchronous version)
  /// Uses cached user's preferred currency
  static String formatFinancialWithUserPreferenceSync(double value) {
    return format(
      value,
      includeSymbol: true,
      decimalPlaces: 2,
    ); // Will use user preference by default
  }

  /// Format currency for display in financial statements
  static String formatFinancial(double value) {
    return format(value, includeSymbol: true, decimalPlaces: 2);
  }

  /// Format currency based on country code with symbol and appropriate decimal places
  static String formatByCountry(double value, String countryCode) {
    return format(value, countryCode: countryCode, includeSymbol: true);
  }

  /// Format currency without symbol (for table columns where symbol is in header)
  static String formatAmount(double value) {
    return format(value, includeSymbol: false, decimalPlaces: 0);
  }

  /// Format currency with symbol and no decimal places (most common use case)
  static String formatRupees(double value) {
    return format(value, includeSymbol: true, decimalPlaces: 0);
  }

  /// Format currency for charts and graphs (abbreviated format)
  static String formatAbbreviated(double value, {String? countryCode}) {
    final effectiveCountryCode = countryCode ?? getCurrentCurrencyCodeSync();
    final symbol = getCurrencySymbol(effectiveCountryCode);

    if (effectiveCountryCode == '+91') {
      // Indian abbreviations
      if (value >= 10000000) {
        // 1 crore
        return '$symbol${(value / 10000000).toStringAsFixed(1)}C';
      } else if (value >= 100000) {
        // 1 lakh
        return '$symbol${(value / 100000).toStringAsFixed(1)}L';
      } else if (value >= 1000) {
        // 1K
        return '$symbol${(value / 1000).toStringAsFixed(1)}K';
      }
    } else {
      // International abbreviations
      if (value >= 1000000) {
        // 1M
        return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
      } else if (value >= 1000) {
        // 1K
        return '$symbol${(value / 1000).toStringAsFixed(1)}K';
      }
    }

    return formatByCountry(value, effectiveCountryCode);
  }

  /// Parse formatted currency string back to double
  ///
  /// [formattedString] - The formatted currency string (e.g., "₹1,00,000")
  /// Returns the numeric value, or null if parsing fails
  static double? parse(String formattedString) {
    try {
      // Remove rupee symbol and commas
      String clean = formattedString.replaceAll('₹', '').replaceAll(',', '');

      // Handle abbreviated formats
      if (clean.endsWith('C')) {
        clean = clean.replaceAll('C', '');
        return double.parse(clean) * 10000000;
      } else if (clean.endsWith('L')) {
        clean = clean.replaceAll('L', '');
        return double.parse(clean) * 100000;
      } else if (clean.endsWith('K')) {
        clean = clean.replaceAll('K', '');
        return double.parse(clean) * 1000;
      }

      return double.parse(clean);
    } catch (e) {
      return null;
    }
  }

  /// Validate if a string is a valid formatted currency
  static bool isValidFormat(String formattedString) {
    return parse(formattedString) != null;
  }
}
