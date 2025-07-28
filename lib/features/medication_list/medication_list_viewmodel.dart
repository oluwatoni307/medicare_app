// medication_list_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../AddMedication/AddMedication_model.dart';
import '../auth/service.dart';

class MedicationListViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  List<MedicationModel> _medications = [];
  bool _isLoading = false;
  final SupabaseClient _client = Supabase.instance.client;

  List<MedicationModel> get medications => _medications;
  bool get isLoading => _isLoading;

  // Active = end_date >= today
  List<MedicationModel> get activeMedications => _medications.where(_isMedicationActive).toList();

  // Completed = end_date < today
  List<MedicationModel> get completedMedications => _medications.where((m) => !_isMedicationActive(m)).toList();
bool _isMedicationActive(MedicationModel medication) {
  final endDateString = _medicationEndDates[medication.id];
  if (endDateString == null) return true;

  final endDate = DateTime.tryParse(endDateString);
  if (endDate == null) return true;

  final today = DateTime.now();
  return endDate.isAfter(today) || endDate.isAtSameMomentAs(today);
}
  MedicationListViewModel() {
    fetchMedications();
  }

  Future<void> fetchMedications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        _medications = [];
      } else {
        _medications = await getMedications(user.id);
      }
    } catch (e) {
      print('Fetch medications error: $e');
      _medications = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshMedications() async {
    await fetchMedications();
  }

  // Delete medication (schedules first due to FK)
  Future<void> deleteMedication(String medicationId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _client.from('schedules').delete().eq('medicine_id', medicationId);
      await _client.from('medicines').delete().eq('id', medicationId);

      await fetchMedications();
    } catch (e) {
      print('Delete medication error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  MedicationModel? getMedicationById(String id) {
    try {
      return _medications.firstWhere((med) => med.id == id);
    } catch (e) {
      return null;
    }
  }

// Store end dates separately
final Map<String, String> _medicationEndDates = {};

// In getMedications():
Future<List<MedicationModel>> getMedications(String userId) async {
  try {
    final response = await _client
        .from('medicines')
        .select('id, name, dosage, type, schedules(start_date, end_date)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;

    // Clear old end dates
    _medicationEndDates.clear();

    return data.map((json) {
      final schedules = json['schedules'] as List<dynamic>? ?? [];
      final firstSchedule = schedules.isNotEmpty ? schedules[0] as Map<String, dynamic> : null;

      // Extract end_date and save it separately
      final endDate = firstSchedule?['end_date'] as String?;
      if (endDate != null) {
        _medicationEndDates[json['id']] = endDate;
      }

      return MedicationModel(
        id: json['id'],
        medicationName: json['name'],
        dosage: json['dosage'],
        type: json['type'],
        // Only pass fields that exist in the model
      );
    }).toList();
  } catch (e) {
    throw Exception('Get medications error: $e');
  }
}

  // Search medications
  List<MedicationModel> searchMedications(String query) {
    final queryLower = query.toLowerCase();
    return _medications.where((med) {
      final name = med.medicationName?.toLowerCase() ?? '';
      return name.contains(queryLower);
    }).toList();
  }
}