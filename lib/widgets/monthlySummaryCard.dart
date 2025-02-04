import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyFinancialSummary extends StatefulWidget {
  @override
  _MonthlyFinancialSummaryState createState() =>
      _MonthlyFinancialSummaryState();
}

class _MonthlyFinancialSummaryState extends State<MonthlyFinancialSummary> {
  double _totalExpense = 0;
  double _totalEarnings = 0;
  double _totalTurnover = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyData();
  }

  Future<void> _fetchMonthlyData() async {
    try {
      final orgId = await _getCurrentOrganizationId();
      if (orgId == null) {
        setState(() {
          _errorMessage = 'No organization found';
          _isLoading = false;
        });
        return;
      }

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

      final List<dynamic> data = response.data;

      double expense = 0;
      double earnings = 0;
      double turnover = 0;

      for (var entry in data) {
        expense += entry['total_cost'] ?? 0;
        earnings += entry['total_profit'] ?? 0;
        turnover += entry['total_selling_price'] ?? 0;
      }

      setState(() {
        _totalExpense = expense;
        _totalEarnings = earnings;
        _totalTurnover = turnover;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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
      throw Exception(
          'Failed to fetch organization ID: HTTP ${response.status}');
    }

    return response.data?['organization_id'] as String?;
  }

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

  @override
  Widget build(BuildContext context) {
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
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              )
            else if (_totalTurnover == 0)
              Center(child: Text('No data available for this month'))
            else
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildMetricCard(
                    'Expense',
                    _totalExpense,
                    Colors.red,
                    Icons.arrow_downward,
                  ),
                  _buildMetricCard(
                    'Earnings',
                    _totalEarnings,
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                  _buildMetricCard(
                    'Turnover',
                    _totalTurnover,
                    Colors.blue,
                    Icons.bar_chart,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
