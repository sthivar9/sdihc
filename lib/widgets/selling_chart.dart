import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Past7DaysSellingPriceChart extends StatefulWidget {
  @override
  _Past7DaysSellingPriceChartState createState() =>
      _Past7DaysSellingPriceChartState();
}

class _Past7DaysSellingPriceChartState
    extends State<Past7DaysSellingPriceChart> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final orgId = await _getCurrentOrganizationId();
      if (orgId == null) {
        setState(() {
          _errorMessage = 'No organization found for the current user.';
          _isLoading = false;
        });
        return;
      }

      final today = DateTime.now();
      final sevenDaysAgo = today.subtract(Duration(days: 7));

      final response = await Supabase.instance.client
          .from('daily_stats')
          .select('date, total_selling_price')
          .eq('org_id', orgId)
          .gte('date', sevenDaysAgo.toIso8601String())
          .lt('date', today.toIso8601String())
          .order('date', ascending: true)
          .execute();

      // Check HTTP status code for errors
      if (response.status != 200) {
        throw Exception('Failed to fetch data: HTTP ${response.status}');
      }

      setState(() {
        _data = List<Map<String, dynamic>>.from(response.data);
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

    // Check HTTP status code for errors
    if (response.status != 200) {
      throw Exception(
          'Failed to fetch organization ID: HTTP ${response.status}');
    }

    return response.data?['organization_id'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            else
              Container(
                height: 300,
                child: SellingPriceLineChart(data: _data),
              ),
          ],
        ),
      ),
    );
  }
}

double calculateMinY(List<Map<String, dynamic>> data) {
  double minY = data
      .map((e) => (e["total_selling_price"] as num).toDouble())
      .reduce((a, b) => a < b ? a : b);
  return minY =
      minY > 10 ? minY / 2 : 1; // Ensure small values are not at the bottom
}

double calculateMaxY(List<Map<String, dynamic>> data) {
  double maxY = data
      .map((e) => (e["total_selling_price"] as num).toDouble())
      .reduce((a, b) => a > b ? a : b);
  return maxY + 10; // Adds spacing on top
}

class SellingPriceLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  SellingPriceLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Center(child: Text("No data available"));

    double minY = calculateMinY(data);
    double maxY = calculateMaxY(data);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Past 7 Days Inventory added cost",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                backgroundColor: Colors.white,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${value.toInt()}',
                          style: TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          DateFormat("dd").format(
                              DateTime.fromMillisecondsSinceEpoch(
                                  value.toInt())),
                          style: TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                    show: true, border: Border.all(color: Colors.grey)),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.map((e) {
                      double yValue = e["total_selling_price"].toDouble();
                      yValue = yValue < 5
                          ? 5
                          : yValue; // Ensures a minimum height for very small values
                      return FlSpot(
                          DateTime.parse(e["date"])
                              .millisecondsSinceEpoch
                              .toDouble(),
                          yValue);
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 4,
                    belowBarData: BarAreaData(
                        show: true, color: Colors.blue.withOpacity(0.3)),
                    dotData: FlDotData(show: true),
                  ),
                  LineChartBarData(
                    spots: data.map((e) {
                      DateTime date = DateTime.parse(e["date"]);
                      return FlSpot(date.millisecondsSinceEpoch.toDouble(),
                          e["total_selling_price"].toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 4,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.3),
                    ),
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
