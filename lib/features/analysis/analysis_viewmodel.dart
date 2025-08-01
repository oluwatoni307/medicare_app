// lib/features/analysis/analysis_viewmodel.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/foundation.dart';
// --- Update import for models ---
import 'analysis_model.dart'; // Adjust path if needed
// --- Update import for the refactored service ---
import 'service.dart'; // Adjust path if needed
// --- Remove AuthService import ---
// import '../auth/service.dart'; // No longer needed

// --- Analysis ViewModel for managing adherence data and chart preparation ---
// --- Updated to work with the refactored Hive-based AnalysisService ---
class AnalysisViewModel extends ChangeNotifier {
  // --- Initialization ---
  // --- Remove AuthService ---
  // final AuthService _authService;
  /// Initializes the ViewModel with the refactored AnalysisService.
  AnalysisViewModel() { // Removed AuthService parameter
    // _authService = authService ?? AuthService(); // Removed
    // Initialize with default data or trigger initial load if needed
    // For example, load data for the default view (Monthly) on creation
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   loadMonthlyData(_currentMonth);
    // });
  }

  // --- State Variables ---
  // Inside AnalysisViewModel class

// Add this field to store the raw weekly data
Map<String, double> _weeklyAdherenceData = {};

// Add this getter
Map<String, double> get weeklyAdherenceData => _weeklyAdherenceData;
  String _selectedView = 'Monthly'; // Current view (Daily, Weekly, Monthly)
  bool _isLoadingMonthly = false; // Loading state for monthly data
  bool _isLoadingWeekly = false; // Loading state for weekly data
  bool _isLoadingToday = false; // Loading state for daily data
  List<DailySummary> _monthlyData = []; // Monthly adherence summaries
  WeeklyInsight? _weeklyInsight; // Weekly adherence insights
  List<DailyTile> _dailyTiles = []; // Daily medication tiles
  Map<String, double> _dailyPieData = {}; // Daily pie chart data
  List<ChartDataPoint> _monthlyChartData = []; // Monthly trend chart data
  DateTime _currentMonth = DateTime.now(); // Current month for data
  DateTime _currentWeekStart = _calculateWeekStart(DateTime.now()); // Start of current week (Monday)
  String? _error; // Error message for UI display
  // Request tracking for preventing race conditions
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
    // Calculate average based on DailySummary.adherencePercentage
    return activeDays
        .map((d) => d.adherencePercentage)
        .reduce((a, b) => a + b) / activeDays.length;
  }
  
  int get totalMedicationsTracked {
    return _weeklyInsight?.totalMedications ?? 0;
  }
  
  // --- Removed userId getter ---
  // String? get _userId => _authService.getCurrentUser()?.id; // Removed

  // --- Tab Handling ---
  /// Sets the current view and triggers data loading for the selected view.
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
  /// Loads monthly adherence data for the specified month.
  Future<void> loadMonthlyData([DateTime? month]) async {
    if (month != null) _currentMonth = month;
    
    // --- Removed userId check ---
    // final userId = _userId;
    // if (userId == null) {
    //   _error = 'User not authenticated';
    //   notifyListeners();
    //   return;
    // }
    
    final requestId = ++_requestCounter;
    _isLoadingMonthly = true;
    _error = null;
    notifyListeners();
    
    try {
      final monthStr = "${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}";
      
      // --- CHANGED: Call refactored service method ---
      // Old: final data = await AnalysisService.getMonthlyData(userId, monthStr);
      final data = await AnalysisService().getMonthlyData(monthStr); // No userId needed
      // --- END CHANGE ---
      
      // Check if this request is still current
      if (requestId != _requestCounter) return;

      // --- CHANGED: Process new data structure ---
      // Old data was Map<String, Map<String, int>> (date -> {scheduled, taken, missed, not_logged})
      // New data is Map<String, double> (date -> average adherence percentage)
      
      // Create DailySummary objects
      _monthlyData = data.entries.map((entry) {
        final dateStr = entry.key;
        final averagePercent = entry.value;
        // hasActivity is true if there was data for the day (averagePercent >= 0)
        // A more precise check might be averagePercent > 0, depending on how 0% is handled
        final hasActivity = true; // If it's in the map, there was activity
        return DailySummary(
          date: dateStr,
          adherencePercentage: averagePercent,
          hasActivity: hasActivity,
        );
      }).toList();
      
      // Prepare chart data points
      _monthlyChartData = data.entries.map((entry) {
        return ChartDataPoint(
          date: entry.key,
          value: entry.value,
        );
      }).toList();
      
      // Sort chart data by date if needed (depends on Map iteration order, usually okay)
      _monthlyChartData.sort((a, b) => a.date.compareTo(b.date));
      
      // --- END CHANGE ---
      
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

  /// Loads weekly adherence data for the specified week.
  Future<void> loadWeeklyData([DateTime? weekStart]) async {
    if (weekStart != null) {
      _currentWeekStart = _calculateWeekStart(weekStart); // Ensure it's Monday
    }
    
    // --- Removed userId check ---
    // final userId = _userId;
    // if (userId == null) {
    //   _error = 'User not authenticated';
    //   notifyListeners();
    //   return;
    // }
    
    final requestId = ++_requestCounter;
    _isLoadingWeekly = true;
    _error = null;
    notifyListeners();
    
    try {
      final endDate = _currentWeekStart.add(const Duration(days: 6));
      final startDateStr = _formatDate(_currentWeekStart);
      final endDateStr = _formatDate(endDate);
      
      // --- CHANGED: Call refactored service method ---
      // Old: final data = await AnalysisService.getWeeklyData(userId, startDateStr, endDateStr);
      final data = await AnalysisService().getWeeklyData(startDateStr, endDateStr); // No userId needed
      _weeklyAdherenceData = data;
      // --- END CHANGE ---
      
      // Check if this request is still current
      if (requestId != _requestCounter) return;

      // --- CHANGED: Process new data structure ---
      // Old data was Map<String, List<Map<...>>> (day abbr -> list of schedule details)
      // New data is Map<String, double> (day abbr -> average adherence percentage for that day)
      
      // For WeeklyInsight, we need to adapt:
      // overallAdherence: Average of the 7 daily averages
      // totalMedications: Harder to determine from averages alone. 
      //                   We could approximate or change the model.
      //                   Let's assume we can't easily get this from averages and set to 0 or N/A.
      // medicationAdherence: Also hard from averages. Could be empty or omitted.
      
      double overallSum = 0.0;
      int dayCount = 0;
      for (var percent in data.values) {
        overallSum += percent;
        dayCount++;
      }
      final overallAdherence = dayCount > 0 ? overallSum / dayCount : 0.0;
      
      // Approximate total medications: This is a simplification.
      // We don't have direct access to unique meds per day anymore.
      // One way: Get all unique medication names from DailyTiles if loaded, 
      // or make an assumption. For now, let's leave it as 0 or find another way.
      // Let's assume the service or a different call would be needed for this detail.
      // Or, if the UI doesn't strictly need it, we can set it to 0 or omit.
      // For this example, let's set it to 0 as we can't easily derive it.
      final totalMedications = 0; 
      
      // medicationAdherence map: We can't easily populate this from daily averages.
      // It required per-med data per day. We might need a different service call 
      // (like getWeeklyMedicineData for each med) or change the UI expectation.
      // For now, leave it empty.
      final medicationAdherence = <String, double>{};
      
      _weeklyInsight = WeeklyInsight(
        overallAdherence: overallAdherence,
        totalMedications: totalMedications, // Simplified/Unavailable
        medicationAdherence: medicationAdherence, // Simplified/Unavailable
      );
      // --- END CHANGE ---
      
    } catch (e) {
      if (requestId == _requestCounter) {
        _error = 'Failed to load weekly data: ${e.toString()}';
        _weeklyInsight = null;
      }
    } finally {
      if (requestId == _requestCounter) {
        _isLoadingWeekly = false;
        notifyListeners();
      }
    }
  }

  /// Loads daily data for today (pie chart and tiles).
  Future<void> loadTodayData() async {
    // --- Removed userId check ---
    // final userId = _userId;
    // if (userId == null) {
    //   _error = 'User not authenticated';
    //   notifyListeners();
    //   return;
    // }
    
    final requestId = ++_requestCounter;
    _isLoadingToday = true;
    _error = null;
    notifyListeners();
    
    try {
      // --- CHANGED: Use helper methods that call refactored service ---
      _dailyTiles = await getDailyTileData(DateTime.now());
      _dailyPieData = await getDailyPieChartData(DateTime.now());
      // --- END CHANGE ---
      
      // Check if this request is still current
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

  // --- Chart Data Preparation ---
  /// Prepares data for the daily pie chart (taken, missed, not_logged percentages).
  /// Note: With the new model, 'missed' and 'not_logged' distinction is lost in the service.
  /// This method now just categorizes based on 'taken' vs. 'not taken' (represented as 'not_logged' in pie).
  Future<Map<String, double>> getDailyPieChartData(DateTime date) async {
    // --- Removed userId check ---
    // final userId = _userId;
    // if (userId == null) return {'taken': 0.0, 'missed': 0.0, 'not_logged': 0.0};
    
    final dateStr = _formatDate(date);
    
    // --- CHANGED: Call refactored service method ---
    // Old: final data = await AnalysisService.getDailyData(userId, dateStr);
    final data = await AnalysisService().getDailyData(dateStr); // No userId needed
    // --- END CHANGE ---
    
    // --- CHANGED: Process new data structure ---
    // Old data was List<Map<String, String>> (list of {id, name, time, status})
    // New data is List<DailyTile> (list of {name, time, status})
    // Status is now 'taken' or 'not_logged' (or potentially 'missed' if inferred)
    
    int takenCount = 0;
    int notTakenCount = 0; // Combines missed/not_logged based on service logic
    int totalCount = data.length;

    for (var tile in data) {
      if (tile.status == 'taken') {
        takenCount++;
      } else {
        // This covers 'missed', 'not_logged', or any other non-'taken' status
        notTakenCount++; 
      }
    }

    if (totalCount == 0) {
      return {'taken': 0.0, 'missed': 0.0, 'not_logged': 0.0};
    }

    // Distribute notTakenCount between 'missed' and 'not_logged' if needed,
    // or lump it all into one category for the pie chart.
    // For simplicity, let's put all not-taken into 'not_logged' for the pie.
    // If the service distinguishes 'missed', it will be in the status.
    // Let's assume status can be 'taken', 'missed', 'not_logged'.
    int missedCount = 0;
    int trulyNotLoggedCount = 0;
    for (var tile in data) {
        if (tile.status == 'missed') {
            missedCount++;
        } else if (tile.status == 'not_logged') {
             trulyNotLoggedCount++;
        }
        // 'taken' is already counted
    }
    // If service only provides 'taken'/'not_logged', missedCount will be 0.
    
    return {
      'taken': (takenCount / totalCount) * 100,
      'missed': (missedCount / totalCount) * 100,
      'not_logged': (trulyNotLoggedCount / totalCount) * 100,
      // Or, if combining:
      // 'not_logged': (notTakenCount / totalCount) * 100,
    };
    // --- END CHANGE ---
  }

  /// Prepares data for the daily tile list (medication name, time, status).
  Future<List<DailyTile>> getDailyTileData(DateTime date) async {
    // --- Removed userId check ---
    // final userId = _userId;
    // if (userId == null) return [];
    
    final dateStr = _formatDate(date);
    
    // --- CHANGED: Call refactored service method ---
    // Old: final data = await AnalysisService.getDailyData(userId, dateStr);
    final data = await AnalysisService().getDailyData(dateStr); // No userId needed, returns List<DailyTile>
    // --- END CHANGE ---
    
    // --- CHANGED: Return data directly ---
    // Old: Mapped List<Map<...>> to List<DailyTile>
    // New: Service already returns List<DailyTile>
    return data; // Return the list of DailyTile objects directly
    // --- END CHANGE ---
  }

  // --- REMOVED: getWeeklyTableData ---
  // This method relied heavily on the old data structure and detailed per-schedule data.
  // With the refactored service returning averages, this specific logic is no longer viable
  // without significant changes or a new service endpoint.
  // If needed, it would require a different approach or service call.
  // For now, we remove it or mark it as not implemented.
  /*
  /// Prepares data for the weekly adherence table (medication vs. day percentages).
  /// [NOT IMPLEMENTED with new service returning averages]
  Future<Map<String, Map<String, double>>> getWeeklyTableData(DateTime startDate) async {
    // Implementation would need to change significantly or require new service methods
    // that provide per-medication daily data.
    return {}; 
  }
  */
  // --- END REMOVAL ---

  /// Prepares data for the monthly adherence trend line chart.
  /// This logic is largely handled in loadMonthlyData now.
  /// This helper can be simplified or removed if loadMonthlyData handles chart data.
  Future<List<ChartDataPoint>> getMonthlyChartData(DateTime month) async {
    // --- Removed userId check ---
    // final userId = _userId;
    // if (userId == null) return [];
    
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    
    // --- CHANGED: Call refactored service method ---
    // Old: final data = await AnalysisService.getMonthlyData(userId, monthStr);
    final data = await AnalysisService().getMonthlyData(monthStr); // No userId needed
    // --- END CHANGE ---
    
    // --- CHANGED: Process new data structure ---
    // Old: Processed Map<String, Map<...>> to List<ChartDataPoint>
    // New: Process Map<String, double> to List<ChartDataPoint>
    final result = data.entries.map((entry) {
        return ChartDataPoint(
          date: entry.key,
          value: entry.value,
        );
    }).toList();
    
    // Ensure sorted by date
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
    // --- END CHANGE ---
  }

  // --- Navigation ---
  /// Navigates to the previous month and reloads data.
  Future<void> goToPreviousMonth() async {
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    await loadMonthlyData(previousMonth);
  }

  /// Navigates to the next month and reloads data.
  Future<void> goToNextMonth() async {
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    await loadMonthlyData(nextMonth);
  }

  /// Navigates to the previous week and reloads data.
  Future<void> goToPreviousWeek() async {
    final previousWeek = _currentWeekStart.subtract(const Duration(days: 7));
    await loadWeeklyData(previousWeek);
  }

  /// Navigates to the next week and reloads data.
  Future<void> goToNextWeek() async {
    final nextWeek = _currentWeekStart.add(const Duration(days: 7));
    await loadWeeklyData(nextWeek);
  }

  // --- Utility Methods ---
  /// Checks if the current month has any adherence data.
  bool hasDataForCurrentMonth() {
    return _monthlyData.any((d) => d.hasActivity);
  }

  /// Formats the current month as a string (e.g., "January 2025").
  String get currentMonthString {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  /// Formats the current week as a string (e.g., "1/7 - 7/7").
  String get currentWeekString {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final startStr = '${_currentWeekStart.day}/${_currentWeekStart.month}';
    final endStr = '${weekEnd.day}/${weekEnd.month}';
    return '$startStr - $endStr';
  }

  /// Clears any error message and notifies listeners.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refreshes data for the current view.
  Future<void> refreshData() async {
    await loadAllData();
  }

  /// Loads data for all views based on the selected view.
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
  
  /// Helper to calculate the start of the week (Monday) for a given date
  static DateTime _calculateWeekStart(DateTime date) {
    // DateTime.weekday: 1=Monday, 7=Sunday
    final dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }
  
  /// Helper to format DateTime to YYYY-MM-DD string.
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _requestCounter++; // Cancel any pending requests
    super.dispose();
  }
}