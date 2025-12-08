import 'package:flutter/material.dart';

/// Today's summary data across all medications
class TodaysSummary {
  final int totalDoses;
  final int takenDoses;
  final double overallPercent;
  final String? nextDoseInfo;

  TodaysSummary({
    required this.totalDoses,
    required this.takenDoses,
    required this.overallPercent,
    this.nextDoseInfo,
  });

  /// Helper getters
  int get missedDoses => totalDoses - takenDoses;
  bool get hasData => totalDoses > 0;
  bool get isComplete => totalDoses > 0 && takenDoses == totalDoses;

  @override
  String toString() {
    return 'TodaysSummary(taken: $takenDoses/$totalDoses, percent: ${overallPercent.toStringAsFixed(1)}%)';
  }
}

/// Medication information with adherence status
class MedicationInfo {
  final String id;
  final String name;
  final String imageUrl;
  final int takenDoses;
  final int totalDoses;
  final double adherencePercent;
  final bool hasScheduleToday;
  final bool isCompleteToday;

  MedicationInfo({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.takenDoses = 0,
    this.totalDoses = 0,
    this.adherencePercent = 0.0,
    this.hasScheduleToday = true,
    this.isCompleteToday = false,
  });

  /// Simple badge text for display
  String? get displayBadge {
    if (!hasScheduleToday) return '—';
    if (isCompleteToday) return '✓';
    if (takenDoses == 0) return null; // Show dot instead
    return '$takenDoses/$totalDoses';
  }

  /// Badge color (subtle, theme-aligned)
  Color get badgeColor {
    if (isCompleteToday) {
      return const Color(0xFF059669); // AppTheme.accent (emerald)
    } else if (takenDoses > 0) {
      return const Color(0xFF1E40AF); // AppTheme.primaryAction (deep blue)
    } else {
      return const Color(0xFF64748B); // AppTheme.lightText (grey)
    }
  }

  /// Background color for badge
  Color get badgeBackgroundColor {
    if (isCompleteToday) {
      return const Color(0xFF059669).withOpacity(0.15); // Very light emerald
    } else if (takenDoses > 0) {
      return const Color(0xFFF1F5F9); // AppTheme.surfaceHover
    } else {
      return const Color(0xFFF8FAFC); // AppTheme.surfaceMuted
    }
  }

  /// Border color for badge
  Color get badgeBorderColor {
    if (isCompleteToday) {
      return const Color(0xFF059669).withOpacity(0.3); // Soft emerald border
    } else if (takenDoses > 0) {
      return const Color(0xFFE2E8F0); // AppTheme.outlineVariant
    } else {
      return const Color(
        0xFFCBD5E1,
      ).withOpacity(0.4); // AppTheme.outline with opacity
    }
  }

  /// Should this card be dimmed/greyed?
  bool get shouldDim => isCompleteToday;

  /// Card opacity
  double get cardOpacity => shouldDim ? 0.65 : 1.0;

  factory MedicationInfo.fromMap(Map<String, dynamic> map) {
    return MedicationInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      imageUrl: _getImageUrlForType(map['type']),
      takenDoses: map['takenDoses'] ?? 0,
      totalDoses: map['totalDoses'] ?? 0,
      adherencePercent: (map['adherencePercent'] ?? 0.0).toDouble(),
      hasScheduleToday: map['hasScheduleToday'] ?? true,
      isCompleteToday: map['isCompleteToday'] ?? false,
    );
  }

  static String _getImageUrlForType(String? type) {
    if (type == null) return 'images/types/default.png';
    return 'images/types/$type.png';
  }

  @override
  String toString() {
    return 'MedicationInfo(name: $name, status: $takenDoses/$totalDoses, complete: $isCompleteToday)';
  }
}

/// Homepage data container
class HomepageData {
  final int upcomingMedicationCount;
  final List<MedicationInfo> medications;
  final TodaysSummary? todaysSummary;

  HomepageData({
    required this.upcomingMedicationCount,
    required this.medications,
    this.todaysSummary,
  });

  /// Helper getter for UI
  bool get hasSummary => todaysSummary != null && todaysSummary!.hasData;

  factory HomepageData.initial() {
    return HomepageData(
      upcomingMedicationCount: 0,
      medications: [],
      todaysSummary: null,
    );
  }

  @override
  String toString() {
    return 'HomepageData(count: $upcomingMedicationCount, meds: ${medications.length}, summary: $todaysSummary)';
  }
}
