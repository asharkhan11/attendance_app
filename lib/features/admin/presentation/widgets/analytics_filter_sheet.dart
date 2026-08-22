import 'package:flutter/material.dart';
import '../../../../design_system/app_spacing.dart';
import '../../../../models/app_models.dart';
import '../../../../widgets/searchable_dropdown.dart';

class AnalyticsFilterSheet extends StatefulWidget {
  final List<SchoolClass> classes;
  final SchoolClass? selectedClass;
  final double threshold;
  final ValueChanged<SchoolClass?> onClassChanged;
  final ValueChanged<double> onThresholdChanged;

  const AnalyticsFilterSheet({
    super.key,
    required this.classes,
    required this.selectedClass,
    required this.threshold,
    required this.onClassChanged,
    required this.onThresholdChanged,
  });

  static void show(
    BuildContext context, {
    required List<SchoolClass> classes,
    required SchoolClass? selectedClass,
    required double threshold,
    required ValueChanged<SchoolClass?> onClassChanged,
    required ValueChanged<double> onThresholdChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AnalyticsFilterSheet(
        classes: classes,
        selectedClass: selectedClass,
        threshold: threshold,
        onClassChanged: onClassChanged,
        onThresholdChanged: onThresholdChanged,
      ),
    );
  }

  @override
  State<AnalyticsFilterSheet> createState() => _AnalyticsFilterSheetState();
}

class _AnalyticsFilterSheetState extends State<AnalyticsFilterSheet> {
  late double _localThreshold;
  late SchoolClass? _localClass;

  @override
  void initState() {
    super.initState();
    _localThreshold = widget.threshold;
    _localClass = widget.selectedClass;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analytics Filters',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SearchableDropdown<SchoolClass?>(
            value: _localClass,
            labelText: 'Class',
            items: [null, ...(List<SchoolClass>.from(widget.classes)..sort(compareSchoolClasses))],
            itemAsString: (c) => c == null ? 'All Classes' : c.displayName,
            onChanged: (v) => setState(() => _localClass = v),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Defaulter Threshold: ${_localThreshold.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _localThreshold,
            min: 30,
            max: 95,
            divisions: 13,
            label: '${_localThreshold.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _localThreshold = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              widget.onClassChanged(_localClass);
              widget.onThresholdChanged(_localThreshold);
              Navigator.pop(context);
            },
            child: const Text('APPLY FILTERS'),
          ),
        ],
      ),
    );
  }
}
