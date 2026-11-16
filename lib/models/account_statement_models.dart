import 'dart:convert';
import 'package:intl/intl.dart';

class AccountStatementRequest {
  final String accountId;
  final int currencyId;
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final int? departmentId;
  final String? ledgerSignature;

  AccountStatementRequest({
    required this.accountId,
    required this.currencyId,
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.departmentId,
    this.ledgerSignature,
  });

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'currencyId': currencyId,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'year': year,
      'branchId': branchId,
      'departmentId': departmentId,
      if (ledgerSignature != null) 'ledgerSignature': ledgerSignature,
    };
  }
}

class StatementTransaction {
  final String traId;
  final String traNo;
  final String date;
  final String type;
  final String description;
  final String beneficiary;
  final double debit;
  final double credit;
  double? balance;

  StatementTransaction({
    required this.traId,
    required this.traNo,
    required this.date,
    required this.type,
    required this.description,
    required this.beneficiary,
    required this.debit,
    required this.credit,
    this.balance,
  });

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    return StatementTransaction(
      traId: json['traId']?.toString() ?? '',
      traNo: json['traNo']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      beneficiary: json['beneficiary']?.toString() ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AccountStatementResponse {
  final double openingBalance;
  final double closingBalance;
  final double totalPeriodDebit;
  final double totalPeriodCredit;
  final String? ledgerSignature;
  final List<StatementTransaction> transactions;

  AccountStatementResponse({
    required this.openingBalance,
    required this.closingBalance,
    required this.totalPeriodDebit,
    required this.totalPeriodCredit,
    this.ledgerSignature,
    required this.transactions,
  });

  factory AccountStatementResponse.fromJson(Map<String, dynamic> json) {
    var list = json['transactions'] as List?;
    List<StatementTransaction> transactionsList = list != null
        ? list.map((i) => StatementTransaction.fromJson(i)).toList()
        : [];

    return AccountStatementResponse(
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (json['closingBalance'] as num?)?.toDouble() ?? 0.0,
      totalPeriodDebit: (json['totalPeriodDebit'] as num?)?.toDouble() ?? 0.0,
      totalPeriodCredit: (json['totalPeriodCredit'] as num?)?.toDouble() ?? 0.0,
      ledgerSignature: json['ledgerSignature']?.toString(),
      transactions: transactionsList,
    );
  }
}

/// نموذج العرض المزدوج لسطر كشف الحساب
/// يجمع بين القيم الرقمية الخام (للفلاتر والمجاميع والـ PDF) والنصوص مسبقة التنسيق (للعرض الفوري 60 FPS)
class StatementRowDisplayModel {
  // 1. البيانات الرقمية والأصلية الخام (Raw & Original Values)
  final String traId;
  final String traNo;
  final DateTime? parsedDate;
  final String rawDate;
  final String type;
  final String description;
  final String beneficiary;
  final double debit;
  final double credit;
  final double balance;

  // 2. النصوص مسبقة التنسيق للعرض السريع (Pre-formatted Display Strings)
  final int index;
  final String debitStr;
  final String creditStr;
  final String balanceStr;
  final String dateStr;
  final String traNoStr;
  final String typeStr;
  final String beneficiaryStr;
  final String descriptionStr;

  StatementRowDisplayModel({
    required this.traId,
    required this.traNo,
    required this.parsedDate,
    required this.rawDate,
    required this.type,
    required this.description,
    required this.beneficiary,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.index,
    required this.debitStr,
    required this.creditStr,
    required this.balanceStr,
    required this.dateStr,
    required this.traNoStr,
    required this.typeStr,
    required this.beneficiaryStr,
    required this.descriptionStr,
  });

  /// خريطة البيانات للتوافق التام 100% مع محرك طباعة وتصدير الـ PDF
  Map<String, dynamic> toMap() {
    return {
      'traId': traId,
      'traNo': traNo,
      'date': dateStr,
      'type': type,
      'description': description,
      'beneficiary': beneficiary,
      'debit': debit,
      'credit': credit,
      'balance': balance,
    };
  }
}

/// معاملات المعالجة في الـ Isolate
class StatementProcessingParams {
  final String? rawJson;
  final AccountStatementResponse? response;
  final DateTime fromDate;
  final DateTime toDate;
  final bool isOfflineSlicing;

  StatementProcessingParams({
    this.rawJson,
    this.response,
    required this.fromDate,
    required this.toDate,
    required this.isOfflineSlicing,
  });
}

/// نتائج المعالجة المحسوبة داخل الـ Isolate
class StatementProcessingResult {
  final List<StatementRowDisplayModel> rows;
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final String? ledgerSignature;
  final double closingBalance;

  StatementProcessingResult({
    required this.rows,
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    this.ledgerSignature,
    required this.closingBalance,
  });
}

/// دالة Top-level تُنفذ بالكامل داخل compute() Isolate
/// تقوم بفك تشفير JSON، وتصفية التواريخ، وحساب الرصيد التراكمي وتنسيق الأرقام دون لمس الـ Main UI Thread
StatementProcessingResult isolateProcessAccountStatement(StatementProcessingParams params) {
  AccountStatementResponse res;
  if (params.rawJson != null) {
    final Map<String, dynamic> jsonMap = jsonDecode(params.rawJson!);
    res = AccountStatementResponse.fromJson(jsonMap);
  } else if (params.response != null) {
    res = params.response!;
  } else {
    throw ArgumentError('Either rawJson or response must be provided.');
  }

  final NumberFormat numberFormat = NumberFormat("#,##0.##");

  DateTime? parseDate(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        var parts = dateStr.split('/');
        if (parts.length == 3) {
          int d = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          int y = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  if (params.isOfflineSlicing) {
    // 1. استبعاد سطر "رصيد مرحل" المضاف لتفادي الازدواجية
    final realTransactions = res.transactions
        .where((tx) => tx.type != 'رصيد مرحل')
        .toList();

    double newOpeningBalance = res.openingBalance;
    final reqStart = params.fromDate;
    final reqEnd = params.toDate.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    final List<StatementTransaction> slicedTransactions = [];

    for (var tx in realTransactions) {
      final txDate = parseDate(tx.date);
      if (txDate == null) continue;

      if (txDate.isBefore(reqStart)) {
        newOpeningBalance += (tx.debit - tx.credit);
      } else if (!txDate.isAfter(reqEnd)) {
        slicedTransactions.add(tx);
      }
    }

    final List<StatementRowDisplayModel> displayRows = [];
    double currentBalance = newOpeningBalance;
    double periodDebit = 0.0;
    double periodCredit = 0.0;
    int indexCounter = 1;

    // إضافة سطر رصيد مرحل إذا وجد رصيد افتتاحي
    if (newOpeningBalance != 0) {
      final displayDate = reqStart.subtract(const Duration(days: 1));
      final formattedDate =
          '${displayDate.day.toString().padLeft(2, '0')}/'
          '${displayDate.month.toString().padLeft(2, '0')}/'
          '${displayDate.year}';

      final oDebit = newOpeningBalance > 0 ? newOpeningBalance : 0.0;
      final oCredit = newOpeningBalance < 0 ? newOpeningBalance.abs() : 0.0;

      displayRows.add(StatementRowDisplayModel(
        traId: '',
        traNo: '0',
        parsedDate: displayDate,
        rawDate: formattedDate,
        type: 'رصيد مرحل',
        description: 'رصيد مرحل',
        beneficiary: '',
        debit: oDebit,
        credit: oCredit,
        balance: newOpeningBalance,
        index: indexCounter++,
        debitStr: oDebit > 0 ? numberFormat.format(oDebit) : '',
        creditStr: oCredit > 0 ? numberFormat.format(oCredit) : '',
        balanceStr: numberFormat.format(newOpeningBalance),
        dateStr: formattedDate,
        traNoStr: '0',
        typeStr: 'رصيد مرحل',
        beneficiaryStr: '',
        descriptionStr: 'رصيد مرحل',
      ));
    }

    for (var tx in slicedTransactions) {
      currentBalance += (tx.debit - tx.credit);
      periodDebit += tx.debit;
      periodCredit += tx.credit;

      final pDate = parseDate(tx.date);
      final dateStr = pDate != null
          ? '${pDate.day.toString().padLeft(2, '0')}/${pDate.month.toString().padLeft(2, '0')}/${pDate.year}'
          : tx.date;

      displayRows.add(StatementRowDisplayModel(
        traId: tx.traId,
        traNo: tx.traNo,
        parsedDate: pDate,
        rawDate: tx.date,
        type: tx.type,
        description: tx.description,
        beneficiary: tx.beneficiary,
        debit: tx.debit,
        credit: tx.credit,
        balance: currentBalance,
        index: indexCounter++,
        debitStr: tx.debit > 0 ? numberFormat.format(tx.debit) : '',
        creditStr: tx.credit > 0 ? numberFormat.format(tx.credit) : '',
        balanceStr: numberFormat.format(currentBalance),
        dateStr: dateStr,
        traNoStr: tx.traNo,
        typeStr: tx.type,
        beneficiaryStr: tx.beneficiary,
        descriptionStr: tx.description,
      ));
    }

    return StatementProcessingResult(
      rows: displayRows,
      openingBalance: newOpeningBalance,
      totalDebit: periodDebit,
      totalCredit: periodCredit,
      closingBalance: currentBalance,
      ledgerSignature: res.ledgerSignature,
    );
  } else {
    // 2. معالجة الرد المباشر (200 OK)
    final List<StatementRowDisplayModel> displayRows = [];
    double currentBalance = res.openingBalance;
    double periodDebit = 0.0;
    double periodCredit = 0.0;
    int indexCounter = 1;

    for (var tx in res.transactions) {
      final pDate = parseDate(tx.date);
      final dateStr = pDate != null
          ? '${pDate.day.toString().padLeft(2, '0')}/${pDate.month.toString().padLeft(2, '0')}/${pDate.year}'
          : tx.date;

      if (tx.type == 'رصيد مرحل') {
        final bal = tx.balance ?? res.openingBalance;
        displayRows.add(StatementRowDisplayModel(
          traId: tx.traId,
          traNo: tx.traNo.isNotEmpty ? tx.traNo : '0',
          parsedDate: pDate,
          rawDate: tx.date,
          type: tx.type,
          description: tx.description,
          beneficiary: tx.beneficiary,
          debit: tx.debit,
          credit: tx.credit,
          balance: bal,
          index: indexCounter++,
          debitStr: tx.debit > 0 ? numberFormat.format(tx.debit) : '',
          creditStr: tx.credit > 0 ? numberFormat.format(tx.credit) : '',
          balanceStr: numberFormat.format(bal),
          dateStr: dateStr,
          traNoStr: tx.traNo,
          typeStr: tx.type,
          beneficiaryStr: tx.beneficiary,
          descriptionStr: tx.description,
        ));
      } else {
        periodDebit += tx.debit;
        periodCredit += tx.credit;
        currentBalance = tx.balance ?? (currentBalance + tx.debit - tx.credit);

        displayRows.add(StatementRowDisplayModel(
          traId: tx.traId,
          traNo: tx.traNo,
          parsedDate: pDate,
          rawDate: tx.date,
          type: tx.type,
          description: tx.description,
          beneficiary: tx.beneficiary,
          debit: tx.debit,
          credit: tx.credit,
          balance: currentBalance,
          index: indexCounter++,
          debitStr: tx.debit > 0 ? numberFormat.format(tx.debit) : '',
          creditStr: tx.credit > 0 ? numberFormat.format(tx.credit) : '',
          balanceStr: numberFormat.format(currentBalance),
          dateStr: dateStr,
          traNoStr: tx.traNo,
          typeStr: tx.type,
          beneficiaryStr: tx.beneficiary,
          descriptionStr: tx.description,
        ));
      }
    }

    return StatementProcessingResult(
      rows: displayRows,
      openingBalance: res.openingBalance,
      totalDebit: res.totalPeriodDebit > 0 ? res.totalPeriodDebit : periodDebit,
      totalCredit: res.totalPeriodCredit > 0 ? res.totalPeriodCredit : periodCredit,
      closingBalance: res.closingBalance != 0 ? res.closingBalance : currentBalance,
      ledgerSignature: res.ledgerSignature,
    );
  }
}