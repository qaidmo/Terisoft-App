import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/database_helper.dart';
import '../../utils/snackbar_helper.dart';

class InvoiceTemplatesController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final RxList<Map<String, dynamic>> _invoiceTemplates = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  final List<Map<String, String>> staticAvailableScreens = const [
    {'display': 'شاشة سند صرف نقداً', 'identifier': 'CashPaymentVoucherScreen'},
    {'display': 'شاشة بيع نقداً', 'identifier': 'CashSaleScreen'},
    {'display': 'شاشة سجل الحركات', 'identifier': 'SalesMovementScreen'},
    {'display': 'شاشة سند قبض نقداً', 'identifier': 'ReceiptScreen'},
    {'display': 'شاشة بيع نقداً معلق', 'identifier': 'AbsoluteCashSaleScreen'},
    {'display': 'شاشة مردود البيع الآجل', 'identifier': 'CreditSaleReturnScreen'},
    {'display': 'شاشة بيع أجل', 'identifier': 'CreditSaleScreen'},
    {'display': 'شاشة كشف الحساب', 'identifier': 'AccountStatementScreen'},
    {'display': 'شاشة حركة العملاء', 'identifier': 'ClientsMovementScreen'},
    {'display': 'شاشة مردود البيع نقداً', 'identifier': 'CashSaleReturnScreen'},
    {'display': 'شاشة مراكز التكلفة', 'identifier': 'CostCenterScreen'},
    {'display': 'شاشة مردود البيع المعلق', 'identifier': 'AbsoluteCashSaleReturnScreen'},
    {'display': 'شاشة مطاعم', 'identifier': 'RestaurantPosScreen'},
    {'display': 'شاشة حركة المبيعات ', 'identifier': 'SalesMovementNewScreen'},
    {'display': 'شاشة حركة الموردين', 'identifier': 'SupplierMovementScreen'},
    {'display': 'شاشة أرصدة الأصناف', 'identifier': 'ItemBalancesScreen'},
    {'display': 'شاشة حركة الأصناف', 'identifier': 'ItemMovementScreen'},
    {'display': 'شاشة هامش الربح', 'identifier': 'ProfitMarginScreen'},
    {'display': 'شاشة بطاقة الصنف', 'identifier': 'ItemCardScreen'},

  ];

  final Rxn<Map<String, dynamic>> selectedTemplate = Rxn<Map<String, dynamic>>();

  late TextEditingController companyNameController;
  late TextEditingController thanksMessageController;
  late TextEditingController contactInfoController;
  late TextEditingController addressDetailsController;

  final RxBool showLogo = true.obs;
  final RxString currentLogoUrl = ''.obs;
  final Rxn<Uint8List> _pickedLogoBytes = Rxn<Uint8List>();
  Uint8List? get pickedLogoBytes => _pickedLogoBytes.value;

  final RxString selectedScreenIdentifier = ''.obs;

  @override
  void onInit() {
    super.onInit();
    companyNameController = TextEditingController();
    thanksMessageController = TextEditingController();
    contactInfoController = TextEditingController();
    addressDetailsController = TextEditingController();
  }

  @override
  void onReady() {
    super.onReady();
    fetchInvoiceTemplates();
  }

  @override
  void onClose() {
    companyNameController.dispose();
    thanksMessageController.dispose();
    contactInfoController.dispose();
    addressDetailsController.dispose();
    super.onClose();
  }

  Future<void> fetchInvoiceTemplates() async {
    if (_invoiceTemplates.isNotEmpty && !isLoading.value) {
      return;
    }

    isLoading.value = true;
    try {
      final List<Map<String, dynamic>> response = await _dbHelper.queryAll(
          'invoice_templates',
          orderBy: 'template_display_name ASC'
      );

      _invoiceTemplates.assignAll(response);

      if (_invoiceTemplates.isNotEmpty && selectedTemplate.value == null) {
        selectTemplate(_invoiceTemplates.first['screen_name_identifier']);
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل جلب قوالب الفواتير', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void selectTemplate(String identifier) {
    final template = _invoiceTemplates.firstWhereOrNull(
            (tpl) => tpl['screen_name_identifier'] == identifier);

    if (template != null) {
      selectedTemplate.value = template;
      selectedScreenIdentifier.value = identifier;

      Map<String, dynamic> settingsMap;
      if (template['settings_json'] is String) {
        try {
          settingsMap = jsonDecode(template['settings_json']);
        } catch (e) {
          settingsMap = {};
        }
      } else {
        settingsMap = template['settings_json'] ?? {};
      }

      _loadSettingsIntoControllers(settingsMap);
    } else {
      final screenInfo = staticAvailableScreens.firstWhereOrNull(
              (screen) => screen['identifier'] == identifier);

      if (screenInfo != null) {
        selectedTemplate.value = {
          'template_display_name': screenInfo['display']!,
          'screen_name_identifier': identifier,
        };
        selectedScreenIdentifier.value = identifier;
        _loadDefaultSettings();
        AppSnackbar.showCustomSnackbar('إنشاء قالب', 'تم تهيئة قالب جديد: ${screenInfo['display']!}');
      } else {
        selectedTemplate.value = null;
        selectedScreenIdentifier.value = '';
        _clearControllers();
        AppSnackbar.showCustomSnackbar('خطأ', 'القالب أو الشاشة غير موجودة.', isError: true);
      }
    }
  }

  void _loadDefaultSettings() {
    companyNameController.text = 'اسم شركتك التجاري';
    thanksMessageController.text = 'شكراً لثقتكم بنا!';
    contactInfoController.text = 'للاستفسار: 0123456789';
    addressDetailsController.text = 'عنوان المقر الرئيسي لشركتك';
    showLogo.value = true;
    currentLogoUrl.value = '';
    _pickedLogoBytes.value = null;
  }

  void _loadSettingsIntoControllers(Map<String, dynamic> settings) {
    companyNameController.text = settings['header_company_name'] ?? '';
    thanksMessageController.text = settings['footer_thanks_message'] ?? '';
    contactInfoController.text = settings['footer_contact_info'] ?? '';
    addressDetailsController.text = settings['footer_address_details'] ?? '';

    showLogo.value = (settings['show_logo'] == 1 || settings['show_logo'] == true);
    currentLogoUrl.value = settings['logo_url'] ?? '';
    _pickedLogoBytes.value = null;
  }

  void _clearControllers() {
    companyNameController.clear();
    thanksMessageController.clear();
    contactInfoController.clear();
    addressDetailsController.clear();
    showLogo.value = true;
    currentLogoUrl.value = '';
    _pickedLogoBytes.value = null;
  }

  Future<void> saveTemplateSettings() async {
    if (selectedTemplate.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لم يتم تحديد قالب لحفظ الإعدادات.', isError: true);
      return;
    }

    final isNewTemplate = selectedTemplate.value!['id'] == null;
    final identifier = selectedScreenIdentifier.value;

    try {
      final Map<String, dynamic> settingsMap = {
        'header_company_name': companyNameController.text.trim(),
        'logo_url': currentLogoUrl.value,
        'show_logo': showLogo.value,
        'footer_thanks_message': thanksMessageController.text.trim(),
        'footer_contact_info': contactInfoController.text.trim(),
        'footer_address_details': addressDetailsController.text.trim(),
      };

      final String settingsJsonString = jsonEncode(settingsMap);
      final String now = DateTime.now().toIso8601String();

      if (isNewTemplate) {
        final String displayName = selectedTemplate.value!['template_display_name'] as String;

        final Map<String, dynamic> row = {
          'template_display_name': displayName,
          'screen_name_identifier': identifier,
          'settings_json': settingsJsonString,
          'is_active': 1,
          'created_at': now,
          'last_updated_at': now,
        };

        final int id = await _dbHelper.insert('invoice_templates', row);

        if (id > 0) {
          final newTemplate = Map<String, dynamic>.from(row);
          newTemplate['id'] = id;
          _invoiceTemplates.add(newTemplate);
          selectedTemplate.value = newTemplate;
          AppSnackbar.showCustomSnackbar('نجاح', 'تم إضافة وحفظ القالب الجديد بنجاح.');
        }
      } else {
        final int id = selectedTemplate.value!['id'];
        final Map<String, dynamic> row = {
          'settings_json': settingsJsonString,
          'last_updated_at': now,
        };

        final int count = await _dbHelper.update(
            'invoice_templates',
            row,
            'id = ?',
            [id]
        );

        if (count > 0) {
          final updatedIndex = _invoiceTemplates.indexWhere((tpl) => tpl['id'] == id);
          if (updatedIndex != -1) {
            final updatedTemplate = Map<String, dynamic>.from(_invoiceTemplates[updatedIndex]);
            updatedTemplate['settings_json'] = settingsJsonString;
            updatedTemplate['last_updated_at'] = now;
            _invoiceTemplates[updatedIndex] = updatedTemplate;
          }

          selectedTemplate.value = _invoiceTemplates[updatedIndex];
          AppSnackbar.showCustomSnackbar('نجاح', 'تم تحديث إعدادات القالب بنجاح.');
        }
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل حفظ إعدادات القالب', isError: true);
    }
  }

  Future<void> pickAndProcessLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      return;
    }

    try {
      final Uint8List bytes = await image.readAsBytes();
      _pickedLogoBytes.value = bytes;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final String localPath = path.join(appDir.path, fileName);

      await File(image.path).copy(localPath);

      currentLogoUrl.value = localPath;

      await saveTemplateSettings();

      AppSnackbar.showCustomSnackbar('نجاح', 'تم حفظ الشعار محلياً.');

    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء حفظ الشعار', isError: true);
      _pickedLogoBytes.value = null;
    }
  }

  void clearPickedLogo() {
    _pickedLogoBytes.value = null;
    currentLogoUrl.value = '';
    AppSnackbar.showCustomSnackbar('إزالة الشعار', 'تم مسح الشعار المختار.');
  }

  List<Map<String, String>> get availableTemplatesForDropdown {
    final List<Map<String, String>> dropdownItems = [];

    for (var template in _invoiceTemplates) {
      dropdownItems.add({
        'display': template['template_display_name'] as String,
        'identifier': template['screen_name_identifier'] as String,
        'isNew': 'false',
        'id': template['id']?.toString() ?? '',
      });
    }

    final List<String> existingIdentifiers = _invoiceTemplates.map((t) => t['screen_name_identifier'] as String).toList();

    for (var screen in staticAvailableScreens) {
      if (!existingIdentifiers.contains(screen['identifier'])) {
        dropdownItems.add({
          'display': '${screen['display']!} (إضافة قالب جديد)',
          'identifier': screen['identifier']!,
          'isNew': 'true',
          'id': '',
        });
      }
    }

    dropdownItems.sort((a, b) => a['display']!.compareTo(b['display']!));
    return dropdownItems;
  }
}