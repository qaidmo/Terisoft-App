import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sync_service.dart';

class SyncView extends StatelessWidget {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncService syncService = Get.find<SyncService>();

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
            ],
          ),
        ),
      ),
    );
  }
}