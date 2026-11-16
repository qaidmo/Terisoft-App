import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/account_controller.dart';
import 'package:untitled4/models/sun_account_model.dart';

// ------------------------------------------------------------------
// الصفحة الرئيسية
// ------------------------------------------------------------------

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We ensure the controller is available for the widgets below
    Get.put(AccountController());

    return Scaffold(
      appBar: AppBar(title: const Text('دليل الحسابات '), elevation: 1),
      body: const Column(
        children: [
          // تم توسيع شجرة الحسابات لتأخذ كامل مساحة الجسم
          Expanded(
            child: Card(
              elevation: 2,
              margin: EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              child: _AccountTreeViewWidget(),
            ),
          ),
          // تم حذف الجزء الذي كان يحتوي على النموذج (`_UnifiedAccountForm`)
        ],
      ),
      // تم استبدال شريط الأزرار القديم بالشريط الجديد والمبسط
      bottomNavigationBar: const _ActionButtonsBarReadOnly(),
    );
  }
}

// ------------------------------------------------------------------
// ويدجت شجرة الحسابات
// ------------------------------------------------------------------

class _AccountTreeViewWidget extends StatelessWidget {
  const _AccountTreeViewWidget();
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AccountController>();
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.treeController.roots.isEmpty) {
        return const Center(child: Text('لا توجد حسابات.'));
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: SizedBox(
          // زيادة العرض الافتراضي لتجنب مشاكل التخطيط الأفقي
          width: MediaQuery.of(context).size.width * 1.5,
          child: TreeView<SunAccount>(
            treeController: controller.treeController,
            nodeBuilder: (BuildContext context, TreeEntry<SunAccount> entry) {
              final account = entry.node;
              final isSelected =
                  controller.selectedAccount.value?.id == account.id;

              return TreeIndentation(
                entry: entry,
                child: InkWell(
                  onTap: () => controller.selectAccount(account),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 6.0, horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (account.isTransactional)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.receipt_long,
                              color: Color(0xFF00695C),
                              size: 20,
                            ),
                          )
                        else
                          FolderButton(
                            isOpen: entry.isExpanded,
                            onPressed: entry.hasChildren
                                ? () => controller.treeController
                                .toggleExpansion(entry.node)
                                : null,
                            icon: const Icon(
                                Icons.folder_outlined,
                                color: Color(0xFF00695C)
                            ),
                            openedIcon: Icon(
                              Icons.folder_open_outlined,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        const SizedBox(width: 8),

                        Flexible(
                          child: Text(
                            '${account.accountNumber} - ${account.name}',
                            style: TextStyle(
                              fontWeight: account.isTransactional
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

// ------------------------------------------------------------------
// شريط الأزرار (القراءة والبحث والطباعة فقط)
// ------------------------------------------------------------------

class _ActionButtonsBarReadOnly extends StatelessWidget {
  const _ActionButtonsBarReadOnly();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AccountController>();
    return Container(
      padding: EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        top: 12.0,
        bottom: MediaQuery.of(context).padding.bottom + 12.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // توزيع الأزرار بالتساوي
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: controller.printAccounts,
                icon: const Icon(Icons.print),
                label: const Text('طباعة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50), // ارتفاع موحد
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: controller.showSearchDialog,
                icon: const Icon(Icons.search),
                label: const Text('بحث'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50), // ارتفاع موحد
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// ويدجت نافذة البحث المنبثقة
// ------------------------------------------------------------------

class AccountSearchDialog extends StatelessWidget {
  const AccountSearchDialog();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AccountController>();

    return AlertDialog(
      title: const Text('بحث عن حساب'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // --- حقل البحث ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.searchAccounts,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'ابحث بالرقم أو الاسم',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.searchController.clear();
                      controller.searchAccounts('');
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- جدول عرض النتائج ---
            Expanded(
              child: Obx(() {
                if (controller.searchResults.isEmpty) {
                  return const Center(child: Text('لا توجد نتائج مطابقة'));
                }
                return SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            showCheckboxColumn: false,
                            border: TableBorder.all(width: 1.0, color: Colors.grey.shade300),
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text('رقم الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('اسم الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('الاسم الأجنبي', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('حساب الأب', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: controller.searchResults.map((account) {
                              return DataRow(
                                onSelectChanged: (isSelected) {
                                  if (isSelected ?? false) {
                                    controller.selectAccount(account);
                                    Get.back();
                                  }
                                },
                                cells: [
                                  DataCell(Text(account.accountNumber)),
                                  DataCell(Text(account.name)),
                                  DataCell(Text(account.nameEn ?? '')),
                                  DataCell(Text(controller.getParentAccountNumber(account))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
      ],
    );
  }
}

// ------------------------------------------------------------------
// الدوال المساعدة (تم حذف الدوال غير المستخدمة)
// ------------------------------------------------------------------

// تم حذف الدوال المساعدة: _buildReadOnlyTextField و _buildCurrencyDropdown
// لأنهما كانتا جزءاً من نموذج الإدخال الذي تم إزالته.