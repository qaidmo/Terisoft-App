import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/report_pre_sync_service.dart';
import '../services/sync_service.dart';
import '../user_state.dart';

class SyncView extends StatelessWidget {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncService syncService = Get.find<SyncService>();
    final ReportPreSyncService reportSyncService =
        Get.isRegistered<ReportPreSyncService>()
            ? Get.find<ReportPreSyncService>()
            : Get.put(ReportPreSyncService());
    final UserState userState = Get.find<UserState>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('مزامنة بيانات النظام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Obx(() => Icon(
                syncService.isSyncing.value ? Icons.sync : Icons.cloud_done_rounded,
                size: 100,
                color: syncService.isSyncing.value ? Colors.blue : Colors.green,
              )),
              const SizedBox(height: 30),

              Obx(() => Text(
                "${(syncService.progressValue.value * 100).toInt()}%",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              )),
              const SizedBox(height: 20),

              Obx(() => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: syncService.progressValue.value,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                ),
              )),
              const SizedBox(height: 25),

              Obx(() => Text(
                syncService.currentTask.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              )),
              const SizedBox(height: 50),

              Obx(() => ElevatedButton.icon(
                onPressed: syncService.isSyncing.value
                    ? null
                    : () => syncService.syncAllMasterData(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('بدء مزامنة البيانات الآن', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              )),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              // --- قسم مزامنة التقارير للعمل بدون اتصال (Step 4) ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.offline_pin_rounded, color: Colors.teal.shade700, size: 28),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'مزامنة التقارير للعمل بدون اتصال',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يقوم بتنزيل تقارير وحركات السنة المالية كاملة لتتمكن من اختيار أي مدة زمنية واستعراضها بدون إنترنت.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        if (reportSyncService.isSyncing.value ||
                            reportSyncService.completedItems.value > 0) {
                          return Column(
                            children: [
                              LinearProgressIndicator(
                                value: reportSyncService.progress.value,
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(reportSyncService.progress.value * 100).toInt()}%  (${reportSyncService.completedItems.value} / ${reportSyncService.totalItems.value})',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reportSyncService.currentTask.value,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      Obx(() => ElevatedButton.icon(
                            onPressed: syncService.isSyncing.value
                                ? null
                                : () {
                                    if (reportSyncService.isSyncing.value) {
                                      reportSyncService.cancelSync();
                                    } else {
                                      String year = userState.safeFinancialYearName;
                                      if (year == 'غير محددة' || year.isEmpty) {
                                        year = DateTime.now().year.toString();
                                      }
                                      reportSyncService.syncAllReportsForOffline(
                                        year: year,
                                        branchId: userState.isAdmin
                                            ? null
                                            : (userState.safeUserBranch > 0
                                                ? userState.safeUserBranch
                                                : null),
                                        departmentId: userState.isAdmin
                                            ? null
                                            : (userState.safeUserDepartment > 0
                                                ? userState.safeUserDepartment
                                                : null),
                                      );
                                    }
                                  },
                            icon: Icon(reportSyncService.isSyncing.value
                                ? Icons.stop_rounded
                                : Icons.download_for_offline_rounded),
                            label: Text(
                              reportSyncService.isSyncing.value
                                  ? 'إيقاف مزامنة التقارير'
                                  : 'تنزيل وتحديث كل التقارير (أوفلاين)',
                              style: const TextStyle(fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: reportSyncService.isSyncing.value
                                  ? Colors.red.shade700
                                  : Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}