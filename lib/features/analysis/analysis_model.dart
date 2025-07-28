// lib/features/analysis/analysis_model.dart

// --- Data Models for Analysis Feature ---

/// Represents a daily summary of medication adherence for a specific date.
class DailySummary {
  final String date; // ISO date (e.g., "2024-01-01")
  final double adherencePercentage; // Percentage of doses taken
  final bool hasActivity; // Indicates if any doses were scheduled

  DailySummary({
    required this.date,
    required this.adherencePercentage,
    required this.hasActivity,
  });

  /// Creates an empty summary for a date with no activity.
  factory DailySummary.empty(String date) => DailySummary(
        date: date,
        adherencePercentage: 0.0,
        hasActivity: false,
      );
}

/// Represents weekly adherence insights, including per-medication adherence.
class WeeklyInsight {
  final double overallAdherence; // Overall adherence percentage for the week
  final int totalMedications; // Number of unique medications tracked
  final Map<String, double> medicationAdherence; // Medication name to adherence %

  WeeklyInsight({
    required this.overallAdherence,
    required this.totalMedications,
    required this.medicationAdherence,
  });
}

/// Represents a single medication dose for the daily tile list.
class DailyTile {
  final String name; // Medication name
  final String time; // Dose time (e.g., "08:00")
  final String status; // Dose status (taken, missed, not_logged)

  DailyTile({
    required this.name,
    required this.time,
    required this.status,
  });
}

/// Represents a data point for the monthly adherence trend chart.
class ChartDataPoint {
  final String date; // ISO date (e.g., "2024-01-01")
  final double value; // Adherence percentage

  ChartDataPoint({
    required this.date,
    required this.value,
  });
}