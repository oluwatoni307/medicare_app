// lib/features/analysis/analysis_view.dart - FIXED VERSION

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

class _AnalysisDashboardViewState extends State<AnalysisDashboardView> with TickerProviderStateMixin {
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
    // ✅ FIXED: Move ChangeNotifierProvider to the top level
    return ChangeNotifierProvider(
      create: (context) => AnalysisViewModel()..loadAllData(),
      child: Scaffold(
        bottomNavigationBar: const BottomNavBar(currentIndex: 1),
        body: Consumer<AnalysisViewModel>(
          builder: (context, viewModel, child) {
            // ✅ FIXED: Add listener here where Provider is available
            _tabController.addListener(() {
              if (!_tabController.indexIsChanging) {
                viewModel.setSelectedView(_tabController.index == 0
                    ? 'Monthly'
                    : _tabController.index == 1
                        ? 'Weekly'
                        : 'Daily');
              }
            });

            return Column(
              children: [
                SizedBox(height: 10,),
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
                    children: const [
                      MonthlyView(),
                      WeeklyView(),
                      DailyView(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icons.access_time,
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
                  'Stay on track with\nyour health goals!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your dashboard keeps you consistent and on track.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
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