import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubmitBillScreen extends StatefulWidget {
  const SubmitBillScreen({super.key});

  @override
  State<SubmitBillScreen> createState() => _SubmitBillScreenState();
}

class _SubmitBillScreenState extends State<SubmitBillScreen> {
  final _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _products = [];
  final _formKey = GlobalKey<FormState>();
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _getCurrentOrganization();
  }

  Future<void> _getCurrentOrganization() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('user_organization_membership')
          .select('organization_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _organizationId = response['organization_id'] as String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading organization: $e')),
        );
      }
    }
  }

  Future<void> _submitBill() async {
    if (_products.isEmpty || _organizationId == null) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Create bill
      final billResponse = await _supabase
          .from('bills')
          .insert({
            'organization_id': _organizationId,
            'created_by': user.id,
          })
          .select()
          .single();

      // Add bill items
      for (final product in _products) {
        final productData = Map<String, dynamic>.from(product);
        // Remove generated or computed columns
        productData.remove('profit_percent');
        productData.remove('margin_of_profit');

        await _supabase.from('bill_items').insert({
          ...productData,
          'bill_id': billResponse['id'],
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting bill: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Bill')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];

                // Calculate bulk selling price and profit
                double bulkSellingPrice =
                    product['selling_price'] * product['quantity'];
                double profit = bulkSellingPrice - product['bulk_cost_price'];
                double profitPercent =
                    (profit / product['bulk_cost_price']) * 100;

                return ListTile(
                  title: Text(product['product_name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qty: ${product['quantity']}'),
                      Text(
                        'Profit: ₹${profit.toStringAsFixed(2)} (${profitPercent.toStringAsFixed(2)}%)',
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => _products.removeAt(index)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton(
              onPressed: _products.isEmpty ? null : _submitBill,
              child: const Text('Submit Bill'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        onSave: (product) {
          // Calculate profit metrics
          final margin = (double.parse(product['selling_price'].toString()) -
                  double.parse(product['bulk_cost_price'].toString())) *
              int.parse(product['quantity'].toString());

          final profitPercent =
              ((double.parse(product['selling_price'].toString()) -
                          double.parse(product['bulk_cost_price'].toString())) /
                      double.parse(product['bulk_cost_price'].toString())) *
                  100;

          setState(() {
            _products.add({
              ...product,
              'margin_of_profit': margin.toStringAsFixed(2),
              'profit_percent': profitPercent.toStringAsFixed(2),
            });
          });
        },
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const AddProductDialog({super.key, required this.onSave});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _bulkPriceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _sellingPriceController,
              decoration: const InputDecoration(labelText: 'Selling Price'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _bulkPriceController,
              decoration: const InputDecoration(labelText: 'Bulk Cost Price'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'product_name': _nameController.text,
                'quantity': int.parse(_quantityController.text),
                'selling_price': double.parse(_sellingPriceController.text),
                'bulk_cost_price': double.parse(_bulkPriceController.text),
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
