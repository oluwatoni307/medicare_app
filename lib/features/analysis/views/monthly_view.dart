// lib/features/analysis/views/monthly_view.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../analysis_viewmodel.dart';

/// FIXED Monthly View with proper date labels, percentage axis, and complete data range
class MonthlyView extends StatelessWidget {
  const MonthlyView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalysisViewModel>(context);

    return SingleChildScrollView(child: _buildContent(context, viewModel));
  }

  // --- Content ---
  /// Displays loading, error, or the monthly adherence chart.
  Widget _buildContent(BuildContext context, AnalysisViewModel viewModel) {
    if (viewModel.isLoadingMonthly) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.refreshData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildMonthlyChart(context, viewModel);
  }

  // --- Monthly Chart ---
  /// Displays a line chart of monthly adherence trends.
  Widget _buildMonthlyChart(BuildContext context, AnalysisViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: viewModel.goToPreviousMonth,
              ),
              Text(
                viewModel.currentMonthString,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: viewModel.goToNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Title
          Text(
            'Daily Medication Adherence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Line chart
          SizedBox(
            height: 280,
            child: Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: viewModel.monthlyChartData.isEmpty
                    ? _buildEmptyState(context)
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 25,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.15),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 ||
                                      index >=
                                          viewModel.monthlyChartData.length) {
                                    return const SizedBox.shrink();
                                  }

                                  final dataPoint =
                                      viewModel.monthlyChartData[index];
                                  // Parse the ISO date string (e.g., "2025-08-15")
                                  final dateParts = dataPoint.date.split('-');
                                  if (dateParts.length != 3) {
                                    return const SizedBox.shrink();
                                  }

                                  final day = int.parse(dateParts[2]);

                                  // FIXED: Show labels every 5 days or day 1
                                  if (day == 1 || day % 5 == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '$day',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 32,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  // FIXED: Show percentage labels (0%, 25%, 50%, 75%, 100%)
                                  if (value % 25 == 0) {
                                    return Text(
                                      '${value.toInt()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 42,
                                interval: 25,
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: viewModel.monthlyChartData
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) =>
                                        FlSpot(e.key.toDouble(), e.value.value),
                                  )
                                  .toList(),
                              isCurved: true,
                              curveSmoothness: 0.25,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 3,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.3),
                                    Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, barData) {
                                  // Show dots only for non-zero values to highlight actual data
                                  return spot.y > 0;
                                },
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 3,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    strokeWidth: 1.5,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) =>
                                  Theme.of(context).colorScheme.inverseSurface,
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              getTooltipItems: (touchedSpots) => touchedSpots.map((
                                spot,
                              ) {
                                final dataPoint =
                                    viewModel.monthlyChartData[spot.x.toInt()];
                                // Parse date for display
                                final dateParts = dataPoint.date.split('-');
                                final month = _getMonthAbbreviation(
                                  int.parse(dateParts[1]),
                                );
                                final day = int.parse(dateParts[2]);

                                return LineTooltipItem(
                                  '$month $day\n${dataPoint.value.toStringAsFixed(1)}%',
                                  TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onInverseSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary stats
          if (viewModel.hasMonthlyData) ...[
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Average Adherence',
                    '${viewModel.monthlyAverageAdherence.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    _getAdherenceColor(
                      viewModel.monthlyAverageAdherence,
                      context,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Days Tracked',
                    '${_countActiveDays(viewModel)}',
                    Icons.calendar_today,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // FIXED: Better empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No medication data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your medications to see\nyour adherence trends here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Count only days with actual activity (adherence > 0 or explicitly logged as 0)
  int _countActiveDays(AnalysisViewModel viewModel) {
    return viewModel.monthlyData.where((d) => d.hasActivity).length;
  }

  // Helper to determine adherence quality color
  Color _getAdherenceColor(double percentage, BuildContext context) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  // Helper to get month abbreviation
  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
