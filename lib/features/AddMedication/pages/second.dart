import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../AddMedication_viewmodel.dart' show MedicationViewModel;

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicationViewModel>(
      builder: (context, viewModel, child) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Start date",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                CalendarWidget(
                  selectedDay: viewModel.medication.startDate,
                  onDaySelected: (selectedDay, focusedDay) {
                    viewModel.updateStartDate(selectedDay);
                  },
                ),
                const SizedBox(height: 20),

                // --- REPLACED Interval and Start Time ---
                const Text(
                  "Schedule Times",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                ScheduleTimesWidget( // New Widget
                  selectedTimes: viewModel.medication.scheduleTimes ?? [],
                  onTimesUpdated: (times) {
                    viewModel.updateScheduleTimes(times);
                  },
                  onAddTime: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      viewModel.addScheduleTime(picked);
                    }
                  },
                ),
                // --- END REPLACEMENT ---

                const SizedBox(height: 20),
                const Text(
                  "Duration",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                DurationDropdown(
                  selectedDuration: viewModel.medication.duration,
                  onDurationSelected: (duration) {
                    viewModel.updateDuration(duration);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// --- NEW WIDGET WITH IMPROVED AESTHETICS ---
class ScheduleTimesWidget extends StatelessWidget {
  final List<TimeOfDay> selectedTimes;
  final ValueChanged<List<TimeOfDay>> onTimesUpdated;
  final VoidCallback onAddTime;

  const ScheduleTimesWidget({
    Key? key,
    required this.selectedTimes,
    required this.onTimesUpdated,
    required this.onAddTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display selected times with remove buttons
        if (selectedTimes.isNotEmpty)
          SizedBox(
            // Adjust height based on content or use IntrinsicHeight?
            // Let's use a Wrap for better flow on smaller screens
            width: double.infinity,
            child: Wrap(
              spacing: 8.0, // gap between chips
              runSpacing: 4.0, // gap between lines
              children: selectedTimes.map((time) {
                return InputChip(
                  label: Text(time.format(context)),
                  onDeleted: () {
                    final newTimes = List<TimeOfDay>.from(selectedTimes)..remove(time);
                    onTimesUpdated(newTimes);
                  },
                  deleteIcon: const Icon(Icons.close, size: 18),
                  // Style the chip to match your app's theme
                  backgroundColor: colorScheme.primaryContainer,
                  deleteIconColor: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.outline.withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 10),

        // Add Time Button - Styled like TimePickerWidget
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAddTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48, // Match TimePickerWidget height
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface, // Match TimePickerWidget
                border: Border.all(
                  color: colorScheme.outline, // Match TimePickerWidget
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add Time',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary, // Make it look actionable
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time, // Use time icon for consistency
                    size: 20,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// --- END NEW WIDGET ---

// ... (Keep CalendarWidget, DurationDropdown, TimePickerWidget as they are, 
//      although TimePickerWidget might now be unused unless needed elsewhere)
class CalendarWidget extends StatefulWidget {
  final Function(DateTime, DateTime)? onDaySelected;
  final DateTime? selectedDay;

  const CalendarWidget({Key? key, this.onDaySelected, this.selectedDay}) : super(key: key);

  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDay ?? DateTime.now(); // Default to today
    _focusedDay = _selectedDay ?? DateTime.now();
  }

  @override
  void didUpdateWidget(CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDay != oldWidget.selectedDay) {
      _selectedDay = widget.selectedDay ?? DateTime.now();
      _focusedDay = _selectedDay ?? DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TableCalendar(
        firstDay: DateTime.now(), // Restrict to today or future
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          if (widget.onDaySelected != null) {
            widget.onDaySelected!(selectedDay, focusedDay);
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
        ),
      ),
    );
  }
}

class IntervalDropdown extends StatelessWidget {
  final ValueChanged<int>? onIntervalSelected;
  final int? selectedInterval;
  final bool enabled;
  final String? label;
  final String? hint;

  const IntervalDropdown({
    super.key,
    this.onIntervalSelected,
    this.selectedInterval,
    this.enabled = true,
    this.label,
    this.hint,
  });

  static const List<int> intervals = [1, 2, 4, 6, 8, 12, 24];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled 
                ? colorScheme.surface 
                : colorScheme.surfaceVariant.withOpacity(0.5),
            border: Border.all(
              color: enabled 
                  ? colorScheme.outline 
                  : colorScheme.outline.withOpacity(0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<int>(
            value: selectedInterval,
            hint: Text(
              hint ?? 'Select interval',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            underline: const SizedBox(),
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: enabled 
                  ? colorScheme.onSurface 
                  : colorScheme.onSurface.withOpacity(0.38),
            ),
            dropdownColor: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            onChanged: enabled ? (value) => onIntervalSelected?.call(value!) : null,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
            items: intervals.map((interval) {
              return DropdownMenuItem<int>(
                value: interval,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '$interval ${interval == 1 ? "hour" : "hours"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class DurationDropdown extends StatelessWidget {
  final ValueChanged<String>? onDurationSelected;
  final String? selectedDuration;
  final bool enabled;
  final String? label;
  final String? hint;

  const DurationDropdown({
    super.key,
    this.onDurationSelected,
    this.selectedDuration,
    this.enabled = true,
    this.label,
    this.hint,
  });

  static const List<String> durations = [
    '1 day', '2 days', '3 days', '4 days', '5 days', '6 days', '7 days',
    '14 days', '21 days', '30 days', '3 months', '6 months', 'indefinitely'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled 
                ? colorScheme.surface 
                : colorScheme.surfaceVariant.withOpacity(0.5),
            border: Border.all(
              color: enabled 
                  ? colorScheme.outline 
                  : colorScheme.outline.withOpacity(0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: selectedDuration,
            hint: Text(
              hint ?? 'Select duration',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            underline: const SizedBox(),
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: enabled 
                  ? colorScheme.onSurface 
                  : colorScheme.onSurface.withOpacity(0.38),
            ),
            dropdownColor: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            onChanged: enabled ? (value) => onDurationSelected?.call(value!) : null,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
            items: durations.map((duration) {
              return DropdownMenuItem<String>(
                value: duration,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    duration,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class TimePickerWidget extends StatelessWidget {
  final ValueChanged<TimeOfDay>? onTimeSelected;
  final TimeOfDay? selectedTime;
  final bool enabled;
  final String? label;
  final String? hint;
  final String? errorText;

  const TimePickerWidget({
    super.key,
    this.onTimeSelected,
    this.selectedTime,
    this.enabled = true,
    this.label,
    this.hint,
    this.errorText,
  });

  Future<void> _selectTime(BuildContext context) async {
    if (!enabled) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteColor: Theme.of(context).colorScheme.surfaceVariant,
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurfaceVariant,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
              entryModeIconColor: Theme.of(context).colorScheme.onSurface,
              helpTextStyle: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedTime) {
      onTimeSelected?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectTime(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: enabled 
                    ? colorScheme.surface 
                    : colorScheme.surfaceVariant.withOpacity(0.5),
                border: Border.all(
                  color: errorText != null
                      ? colorScheme.error
                      : enabled 
                          ? colorScheme.outline 
                          : colorScheme.outline.withOpacity(0.5),
                  width: errorText != null ? 2.0 : 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: selectedTime != null
                        ? Text(
                            selectedTime!.format(context),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: enabled 
                                  ? colorScheme.onSurface 
                                  : colorScheme.onSurface.withOpacity(0.38),
                            ),
                          )
                        : Text(
                            hint ?? 'Select time',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                  ),
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: enabled 
                        ? colorScheme.onSurface.withOpacity(0.7)
                        : colorScheme.onSurface.withOpacity(0.38),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}