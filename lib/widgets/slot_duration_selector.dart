import 'package:flutter/material.dart';

class SlotDurationSelector extends StatelessWidget {
  final int selectedDuration;
  final Function(int) onDurationSelected;
  final List<int> availableDurations;
  final int totalDurationMinutes;

  const SlotDurationSelector({
    Key? key,
    required this.selectedDuration,
    required this.onDurationSelected,
    this.availableDurations = const [], // Empty default, will calculate based on total duration
    this.totalDurationMinutes = 120, // Default 2 hours (120 minutes)
  }) : super(key: key);

  List<int> _getRecommendedDurations() {
    if (availableDurations.isNotEmpty) {
      return availableDurations;
    }
    
    // Calculate appropriate durations based on total time
    // We'll aim for between 4-12 slots as a reasonable number
    final List<int> durations = [];
    
    // Try standard durations: 5, 10, 15, 20, 30, 60 minutes
    final standardDurations = [5, 10, 15, 20, 30, 60, 120];
    
    for (final duration in standardDurations) {
      final slotCount = totalDurationMinutes ~/ duration;
      if (slotCount >= 2 && slotCount <= 12) {
        durations.add(duration);
      }
    }
    
    // If no standard durations work well, calculate a custom one
    if (durations.isEmpty) {
      // Aim for about 6 slots
      final idealDuration = totalDurationMinutes ~/ 6;
      // Round to nearest 5 minutes
      final roundedDuration = (idealDuration / 5).round() * 5;
      durations.add(roundedDuration > 0 ? roundedDuration : 5);
    }
    
    return durations;
  }

  @override
  Widget build(BuildContext context) {
    final durations = _getRecommendedDurations();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Select Time Slot Duration',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: durations.length,
            itemBuilder: (context, index) {
              final duration = durations[index];
              final isSelected = selectedDuration == duration;
              
              // Calculate width based on the number of digits in the duration
              final textWidth = '$duration min'.length * 8.0; // Approximate width per character
              final containerWidth = textWidth + 24.0; // Add padding
              
              return GestureDetector(
                onTap: () {
                  onDurationSelected(duration);
                },
                child: Container(
                  width: containerWidth,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$duration min',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
