import 'package:flutter/material.dart';
import 'package:untitled4/supabase_manager.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        await SupabaseManager.client.from('products').insert({
          'name': _nameController.text,
          'product_code': _codeController.text,
          'price': double.parse(_priceController.text),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة المنتج بنجاح')),
        );
        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الإضافة: ${e.toString()}')),
        );
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _codeController.clear();
    _priceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _addProduct,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField('اسم المنتج', _nameController),
              _buildTextField('كود المنتج', _codeController),
              _buildNumberField('السعر', _priceController),
              ElevatedButton(
                onPressed: _addProduct,
                child: const Text('حفظ المنتج'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null,
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null,
    );
  }
}