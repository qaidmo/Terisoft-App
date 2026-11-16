class RestaurantInvoiceDetailModel {
  final int? id;
  final String invoiceNumber;
  final String itemId;
  final String itemName;
  final String? unit;
  final double quantity;
  final double price;
  final double total;
  final String? notes;
  final String? categoryName;
  final double discount;
  final double tax;

  RestaurantInvoiceDetailModel({
    this.id,
    required this.invoiceNumber,
    required this.itemId,
    required this.itemName,
    this.unit,
    this.quantity = 1.0,
    this.price = 0.0,
    this.total = 0.0,
    this.notes,
    this.categoryName,
    this.discount = 0.0,
    this.tax = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'itemId': itemId,
      'itemName': itemName,
      'unit': unit,
      'quantity': quantity,
      'price': price,
      'total': total,
      'notes': notes,
      'categoryName': categoryName,
      'discount': discount,
      'tax': tax,
    };
  }
}

class RestaurantInvoiceModel {
  final int? id;
  final String invoiceNumber;
  final String? orderNumber;
  final String? tableNumber;
  final String transactionDate;
  final String yearId;
  final String userId;
  final String? userName;
  final String? branchId;
  final String? sectionId;
  final String? storeId;
  final String? storeName;
  final String? currencyId;
  final String? currencyName;
  final double currencyValue;
  final double discount;
  final double tax;
  final double total;
  final double netTotal;
  final String? orderTypeId;
  final String? netTotalInWords;
  final String traLstId;
  final String? traTitle;
  final String? customerName;
  final int isNetworkPayment;
  final double paidAmount;
  final String? boxId;
  final String? boxNo;
  final String? boxName;
  final String? boxParentName;
  final String? notes;
  final int isSynced;
  final List<RestaurantInvoiceDetailModel> details;

  RestaurantInvoiceModel({
    this.id,
    required this.invoiceNumber,
    this.orderNumber,
    this.tableNumber,
    required this.transactionDate,
    required this.yearId,
    required this.userId,
    this.userName,
    this.branchId,
    this.sectionId,
    this.storeId,
    this.storeName,
    this.currencyId,
    this.currencyName,
    this.currencyValue = 1.0,
    this.discount = 0.0,
    this.tax = 0.0,
    this.total = 0.0,
    this.netTotal = 0.0,
    this.orderTypeId = '0',
    this.netTotalInWords,
    required this.traLstId,
    this.traTitle,
    this.customerName,
    this.isNetworkPayment = 0,
    this.paidAmount = 0.0,
    this.boxId,
    this.boxNo,
    this.boxName,
    this.boxParentName,
    this.notes,
    this.isSynced = 0,
    this.details = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'orderNumber': orderNumber,
      'tableNumber': tableNumber,
      'transactionDate': transactionDate,
      'yearId': yearId,
      'userId': userId,
      'userName': userName,
      'branchId': branchId,
      'sectionId': sectionId,
      'storeId': storeId,
      'storeName': storeName,
      'currencyId': currencyId,
      'currencyName': currencyName,
      'currencyValue': currencyValue,
      'discount': discount,
      'tax': tax,
      'total': total,
      'netTotal': netTotal,
      'orderTypeId': orderTypeId,
      'netTotalInWords': netTotalInWords,
      'traLstId': traLstId,
      'traTitle': traTitle,
      'customerName': customerName,
      'isNetworkPayment': isNetworkPayment,
      'paidAmount': paidAmount,
      'boxId': boxId,
      'boxNo': boxNo,
      'boxName': boxName,
      'boxParentName': boxParentName,
      'notes': notes,
      'is_synced': isSynced,
    };
  }
}
