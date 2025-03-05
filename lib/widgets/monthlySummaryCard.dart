import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sdihc/utils/organizationIdProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Riverpod FutureProvider for fetching financial data
// Provider to fetch financial data based on the organization ID
final monthlyFinancialProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final orgId = await ref.watch(organizationIdProvider.future);
  if (orgId == null) throw Exception('No organization found');

  final now = DateTime.now();
  final firstDayOfMonth = DateTime.utc(now.year, now.month, 1);
  final lastDayOfMonth = DateTime.utc(now.year, now.month + 1, 0);

  final response = await Supabase.instance.client
      .from('daily_stats')
      .select('total_cost, total_profit, total_selling_price')
      .eq('org_id', orgId)
      .gte('date', firstDayOfMonth.toIso8601String())
      .lte('date', lastDayOfMonth.toIso8601String())
      .execute();

  if (response.status != 200) {
    throw Exception('Failed to fetch data: HTTP ${response.status}');
  }

  final List<dynamic> data = response.data ?? [];

  double expense = 0, earnings = 0, turnover = 0;
  for (var entry in data) {
    expense += (entry['total_cost'] ?? 0).toDouble();
    earnings += (entry['total_profit'] ?? 0).toDouble();
    turnover += (entry['total_selling_price'] ?? 0).toDouble();
  }

  return {'expense': expense, 'earnings': earnings, 'turnover': turnover};
});

// Function to fetch organization ID

// Main Widget
class MonthlyFinancialSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financialSummary = ref.watch(monthlyFinancialProvider);

    return Card(
      elevation: 4,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Financial Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),

            // Loading state
            financialSummary.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Error: ${err.toString()}',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              data: (data) {
                if (data['turnover'] == 0) {
                  return Center(
                      child: Text('No data available for this month'));
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildMetricCard('Expense', data['expense']!, Colors.red,
                        Icons.arrow_downward),
                    _buildMetricCard('Earnings', data['earnings']!,
                        Colors.green, Icons.arrow_upward),
                    _buildMetricCard('Turnover', data['turnover']!, Colors.blue,
                        Icons.bar_chart),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Metric card widget
  Widget _buildMetricCard(
      String title, double value, Color color, IconData icon) {
    return Card(
      color: Colors.white60,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '₹${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
