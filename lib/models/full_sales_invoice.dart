// lib/models/full_sales_invoice.dart

import 'sale.dart';
import 'sale_item.dart';
import 'sun_collector.dart';
import 'sun_salesperson.dart';

class FullSalesInvoice {
  final Sale sale;
  final List<SaleItem> items;
  final SunCollector? collector;
  final SunSalesperson? agent;

  FullSalesInvoice({
    required this.sale,
    required this.items,
    this.collector,
    this.agent,
  });

  factory FullSalesInvoice.fromJson(Map<String, dynamic> json) {
    final Sale saleData = Sale.fromJson(json);
    final List<SaleItem> itemsList =
    (json['sale_items'] as List<dynamic>? ?? [])
        .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
        .toList();
    final SunCollector? collectorData =
    json['collector'] != null && json['collector'] is Map
        ? SunCollector.fromJson(json['collector'])
        : null;

    final SunSalesperson? agentData =
    json['agent'] != null && json['agent'] is Map
        ? SunSalesperson.fromJson(json['agent'])
        : null;

    return FullSalesInvoice(
      sale: saleData,
      items: itemsList,
      collector: collectorData,
      agent: agentData,
    );
  }
}