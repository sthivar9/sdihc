import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sdihc/pages/functionPages/bill_detailsscreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getBills(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error);
          }
          final bills = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return Card(
                child: ListTile(
                  title: Text('Bill #${bill['id'].substring(0, 6)}'),
                  subtitle: Text(DateFormat.yMd().format(
                    DateTime.parse(bill['created_at'] as String),
                  )),
                  trailing: Text(
                    '₹${(bill['total_bulk_cost_price'] ?? 0.0).toStringAsFixed(2)}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BillDetailsScreen(billId: bill['id'] as String),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(Object? error) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bills: $error')),
        );
      }
    });
    return const Center(child: Text('Failed to load bills. Please try again.'));
  }

  Future<List<Map<String, dynamic>>> _getBills() async {
    final organizationId = await _getCurrentOrganizationId();

    if (organizationId == null) {
      throw Exception('No organization found for the user.');
    }

    final response = await Supabase.instance.client
        .from('bills')
        .select('''
          id,
          created_at,
          bill_items (bulk_cost_price)
        ''')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .execute();

    if (response.status != 200) {
      throw Exception('Failed to fetch bills: ');
    }

    // Process the response to calculate total_bulk_cost_price for each bill
    final List<dynamic> data = response.data;
    final List<Map<String, dynamic>> bills = [];

    for (var bill in data) {
      final List<dynamic> billItems = bill['bill_items'] ?? [];
      double totalBulkCostPrice = 0;

      for (var item in billItems) {
        totalBulkCostPrice += (item['bulk_cost_price'] ?? 0.0) as double;
      }

      bills.add({
        'id': bill['id'],
        'created_at': bill['created_at'],
        'total_bulk_cost_price': totalBulkCostPrice,
      });
    }

    return bills;
  }

  Future<String?> _getCurrentOrganizationId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final response = await Supabase.instance.client
        .from('user_organization_membership')
        .select('organization_id')
        .eq('user_id', user.id)
        .maybeSingle()
        .execute();

    if (response.status != 200) {
      throw Exception('Failed to fetch organization ID: ');
    }

    return response.data?['organization_id'] as String?;
  }
}
