import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillDetailsScreen extends StatelessWidget {
  final String billId;

  const BillDetailsScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Details')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getBillItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _handleError(context, snapshot.error);
          }
          final items = snapshot.data ?? [];

          // Calculate totals
          double totalBulkCostPrice = 0;
          double totalMarginOfProfit = 0;
          double totalProfitPercent = 0;

          for (var item in items) {
            totalBulkCostPrice += (item['bulk_cost_price'] ?? 0.0) as double;
            totalMarginOfProfit += (item['margin_of_profit'] ?? 0.0) as double;
            totalProfitPercent += (item['profit_percent'] ?? 0.0) as double;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item['product_name'] as String),
                        subtitle: Text('Qty: ${item['quantity']}'),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '₹${(item['bulk_cost_price'] ?? 0.0).toStringAsFixed(2)}'),
                            Text(
                                '${(item['profit_percent'] ?? 0.0).toStringAsFixed(2)}%'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Display totals at the bottom
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Bulk Cost Price: ₹${totalBulkCostPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Margin of Profit: ₹${totalMarginOfProfit.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Profit Percentage: ${totalProfitPercent.toStringAsFixed(2)}%',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getBillItems() async {
    final response =
        await Supabase.instance.client.from('bill_items').select('''
          product_name,
          quantity,
          bulk_cost_price,
          margin_of_profit,
          profit_percent
        ''').eq('bill_id', billId).execute();

    if (response.status != 200) {
      throw Exception('Failed to fetch bill items: ');
    }

    final List<dynamic> data = response.data;
    return data.cast<Map<String, dynamic>>();
  }

  Widget _handleError(BuildContext context, Object? error) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bill items: $error')),
      );
    });

    // Return a widget to display the error message
    return const Center(
      child: Text('Failed to load bill items. Please try again.'),
    );
  }
}
