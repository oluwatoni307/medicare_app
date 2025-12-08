import 'package:flutter/material.dart';
import 'medicine_model.dart';
import 'medicine_view_model.dart'; // FIXED: correct filename
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '/theme.dart';

class MedicationDetailView extends StatelessWidget {
  final String medicineId;
  const MedicationDetailView({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MedicationDetailViewModel()..loadMedicine(medicineId),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Medicine Details'),
          backgroundColor: Colors.transparent,
        ),
        body: const _Body(),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                              PRIVATE WIDGETS                               */
/* -------------------------------------------------------------------------- */
class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicationDetailViewModel>();

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return _ErrorState(
        error: vm.error!,
        onRetry: () =>
            vm.loadMedicine(vm.medicationDetail?.medication.id ?? ''),
      );
    }

    if (vm.medicationDetail == null) {
      return const Center(child: Text('No medicine data found'));
    }

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          /* ----------------------------- Header ----------------------------- */
          SliverToBoxAdapter(
            child: _MedicineHeader(medicationDetail: vm.medicationDetail!),
          ),
          /* ----------------------------- Calendar --------------------------- */
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: _Calendar(vm),
            ),
          ),
          /* ----------------------------- Toggle ----------------------------- */
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              child: _ToggleButton(
                label: vm.showMetrics ? 'Show Schedule' : 'Show Metrics',
                icon: vm.showMetrics ? Icons.schedule : Icons.analytics,
                onPressed: vm.toggleView,
              ),
            ),
          ),
          /* -------------------------- Schedule / Metrics -------------------- */
          if (!vm.showMetrics) _ScheduleSliver(vm) else _MetricsSliver(vm),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingL)),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               UI SECTIONS                                  */
/* -------------------------------------------------------------------------- */
class _MedicineHeader extends StatelessWidget {
  final MedicationDetail medicationDetail;
  const _MedicineHeader({required this.medicationDetail});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final med = medicationDetail.medication;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingXL + kToolbarHeight,
        AppTheme.spacingM,
        AppTheme.spacingM,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(med.name, style: textTheme.displaySmall),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Text(
                'Dosage: ${med.dosage}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'Type: ${med.type}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            'Starts: ${_formatDate(med.startAt)}' +
                (med.endAt != null
                    ? ', Ends: ${_formatDate(med.endAt!)}'
                    : ', Indefinite'),
            style: textTheme.bodySmall?.copyWith(color: AppTheme.lightText),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            'Doses per day: ${med.scheduleTimes.length}',
            style: textTheme.bodySmall?.copyWith(color: AppTheme.lightText),
          ),
        ],
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  final MedicationDetailViewModel vm;
  const _Calendar(this.vm);

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Get date ranges from ViewModel
    final firstDay = vm.getStartDate();
    final lastDay = vm.getEndDate();
    final focusedDay = vm.getFocusedDay(); // This is the KEY fix!

    // Debug assertion to catch issues early
    assert(
      isSameDay(focusedDay, lastDay) || focusedDay.isBefore(lastDay),
      'Focused day ($focusedDay) must be before or equal to last day ($lastDay)',
    );
    assert(
      isSameDay(focusedDay, firstDay) || focusedDay.isAfter(firstDay),
      'Focused day ($focusedDay) must be after or equal to first day ($firstDay)',
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: TableCalendar<String>(
          // CRITICAL: Use ViewModel methods for date constraints
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay:
              focusedDay, // FIXED: No longer using DateTime.now() directly
          daysOfWeekHeight: 45.0,
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          availableGestures: AvailableGestures.horizontalSwipe,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            selectedDecoration: const BoxDecoration(
              color: AppTheme.primaryAction,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppTheme.primaryAction.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          selectedDayPredicate: (day) => vm.selectedDate == _formatDate(day),
          onDaySelected: (selected, _) {
            // Only allow selection of dates within range
            if (vm.isDateInRange(selected)) {
              vm.selectDate(_formatDate(selected));
            }
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, _) =>
                _CalendarDay(day, vm, isSelected: false, isToday: false),
            todayBuilder: (context, day, _) =>
                _CalendarDay(day, vm, isSelected: false, isToday: true),
            selectedBuilder: (context, day, _) =>
                _CalendarDay(day, vm, isSelected: true, isToday: false),
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime day;
  final MedicationDetailViewModel vm;
  final bool isSelected;
  final bool isToday;

  const _CalendarDay(
    this.day,
    this.vm, {
    required this.isSelected,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(day);
    final inRange = vm.isDateInRange(day);
    final color = vm.getDayColor(dateStr);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? AppTheme.primaryAction
            : isToday
            ? AppTheme.primaryAction.withOpacity(0.5)
            : inRange
            ? color.withOpacity(0.7)
            : null,
        border: inRange && !isSelected && !isToday
            ? Border.all(color: AppTheme.primaryAction, width: 1)
            : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: (isSelected || isToday) ? Colors.white : Colors.black87,
            fontWeight: inRange ? FontWeight.w600 : null,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: AppTheme.primaryAction,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/* ------------------------------- Schedule --------------------------------- */
class _ScheduleSliver extends StatelessWidget {
  final MedicationDetailViewModel vm;
  const _ScheduleSliver(this.vm);

  @override
  Widget build(BuildContext context) {
    final date = vm.selectedDate ?? _formatDate(DateTime.now());
    final schedules = vm.getDaySchedules(date);

    if (schedules.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No scheduled doses for this day',
            style: TextStyle(color: AppTheme.lightText),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
            child: _ScheduleCard(schedules[index]),
          ),
          childCount: schedules.length,
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const _ScheduleCard(this.schedule);

  @override
  Widget build(BuildContext context) {
    final status = schedule['status'] as String;
    final timeOfDay = schedule['time'] as TimeOfDay;
    final timeString =
        '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';

    final (color, icon, label) = switch (status) {
      'taken' => (Colors.green, Icons.check_circle, 'Taken'),
      'missed' => (Colors.red, Icons.cancel, 'Missed'),
      _ => (Colors.orange, Icons.schedule, 'Pending'),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(timeString, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(label, style: Theme.of(context).textTheme.bodySmall),
        trailing: Chip(
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          backgroundColor: color.withOpacity(0.15),
          side: BorderSide(color: color),
        ),
      ),
    );
  }
}

/* -------------------------------- Metrics --------------------------------- */
class _MetricsSliver extends StatelessWidget {
  final MedicationDetailViewModel vm;
  const _MetricsSliver(this.vm);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: AppTheme.spacingM,
        crossAxisSpacing: AppTheme.spacingM,
        childAspectRatio: 1.1,
        children: [
          _MetricCard(
            'Overall Adherence',
            '${vm.getAdherencePercentage().toStringAsFixed(1)}%',
            Icons.pie_chart,
            AppTheme.primaryAction,
          ),
          _MetricCard(
            'Current Streak',
            '${vm.getCurrentStreak()} days',
            Icons.local_fire_department,
            Colors.orange,
          ),
          _MetricCard(
            'Doses Taken',
            vm.getTakenDosesCount().toString(),
            Icons.check_circle,
            Colors.green,
          ),
          _MetricCard(
            'Doses Missed',
            vm.getMissedDosesCount().toString(),
            Icons.cancel,
            Colors.red,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _MetricCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                            RE-USABLE HELPERS                               */
/* -------------------------------------------------------------------------- */
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Error loading medicine details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.lightText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                            FORMAT HELPERS                                */
/* -------------------------------------------------------------------------- */
String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
