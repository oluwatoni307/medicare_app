// lib/features/analysis/analysis_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'analysis_model.dart';
import 'service.dart';

/// ViewModel for managing adherence data and chart preparation
class AnalysisViewModel extends ChangeNotifier {
  final AnalysisService _analysisService = AnalysisService();

  AnalysisViewModel();

  // === STATE VARIABLES ===

  Map<String, double> _weeklyAdherenceData = {};
  List<String> _weeklyMedications = [];
  Map<String, Map<String, double>> _weeklyMedicationData = {};

  String _selectedView = 'Monthly';
  bool _isLoadingMonthly = false;
  bool _isLoadingWeekly = false;
  bool _isLoadingToday = false;
  List<DailySummary> _monthlyData = [];
  WeeklyInsight? _weeklyInsight;
  List<DailyTile> _dailyTiles = [];
  Map<String, double> _dailyPieData = {};
  List<ChartDataPoint> _monthlyChartData = [];
  DateTime _currentMonth = DateTime.now();
  DateTime _currentWeekStart = _calculateWeekStart(DateTime.now());
  String? _error;
  int _requestCounter = 0;

  // === GETTERS ===

  String get selectedView => _selectedView;
  bool get isLoadingMonthly => _isLoadingMonthly;
  bool get isLoadingWeekly => _isLoadingWeekly;
  bool get isLoadingToday => _isLoadingToday;
  bool get isLoading =>
      _isLoadingMonthly || _isLoadingWeekly || _isLoadingToday;
  List<DailySummary> get monthlyData => _monthlyData;
  WeeklyInsight? get weeklyInsight => _weeklyInsight;
  List<DailyTile> get dailyTiles => _dailyTiles;
  Map<String, double> get dailyPieData => _dailyPieData;
  List<ChartDataPoint> get monthlyChartData => _monthlyChartData;
  DateTime get currentMonth => _currentMonth;
  DateTime get currentWeekStart => _currentWeekStart;
  String? get error => _error;
  bool get hasMonthlyData => _monthlyData.isNotEmpty;
  bool get hasWeeklyData => _weeklyInsight != null;
  bool get hasDailyData => _dailyTiles.isNotEmpty;
  Map<String, double> get weeklyAdherenceData => _weeklyAdherenceData;
  List<String> get weeklyMedications => _weeklyMedications;
  Map<String, Map<String, double>> get weeklyMedicationData =>
      _weeklyMedicationData;

  double get monthlyAverageAdherence {
    if (_monthlyData.isEmpty) return 0.0;
    final activeDays = _monthlyData.where((d) => d.hasActivity).toList();
    if (activeDays.isEmpty) return 0.0;
    return activeDays
            .map((d) => d.adherencePercentage)
            .reduce((a, b) => a + b) /
        activeDays.length;
  }

  int get totalMedicationsTracked {
    return _weeklyInsight?.totalMedications ?? 0;
  }

  List<ChartDataPoint> get weeklyChartData {
    const serviceDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    return serviceDayKeys.asMap().entries.map((entry) {
      final index = entry.key;
      final serviceKey = entry.value;
      final date = _currentWeekStart.add(Duration(days: index));
      final value = _weeklyAdherenceData[serviceKey] ?? 0.0;
      return ChartDataPoint(date: _formatDate(date), value: value);
    }).toList();
  }

  // === TAB HANDLING ===

  void setSelectedView(String view) {
    if (_selectedView != view) {
      _selectedView = view;
      switch (view) {
        case 'Monthly':
          loadMonthlyData(_currentMonth);
          break;
        case 'Weekly':
          loadWeeklyData(_currentWeekStart);
          break;
        case 'Daily':
          loadTodayData();
          break;
      }
      notifyListeners();
    }
  }

  // === DATA FETCHING ===

  Future<void> loadMonthlyData([DateTime? month]) async {
    if (month != null) _currentMonth = month;

    final requestId = ++_requestCounter;
    _isLoadingMonthly = true;
    _error = null;
    notifyListeners();

    try {
      await _analysisService.init();

      final monthStr =
          "${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}";

      _monthlyData = await _analysisService.getMonthlySummaryData(monthStr);
      _monthlyChartData = await _analysisService.getMonthlyChartData(monthStr);

      if (requestId != _requestCounter) return;
    } catch (e) {
      if (requestId == _requestCounter) {
        _error = 'Failed to load monthly data: ${e.toString()}';
        _monthlyData = [];
        _monthlyChartData = [];
      }
    } finally {
      if (requestId == _requestCounter) {
        _isLoadingMonthly = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadWeeklyData([DateTime? weekStart]) async {
    if (weekStart != null) {
      _currentWeekStart = _calculateWeekStart(weekStart);
    }

    final requestId = ++_requestCounter;
    _isLoadingWeekly = true;
    _error = null;
    notifyListeners();

    try {
      await _analysisService.init();

      final weekEnd = _currentWeekStart.add(const Duration(days: 6));
      final startStr = _formatDate(_currentWeekStart);
      final endStr = _formatDate(weekEnd);

      final weeklyData = await _analysisService.getWeeklyDataComplete(
        startStr,
        endStr,
      );

      if (requestId != _requestCounter) return;

      _weeklyAdherenceData = weeklyData.overallAdherence;
      _weeklyMedications = weeklyData.medications;
      _weeklyMedicationData = weeklyData.perMedicationData;
      _weeklyInsight = weeklyData.insight;
    } catch (e) {
      if (requestId == _requestCounter) {
        _error = 'Failed to load weekly data: ${e.toString()}';
        _weeklyInsight = null;
        _weeklyMedications = [];
        _weeklyAdherenceData = {};
        _weeklyMedicationData = {};
      }
    } finally {
      if (requestId == _requestCounter) {
        _isLoadingWeekly = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadTodayData() async {
    if (_dailyTiles.isNotEmpty) return;

    final requestId = ++_requestCounter;
    _isLoadingToday = true;
    _error = null;
    notifyListeners();

    try {
      await _analysisService.init();

      final dateStr = _formatDate(DateTime.now());

      _dailyTiles = await _analysisService.getDailyData(dateStr);
      _dailyPieData = await _analysisService.getDailyPieChartData(dateStr);

      if (requestId != _requestCounter) return;
    } catch (e) {
      if (requestId == _requestCounter) {
        _error = 'Failed to load daily data: ${e.toString()}';
        _dailyTiles = [];
        _dailyPieData = {};
      }
    } finally {
      if (requestId == _requestCounter) {
        _isLoadingToday = false;
        notifyListeners();
      }
    }
  }

  // === NAVIGATION ===

  Future<void> goToPreviousMonth() async {
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    await loadMonthlyData(previousMonth);
  }

  Future<void> goToNextMonth() async {
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    await loadMonthlyData(nextMonth);
  }

  Future<void> goToPreviousWeek() async {
    final previousWeek = _currentWeekStart.subtract(const Duration(days: 7));
    await loadWeeklyData(previousWeek);
  }

  Future<void> goToNextWeek() async {
    final nextWeek = _currentWeekStart.add(const Duration(days: 7));
    await loadWeeklyData(nextWeek);
  }

  // === UTILITY METHODS ===

  bool hasDataForCurrentMonth() {
    return _monthlyData.any((d) => d.hasActivity);
  }

  String get currentMonthString {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  String get currentWeekString {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final startStr = '${_currentWeekStart.day}/${_currentWeekStart.month}';
    final endStr = '${weekEnd.day}/${weekEnd.month}';
    return '$startStr - $endStr';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refreshData() async {
    await loadAllData();
  }

  Future<void> loadAllData() async {
    switch (_selectedView) {
      case 'Monthly':
        await loadMonthlyData();
        break;
      case 'Weekly':
        await loadWeeklyData();
        break;
      case 'Daily':
        await loadTodayData();
        break;
    }
  }

  // === HELPER METHODS ===

  static DateTime _calculateWeekStart(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _requestCounter++;
    super.dispose();
  }
}
