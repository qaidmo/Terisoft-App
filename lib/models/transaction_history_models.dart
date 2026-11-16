class TransactionHistoryRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final String transactionType;
  final int? userId;
  final int? departmentId;

  TransactionHistoryRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    required this.transactionType,
    this.userId,
    this.departmentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'year': year,
      'branchId': branchId,
      'transactionType': transactionType,
      'userId': userId,
      'departmentId': departmentId,
    };
  }
}

class TransactionHistoryItem {
  final String transactionId;
  final String transactionNumber;
  final String referenceNumber;
  final String date;
  final String time;
  final String customerName;
  final double netTotal;
  final String userName;
  final String transactionTypeId;
  final String transactionTypeName;

  TransactionHistoryItem({
    required this.transactionId,
    required this.transactionNumber,
    required this.referenceNumber,
    required this.date,
    required this.time,
    required this.customerName,
    required this.netTotal,
    required this.userName,
    required this.transactionTypeId,
    required this.transactionTypeName,
  });

  factory TransactionHistoryItem.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryItem(
      transactionId: json['transactionId']?.toString() ?? '',
      transactionNumber: json['transactionNumber']?.toString() ?? '',
      referenceNumber: json['referenceNumber']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      netTotal: (json['netTotal'] as num?)?.toDouble() ?? 0.0,
      userName: json['userName']?.toString() ?? '',
      transactionTypeId: json['transactionTypeId']?.toString() ?? '',
      transactionTypeName: json['transactionTypeName']?.toString() ?? '',
    );
  }
}

class TransactionHistoryResponse {
  final double grandTotal;
  final int itemsCount;
  final List<TransactionHistoryItem> transactions;

  TransactionHistoryResponse({
    required this.grandTotal,
    required this.itemsCount,
    required this.transactions,
  });

  factory TransactionHistoryResponse.fromJson(Map<String, dynamic> json) {
    var list = json['transactions'] as List?;
    List<TransactionHistoryItem> transactionsList = list != null
        ? list.map((i) => TransactionHistoryItem.fromJson(i)).toList()
        : [];

    return TransactionHistoryResponse(
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
      transactions: transactionsList,
    );
  }
}