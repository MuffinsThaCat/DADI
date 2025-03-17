import 'package:flutter/material.dart';

class SlotDurationSelector extends StatelessWidget {
  final int selectedDuration;
  final Function(int) onDurationSelected;
  final List<int> availableDurations;
  final int totalDurationMinutes;

  // Standard durations that will always be available
  static const List<int> standardDurations = [15, 30, 45, 60, 90, 120, 180];

  const SlotDurationSelector({
    Key? key,
    required this.selectedDuration,
    required this.onDurationSelected,
    this.availableDurations = const [], // Empty default, will use standard durations
    this.totalDurationMinutes = 120, // Default 2 hours (120 minutes)
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use provided durations or fall back to standard durations
    final List<int> durations = availableDurations.isNotEmpty 
        ? availableDurations 
        : standardDurations;
    
    // Ensure selectedDuration is valid or use first available
    final int effectiveSelectedDuration = durations.contains(selectedDuration)
        ? selectedDuration
        : durations.first;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Duration (minutes)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              border: InputBorder.none,
              hintText: 'Select duration',
            ),
            value: effectiveSelectedDuration,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down),
            items: durations.map<DropdownMenuItem<int>>((int duration) {
              return DropdownMenuItem<int>(
                value: duration,
                child: Text('$duration minutes'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                onDurationSelected(newValue);
              }
            },
          ),
        ),
      ],
    );
  }
}
