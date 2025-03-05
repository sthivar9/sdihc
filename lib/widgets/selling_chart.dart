import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sdihc/utils/providers.dart';

class Past7DaysSellingPriceChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final past7DaysData = ref.watch(past7DaysDataProvider);

    return Container(
      color: Colors.transparent,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            past7DaysData.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  "Error: ${error.toString()}",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              data: (data) => data.isEmpty
                  ? Center(child: Text("No data available"))
                  : Container(
                      height: 300,
                      child: SellingPriceLineChart(data: data),
                    ),
            ),
          ],
        ),
      ),
    );
  }
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
            "Past 7 Days Inventory Added Cost",
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Functions
double calculateMinY(List<Map<String, dynamic>> data) {
  double minY = data
      .map((e) => (e["total_selling_price"] as num).toDouble())
      .reduce((a, b) => a < b ? a : b);
  return minY > 10 ? minY / 2 : 1;
}

double calculateMaxY(List<Map<String, dynamic>> data) {
  double maxY = data
      .map((e) => (e["total_selling_price"] as num).toDouble())
      .reduce((a, b) => a > b ? a : b);
  return maxY + 10;
}
