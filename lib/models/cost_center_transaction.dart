// lib/models/cost_center_transaction.dart

class CostCenterTransaction {
  final String transactionDate;
  final String transactionRef;
  final String description;
  final String transactionType;
  final String accountNumber;
  final String accountName;
  final double debit;
  final double credit;
  final double balance;

  // Pre-formatted strings for instant virtualized table rendering
  final String debitStr;
  final String creditStr;
  final String balanceStr;

  CostCenterTransaction({
    required this.transactionDate,
    required this.transactionRef,
    required this.description,
    required this.transactionType,
    required this.accountNumber,
    required this.accountName,
    required this.debit,
    required this.credit,
    required this.balance,
    this.debitStr = '',
    this.creditStr = '',
    this.balanceStr = '',
  });

  factory CostCenterTransaction.fromResponse(Map<String, dynamic> response, double runningBalance) {
    final accountData = response['sun_account'];
    final double debitAmount = (response['debit'] as num?)?.toDouble() ?? 0.0;
    final double creditAmount = (response['credit'] as num?)?.toDouble() ?? 0.0;

    return CostCenterTransaction(
      transactionDate: response['transaction_date']?.toString() ?? '',
      transactionRef: response['transaction_ref'] ?? 'N/A',
      description: response['description'] ?? '',
      transactionType: response['transaction_type'] ?? '',
      accountNumber: response['account_number'] ?? ((accountData != null && accountData is Map) ? accountData['account_number'] ?? 'N/A' : 'N/A'),
      accountName: response['account_name'] ?? ((accountData != null && accountData is Map) ? accountData['name'] ?? 'حساب غير معروف' : 'حساب غير معروف'),
      debit: debitAmount,
      credit: creditAmount,
      balance: runningBalance,
      debitStr: debitAmount.toStringAsFixed(2),
      creditStr: creditAmount.toStringAsFixed(2),
      balanceStr: runningBalance.toStringAsFixed(2),
    );
  }
}