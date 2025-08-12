// lib/features/analysis/views/daily_view.dart

// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../analysis_model.dart';
import '../analysis_viewmodel.dart';

// --- Daily View for displaying adherence pie chart and medication tiles ---
class DailyView extends StatelessWidget {
  const DailyView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AnalysisViewModel>(context);

    return SingleChildScrollView(
      child: Column(children: [_buildContent(context, viewModel)]),
    );
  }

  // --- Content ---
  /// Displays loading, error, or main content (pie chart and tiles).
  Widget _buildContent(BuildContext context, AnalysisViewModel viewModel) {
    if (viewModel.isLoadingToday) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      );
    }

    if (viewModel.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              viewModel.error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => viewModel.refreshData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (viewModel.dailyTiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No doses scheduled today',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPieChart(context, viewModel),
        _buildMedicineGrid(context, viewModel),
      ],
    );
  }

  // --- Pie Chart ---
  /// Displays a pie chart of taken, missed, and not logged percentages.
  Widget _buildPieChart(BuildContext context, AnalysisViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Adherence',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  if (viewModel.dailyPieData['taken']! > 0)
                    PieChartSectionData(
                      value: viewModel.dailyPieData['taken'],
                      color: Colors.green,
                      title:
                          'Taken\n${viewModel.dailyPieData['taken']!.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  if (viewModel.dailyPieData['missed']! > 0)
                    PieChartSectionData(
                      value: viewModel.dailyPieData['missed'],
                      color: Colors.red,
                      title:
                          'Missed\n${viewModel.dailyPieData['missed']!.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  if (viewModel.dailyPieData['not_logged']! > 0)
                    PieChartSectionData(
                      value: viewModel.dailyPieData['not_logged'],
                      color: Colors.amber,
                      title:
                          'Not Logged\n${viewModel.dailyPieData['not_logged']!.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tile List ---
  /// Displays a list of medication tiles with name, time, and status.
  Widget _buildTileList(BuildContext context, AnalysisViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Medications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...viewModel.dailyTiles.map((tile) => _buildDoseTile(tile)),
        ],
      ),
    );
  }

  // --- Dose Tile ---
  /// Builds a single tile for a medication dose.
  Widget _buildDoseTile(DailyTile tile) {
    return Semantics(
      label: '${tile.name}, ${tile.status} at ${tile.time}',
      child: Card(
        child: ListTile(
          title: Text(tile.name),
          subtitle: Text('Time: ${tile.time}'),
          trailing: Text(
            tile.status,
            style: TextStyle(
              color: tile.status == 'taken'
                  ? Colors.green
                  : tile.status == 'missed'
                  ? Colors.red
                  : Colors.amber,
            ),
          ),
          tileColor: tile.status == 'taken'
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
        ),
      ),
    );
  }
}

/// Replaces the tile list with a 3x3 medicine adherence grid
Widget _buildMedicineGrid(BuildContext context, AnalysisViewModel viewModel) {
  // Calculate adherence statistics
  final takenCount = viewModel.dailyTiles
      .where((t) => t.status == 'taken')
      .length;
  final missedCount = viewModel.dailyTiles
      .where((t) => t.status == 'missed')
      .length;

  // Group medications by name and sort by time
  final medicationGroups = <String, List<DailyTile>>{};
  for (final tile in viewModel.dailyTiles) {
    medicationGroups.putIfAbsent(tile.name, () => []).add(tile);
  }

  // Sort each medication's doses by time
  medicationGroups.forEach(
    (_, tiles) => tiles.sort((a, b) => a.time.compareTo(b.time)),
  );

  // Get up to 3 medications (as shown in the dashboard image)
  final medications = medicationGroups.keys.take(3).toList();

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Medications',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        // Legend with counters
        _buildLegend(takenCount, missedCount),

        const SizedBox(height: 12),

        // 3x3 Grid Layout
        _buildAdherenceGrid(medications, medicationGroups),
      ],
    ),
  );
}

/// Creates the legend showing taken/missed counts with color indicators
Widget _buildLegend(int takenCount, int missedCount) {
  return Row(
    children: [
      _legendItem('Taken', Colors.green, takenCount),
      const SizedBox(width: 24),
      _legendItem('Missed', Colors.red, missedCount),
    ],
  );
}

Widget _legendItem(String label, Color color, int count) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '$label: $count',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ],
  );
}

/// Builds the 3x3 adherence grid with medicine names as row headers
Widget _buildAdherenceGrid(
  List<String> medications,
  Map<String, List<DailyTile>> medicationGroups,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Interval headers (Morning, Afternoon, Evening)

      const Divider(height: 16, thickness: 1),

      // Medicine rows
      for (final medication in medications)
        _buildMedicineRow(medication, medicationGroups[medication] ?? []),
    ],
  );
}



/// Builds a single medicine row with 3 interval cells
Widget _buildMedicineRow(String medication, List<DailyTile> doses) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        // Medicine name (row header)
        SizedBox(
          width: 120,
          child: Text(
            medication,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 3 interval cells
        for (int i = 0; i < 3; i++)
          _buildIntervalCell(doses.length > i ? doses[i] : null),
      ],
    ),
  );
}

/// Builds a single interval cell with appropriate status color
Widget _buildIntervalCell(DailyTile? dose) {
  Color cellColor;
  String status = 'not_logged';

  if (dose != null) {
    status = dose.status;
    cellColor = status == 'taken'
        ? Colors.green
        : status == 'missed'
        ? Colors.red
        : Colors.grey[300]!;
  } else {
    cellColor = Colors.grey[300]!;
  }

  return Padding(
    padding: const EdgeInsets.all(2.0),
    child: Semantics(
      label: dose != null
          ? '${dose.name} dose ${dose.status} at ${dose.time}'
          : 'No dose scheduled',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[400]!, width: 0.5),
        ),
      ),
    ),
  );
}
