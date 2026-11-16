import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/reports_controller.dart';
import 'package:untitled4/models/menu_item.dart';

class ReportGroupScreen extends StatelessWidget {
  final ReportCategory category;

  const ReportGroupScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final ReportsController controller = Get.find<ReportsController>();
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.title),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: category.items.length,
        itemBuilder: (context, index) {
          final item = category.items[index];
          return _buildReportCard(context, item, controller);
        },
      ),
    );
  }

  Widget _buildReportCard(
      BuildContext context, MenuItem item, ReportsController controller) {
    final bool canAccess = controller.canAccessScreen(item.screenNameKey);

    return Opacity(
      opacity: canAccess ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => controller.onReportItemTap(item),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canAccess
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 32,
                    color: canAccess
                        ? const Color.fromARGB(255, 1, 90, 163)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: canAccess ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                if (!canAccess) ...[
                  const SizedBox(height: 8),
                  const Icon(Icons.lock, size: 16, color: Colors.grey),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}