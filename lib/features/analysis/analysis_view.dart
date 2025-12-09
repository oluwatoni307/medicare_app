// lib/features/analysis/analysis_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/monthly_view.dart';
import 'views/weekly_view.dart';
import 'views/daily_view.dart';
import 'analysis_viewmodel.dart';
import '/navBar.dart';

class AnalysisDashboardView extends StatefulWidget {
  const AnalysisDashboardView({Key? key}) : super(key: key);

  @override
  State<AnalysisDashboardView> createState() => _AnalysisDashboardViewState();
}

class _AnalysisDashboardViewState extends State<AnalysisDashboardView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AnalysisViewModel()..loadAllData(),
      child: Scaffold(
        bottomNavigationBar: const BottomNavBar(currentIndex: 1),
        body: Consumer<AnalysisViewModel>(
          builder: (context, viewModel, child) {
            _tabController.addListener(() {
              if (!_tabController.indexIsChanging) {
                viewModel.setSelectedView(
                  _tabController.index == 0
                      ? 'Monthly'
                      : _tabController.index == 1
                      ? 'Weekly'
                      : 'Daily',
                );
              }
            });

            return Column(
              children: [
                _buildHeader(),
                Container(
                  color: const Color(0xFF4A90E2),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: const [
                      Tab(text: 'Monthly'),
                      Tab(text: 'Weekly'),
                      Tab(text: 'Daily'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [MonthlyView(), WeeklyView(), DailyView()],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // SIMPLIFIED HEADER - Clean and minimal
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 23, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Track your medication adherence',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
