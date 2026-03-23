/// Standardized currency formatting service for the startup expense tracker
///
/// Ensures consistent currency formatting across all UI components
/// and eliminates formatting inconsistencies that can cause confusion.
class CurrencyFormatter {
  // Private constructor to prevent instantiation
  CurrencyFormatter._();

  /// Format currency value with proper Indian Rupee formatting
  ///
  /// [value] - The monetary value to format
  /// [includeSymbol] - Whether to include ₹ symbol (default: true)
  /// [decimalPlaces] - Number of decimal places (default: 0 for whole rupees)
  /// Returns formatted currency string
  static String format(
    double value, {
    bool includeSymbol = true,
    int decimalPlaces = 0,
  }) {
    // Round to avoid floating point precision issues
    final roundedValue = double.parse(value.toStringAsFixed(decimalPlaces));
    
    // Convert to string and add commas for thousands
    String formatted = roundedValue.toStringAsFixed(decimalPlaces);
    
    // Add comma separators for thousands (Indian format: 1,00,000)
    if (decimalPlaces == 0) {
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
    
    // Add rupee symbol if requested
    if (includeSymbol) {
      return '₹$formatted';
    }
    
    return formatted;
  }

  /// Format currency with symbol and no decimal places (most common use case)
  static String formatRupees(double value) {
    return format(value, includeSymbol: true, decimalPlaces: 0);
  }

  /// Format currency without symbol (for table columns where symbol is in header)
  static String formatAmount(double value) {
    return format(value, includeSymbol: false, decimalPlaces: 0);
  }

  /// Format currency for display in financial statements
  static String formatFinancial(double value) {
    return format(value, includeSymbol: true, decimalPlaces: 2);
  }

  /// Format currency for charts and graphs (abbreviated format)
  static String formatAbbreviated(double value) {
    if (value >= 10000000) { // 1 crore
      return '₹${(value / 10000000).toStringAsFixed(1)}C';
    } else if (value >= 100000) { // 1 lakh
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) { // 1K
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }
    
    return formatRupees(value);
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
