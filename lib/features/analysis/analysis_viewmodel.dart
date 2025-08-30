// lib/features/analysis/analysis_viewmodel.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';
import '/data/models/log.dart';
// --- Update import for models ---
import 'analysis_model.dart';
// --- Update import for the LogService ---
import '/features/log/service.dart';
import 'service.dart'; // LogService

// --- Analysis ViewModel for managing adherence data and chart preparation ---
// --- Updated to work with LogService instead of AnalysisService ---
class AnalysisViewModel extends ChangeNotifier {
  // --- Initialization ---
  final LogService _logService = LogService();

  /// Initializes the ViewModel with LogService.
  AnalysisViewModel();

  // --- State Variables ---
  Map<String, double> _weeklyAdherenceData = {};
  List<String> _weeklyMedications = [];
  Map<String, Map<String, double>> _weeklyMedicationData = {};

  // Add getters
  Map<String, double> get weeklyAdherenceData => _weeklyAdherenceData;
  List<String> get weeklyMedications => _weeklyMedications;
  Map<String, Map<String, double>> get weeklyMedicationData => _weeklyMedicationData;
  
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

  // --- Getters ---
  String get selectedView => _selectedView;
  bool get isLoadingMonthly => _isLoadingMonthly;
  bool get isLoadingWeekly => _isLoadingWeekly;
  bool get isLoadingToday => _isLoadingToday;
  bool get isLoading => _isLoadingMonthly || _isLoadingWeekly || _isLoadingToday;
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

  double get monthlyAverageAdherence {
    if (_monthlyData.isEmpty) return 0.0;
    final activeDays = _monthlyData.where((d) => d.hasActivity).toList();
    if (activeDays.isEmpty) return 0.0;
    return activeDays.map((d) => d.adherencePercentage).reduce((a, b) => a + b) / activeDays.length;
  }

  int get totalMedicationsTracked {
    return _weeklyInsight?.totalMedications ?? 0;
  }

  // --- Tab Handling ---
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

  // --- Data Fetching ---
  
  /// Loads monthly adherence data for the specified month using LogService
  Future<void> loadMonthlyData([DateTime? month]) async {
    if (month != null) _currentMonth = month;

    final requestId = ++_requestCounter;
    _isLoadingMonthly = true;
    _error = null;
    notifyListeners();

    try {
      await _logService.init();

      // Get all active medications
      final medsBox = Hive.box<Med>('meds');
      final medications = medsBox.values.toList();

      if (medications.isEmpty) {
        _monthlyData = [];
        _monthlyChartData = [];
        return;
      }

      final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

      // Process logs for each day of the month
      final dayData = <String, double>{};

      for (int day = 1; day <= monthEnd.day; day++) {
        final currentDate = DateTime(_currentMonth.year, _currentMonth.month, day);
        if (currentDate.isAfter(DateTime.now())) break;

        double dailyTotalPercent = 0.0;
        int medicationCount = 0;

        for (final med in medications) {
          // Check if medication was active on this date
          if (!_isMedicationActiveOnDate(med, currentDate)) continue;

          final logs = await _logService.getLogsForMedicineAndRange(
            med.id, 
            currentDate, 
            currentDate
          );

          if (logs.isNotEmpty) {
            dailyTotalPercent += logs.first.percent;
            medicationCount++;
          }
        }

        if (medicationCount > 0) {
          final dateStr = _formatDate(currentDate);
          dayData[dateStr] = dailyTotalPercent / medicationCount;
        }
      }

      // Check if this request is still current
      if (requestId != _requestCounter) return;

      // Create DailySummary objects
      _monthlyData = dayData.entries.map((entry) {
        return DailySummary(
          date: entry.key,
          adherencePercentage: entry.value,
          hasActivity: true,
        );
      }).toList();

      // Prepare chart data points
      _monthlyChartData = dayData.entries.map((entry) {
        return ChartDataPoint(date: entry.key, value: entry.value);
      }).toList();

      _monthlyChartData.sort((a, b) => a.date.compareTo(b.date));

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

/// Loads weekly adherence data for the 7-day window starting on
/// [_currentWeekStart].  Days strictly after *today* are always ignored.
/// *Today* itself is shown **only if** at least one log already exists for it.
Future<void> loadWeeklyData([DateTime? weekStart]) async {
  if (weekStart != null) {
    _currentWeekStart = _calculateWeekStart(weekStart);
  }

  final requestId = ++_requestCounter;
  _isLoadingWeekly = true;
  _error = null;
  notifyListeners();

  try {
    await _logService.init();

    final medsBox = Hive.box<Med>('meds');
    final medications = medsBox.values.toList();

    if (medications.isEmpty) {
      _weeklyAdherenceData = {};
      _weeklyMedicationData = {};
      _weeklyMedications = [];
      _weeklyInsight = null;
      return;
    }

    final weekEnd = _currentWeekStart.add(const Duration(days: 6));

    // --- helpers for the “today” rule -----------------------------
    final today = DateTime.now();
    final todayKey = _formatDate(today);
    // --------------------------------------------------------------

    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    _weeklyAdherenceData = {};
    _weeklyMedicationData = {};
    final medicationNames = <String>[];

    // ---------- per-medication processing -------------------------
    for (final med in medications) {
      medicationNames.add(med.name);
      _weeklyMedicationData[med.name] = {};

      final logs = await _logService.getLogsForMedicineAndRange(
        med.id,
        _currentWeekStart,
        weekEnd,
      );

      final logMap = <String, LogModel>{
        for (final log in logs) _formatDate(log.date): log,
      };

      for (int i = 0; i < 7; i++) {
        final dayDate = _currentWeekStart.add(Duration(days: i));

        // Skip any day strictly after today
        if (dayDate.isAfter(today)) break;

        final dayKey = dayKeys[i];
        final dateKey = _formatDate(dayDate);

        // If today has no log, skip it
        if (dayDate == today && !logMap.containsKey(dateKey)) continue;

        double dayPercent = 0.0;
        if (logMap.containsKey(dateKey) &&
            _isMedicationActiveOnDate(med, dayDate)) {
          dayPercent = logMap[dateKey]!.percent;
        }

        _weeklyMedicationData[med.name]![dayKey] = dayPercent;
      }
    }

    // ---------- daily averages -----------------------------------
    for (int i = 0; i < 7; i++) {
      final dayDate = _currentWeekStart.add(Duration(days: i));
      if (dayDate.isAfter(today)) break;

      final dayKey = dayKeys[i];
      if (!_weeklyMedicationData[medicationNames.first]!.containsKey(dayKey)) {
        continue; // nothing to average
      }

      double totalPercent = 0.0;
      int activeMedicationCount = 0;

      for (final medName in medicationNames) {
        final medPercent = _weeklyMedicationData[medName]![dayKey] ?? 0.0;
        if (medPercent > 0) {
          totalPercent += medPercent;
          activeMedicationCount++;
        }
      }

      _weeklyAdherenceData[dayKey] = activeMedicationCount > 0
          ? totalPercent / activeMedicationCount
          : 0.0;
    }

    if (requestId != _requestCounter) return;
    _weeklyMedications = medicationNames;

    // ---------- weekly insight -----------------------------------
    double overallSum = 0.0;
    int dayCount = 0;
    for (final percent in _weeklyAdherenceData.values) {
      if (percent > 0) {
        overallSum += percent;
        dayCount++;
      }
    }
    final overallAdherence = dayCount > 0 ? overallSum / dayCount : 0.0;

    final medicationAdherence = <String, double>{};
    for (final medName in medicationNames) {
      double medSum = 0.0;
      int medDayCount = 0;
      for (final dayPercent in _weeklyMedicationData[medName]!.values) {
        if (dayPercent > 0) {
          medSum += dayPercent;
          medDayCount++;
        }
      }
      medicationAdherence[medName] =
          medDayCount > 0 ? medSum / medDayCount : 0.0;
    }

    _weeklyInsight = WeeklyInsight(
      overallAdherence: overallAdherence,
      totalMedications: medications.length,
      medicationAdherence: medicationAdherence,
    );
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

  /// Loads daily data for today (keep existing implementation for daily view)
  Future<void> loadTodayData() async {
    if (_dailyTiles.isNotEmpty) return;

    final requestId = ++_requestCounter;
    _isLoadingToday = true;
    _error = null;
    notifyListeners();

    try {
      _dailyTiles = await getDailyTileData(DateTime.now());
      _dailyPieData = await getDailyPieChartData(DateTime.now());

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

  // --- Chart Data Preparation (Keep existing daily methods unchanged) ---
  
  Future<Map<String, double>> getDailyPieChartData(DateTime date) async {
    final dateStr = _formatDate(date);
    final data = await AnalysisService().getDailyData(dateStr);

    int takenCount = 0;
    int missedCount = 0;
    int trulyNotLoggedCount = 0;
    int totalCount = data.length;

    for (var tile in data) {
      if (tile.status == 'taken') {
        takenCount++;
      } else if (tile.status == 'missed') {
        missedCount++;
      } else if (tile.status == 'not_logged') {
        trulyNotLoggedCount++;
      }
    }

    if (totalCount == 0) {
      return {'taken': 0.0, 'missed': 0.0, 'not_logged': 0.0};
    }

    return {
      'taken': (takenCount / totalCount) * 100,
      'missed': (missedCount / totalCount) * 100,
      'not_logged': (trulyNotLoggedCount / totalCount) * 100,
    };
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

  Future<List<DailyTile>> getDailyTileData(DateTime date) async {
    final dateStr = _formatDate(date);
    final data = await AnalysisService().getDailyData(dateStr);
    return data;
  }

  Future<List<ChartDataPoint>> getMonthlyChartData(DateTime month) async {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    final data = await AnalysisService().getMonthlyData(monthStr);
    
    final result = data.entries.map((entry) {
      return ChartDataPoint(date: entry.key, value: entry.value);
    }).toList();

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // --- Navigation ---
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

  // --- Utility Methods ---
  bool hasDataForCurrentMonth() {
    return _monthlyData.any((d) => d.hasActivity);
  }

  String get currentMonthString {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
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

  // --- Helper Methods ---
  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
    if (startDate.isAfter(targetDate)) return false;
    if (med.endAt != null) {
      final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
      if (endDate.isBefore(targetDate)) return false;
    }
    return true;
  }

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