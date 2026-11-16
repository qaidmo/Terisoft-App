class CustomerActivityRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final int departmentId;
  final int currencyId;
  final int? userId;

  CustomerActivityRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    required this.departmentId,
    required this.currencyId,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'year': year,
      'branchId': branchId,
      'departmentId': departmentId,
      'currencyId': currencyId,
      'userId': userId,
    };
  }
}

class CustomerActivityItem {
  final String customerName;
  final String customerNo;
  final double totalSales;
  final double totalReturns;
  final double netSales;
  final double totalCollections;
  final double collectionPercentage;
  final double openingBalance;
  final double periodBalance;
  final double balancePercentage;
  final String lastInvoiceDate;
  final String lastPaymentDate;
  final int debtAge;

  CustomerActivityItem({
    required this.customerName,
    required this.customerNo,
    required this.totalSales,
    required this.totalReturns,
    required this.netSales,
    required this.totalCollections,
    required this.collectionPercentage,
    required this.openingBalance,
    required this.periodBalance,
    required this.balancePercentage,
    required this.lastInvoiceDate,
    required this.lastPaymentDate,
    required this.debtAge,
  });

  factory CustomerActivityItem.fromJson(Map<String, dynamic> json) {
    return CustomerActivityItem(
      customerName: json['customerName']?.toString() ?? '',
      customerNo: json['customerNo']?.toString() ?? '',
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalReturns: (json['totalReturns'] as num?)?.toDouble() ?? 0.0,
      netSales: (json['netSales'] as num?)?.toDouble() ?? 0.0,
      totalCollections: (json['totalCollections'] as num?)?.toDouble() ?? 0.0,
      collectionPercentage: (json['collectionPercentage'] as num?)?.toDouble() ?? 0.0,
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      periodBalance: (json['periodBalance'] as num?)?.toDouble() ?? 0.0,
      balancePercentage: (json['balancePercentage'] as num?)?.toDouble() ?? 0.0,
      lastInvoiceDate: json['lastInvoiceDate']?.toString() ?? '-',
      lastPaymentDate: json['lastPaymentDate']?.toString() ?? '-',
      debtAge: (json['debtAge'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerActivityResponse {
  final List<CustomerActivityItem> data;
  final double totalSalesAll;
  final double totalReturnsAll;
  final double totalCollectionsAll;

  CustomerActivityResponse({
    required this.data,
    required this.totalSalesAll,
    required this.totalReturnsAll,
    required this.totalCollectionsAll,
  });

  factory CustomerActivityResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List?;
    List<CustomerActivityItem> dataList = list != null
        ? list.map((i) => CustomerActivityItem.fromJson(i)).toList()
        : [];

    return CustomerActivityResponse(
      data: dataList,
      totalSalesAll: (json['totalSalesAll'] as num?)?.toDouble() ?? 0.0,
      totalReturnsAll: (json['totalReturnsAll'] as num?)?.toDouble() ?? 0.0,
      totalCollectionsAll: (json['totalCollectionsAll'] as num?)?.toDouble() ?? 0.0,
    );
  }
}