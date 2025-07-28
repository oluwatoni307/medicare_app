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
      child: Column(
        children: [
          _buildContent(context, viewModel),
        ],
      ),
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
        _buildTileList(context, viewModel),
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
          Text('Today\'s Adherence', style: Theme.of(context).textTheme.titleLarge),
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
                      title: 'Taken\n${viewModel.dailyPieData['taken']!.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  if (viewModel.dailyPieData['missed']! > 0)
                    PieChartSectionData(
                      value: viewModel.dailyPieData['missed'],
                      color: Colors.red,
                      title: 'Missed\n${viewModel.dailyPieData['missed']!.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  if (viewModel.dailyPieData['not_logged']! > 0)
                    PieChartSectionData(
                      value: viewModel.dailyPieData['not_logged'],
                      color: Colors.amber,
                      title: 'Not Logged\n${viewModel.dailyPieData['not_logged']!.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(color: Colors.black, fontSize: 12),
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
          Text('Today\'s Medications', style: Theme.of(context).textTheme.titleLarge),
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
          tileColor: tile.status == 'taken' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        ),
      ),
    );
  }
}