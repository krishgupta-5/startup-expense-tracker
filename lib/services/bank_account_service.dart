import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing bank accounts with production-grade subcollection model
///
/// Uses stable IDs from Firestore subcollection instead of fragile array-based
/// matching for proper fintech architecture.
class BankAccountService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔥 PRODUCTION FIX: Get all bank accounts from subcollection with stable IDs
  static Future<List<Map<String, dynamic>>> getBankAccounts() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Try subcollection first (new model)
      final bankAccountsSnapshot = await _firestore
          .collection("companies")
          .doc(user.uid)
          .collection("bankAccounts")
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      if (bankAccountsSnapshot.docs.isNotEmpty) {
        return bankAccountsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': data['id'] ?? doc.id,
            'name': data['name'] ?? 'Unknown Bank',
            'number': data['number'] ?? '',
            'last4': data['last4'] ?? '',
            'maskedNumber':
                data['maskedNumber'] ??
                _maskAccountNumber(data['number'] ?? ''),
            'createdAt': data['createdAt'],
            'isActive': data['isActive'] ?? true,
          };
        }).toList();
      }

      // Fallback: Check for legacy array-based accounts and migrate
      return await _migrateLegacyBankAccounts(user.uid);
    } catch (e) {
      throw Exception('Failed to fetch bank accounts: $e');
    }
  }

  /// 🔥 PRODUCTION FIX: Calculate spending for each bank account using stable ID matching
  static Future<List<Map<String, dynamic>>> getBankAccountsWithSpending(
    List<Map<String, dynamic>> expenses,
  ) async {
    final bankAccounts = await getBankAccounts();

    // Initialize spending map with stable IDs
    final Map<String, double> bankSpending = {};
    for (var account in bankAccounts) {
      bankSpending[account['id']] = 0.0;
    }

    // Calculate actual spending for each bank account from expenses
    for (var expense in expenses) {
      final amount = expense['amount'] as double;
      final expenseBankAccount = expense['bankAccount'] as String?;

      if (expenseBankAccount != null) {
        // Try stable ID match first (new format)
        final matchedAccount = bankAccounts.firstWhere(
          (account) => account['id'] == expenseBankAccount,
          orElse: () =>
              _findAccountByLegacyKey(bankAccounts, expenseBankAccount),
        );

        if (matchedAccount['id'] != null) {
          // 🔥 PRODUCTION FIX: Only count real outflows (positive amounts)
          // Exclude refunds, revenue, and credits from "total spent"
          if (amount > 0) {
            bankSpending[matchedAccount['id']] =
                (bankSpending[matchedAccount['id']] ?? 0.0) + amount;
          }
        }
      }
    }

    // Return bank accounts with calculated spending
    return bankAccounts.map((account) {
      return {...account, 'totalSpent': bankSpending[account['id']] ?? 0.0};
    }).toList();
  }

  /// 🔥 PRODUCTION FIX: Migrate expense bank account references to stable IDs
  static Future<void> migrateExpenseBankAccountReferences() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get all bank accounts with stable IDs
      final bankAccounts = await getBankAccounts();

      // Get all expenses
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .get();

      // Batch update expenses to use stable IDs
      final batch = _firestore.batch();

      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final currentBankAccount = data['BankAccount'] as String?;

        if (currentBankAccount != null) {
          // Find matching bank account
          final matchedAccount = bankAccounts.firstWhere(
            (account) => account['legacyKey'] == currentBankAccount,
            orElse: () => {'id': null},
          );

          if (matchedAccount['id'] != null) {
            // Update to use stable ID
            batch.update(doc.reference, {
              'BankAccount': matchedAccount['id'],
              'bankAccountId': matchedAccount['id'], // New field for clarity
            });
          }
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to migrate expense bank references: $e');
    }
  }

  /// 🔥 PRODUCTION FIX: Migrate legacy array-based bank accounts to subcollection
  static Future<List<Map<String, dynamic>>> _migrateLegacyBankAccounts(
    String uid,
  ) async {
    try {
      final docSnapshot = await _firestore
          .collection("companies")
          .doc(uid)
          .get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return [];
      }

      final data = docSnapshot.data()!;
      final bankAccountsData = data["Bank Accounts"] as List<dynamic>? ?? [];

      if (bankAccountsData.isEmpty) {
        return [];
      }

      // Migrate to subcollection
      final batch = _firestore.batch();
      final List<Map<String, dynamic>> migratedAccounts = [];

      for (var account in bankAccountsData) {
        final bankName = account["name"] ?? 'Unknown Bank';
        final accountNumber = account["number"] ?? '';

        // Create new subcollection document
        final bankRef = _firestore
            .collection("companies")
            .doc(uid)
            .collection("bankAccounts")
            .doc();

        final bankData = {
          "id": bankRef.id,
          "name": _normalizeBankName(bankName),
          "number": accountNumber,
          "last4": accountNumber.length >= 4
              ? accountNumber.substring(accountNumber.length - 4)
              : accountNumber,
          "maskedNumber": _maskAccountNumber(accountNumber),
          "createdAt": FieldValue.serverTimestamp(),
          "isActive": true,
          "legacyKey": "$bankName-$accountNumber", // Keep for migration
        };

        batch.set(bankRef, bankData);
        migratedAccounts.add(bankData);
      }

      // Commit migration
      await batch.commit();

      // Optionally clean up legacy array after successful migration
      // await _firestore.collection("companies").doc(uid).update({
      //   "Bank Accounts": FieldValue.delete(),
      // });

      return migratedAccounts;
    } catch (e) {
      print("Migration failed: $e");
      return [];
    }
  }

  /// 🔥 PRODUCTION FIX: Normalize bank name to prevent duplicates
  static String _normalizeBankName(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Find account by legacy key for backward compatibility
  static Map<String, dynamic> _findAccountByLegacyKey(
    List<Map<String, dynamic>> accounts,
    String legacyKey,
  ) {
    try {
      return accounts.firstWhere(
        (account) => account['legacyKey'] == legacyKey,
        orElse: () => {'id': null},
      );
    } catch (e) {
      return {'id': null};
    }
  }

  /// Mask account number for display
  static String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return accountNumber.substring(0, 2) +
        '*' * (accountNumber.length - 4) +
        accountNumber.substring(accountNumber.length - 2);
  }

  /// Format currency consistently across the app
  static String formatCurrency(double value) {
    return "₹${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}";
  }
}
