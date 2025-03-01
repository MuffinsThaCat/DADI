import 'package:flutter/material.dart';

class SlotDurationSelector extends StatelessWidget {
  final int selectedDuration;
  final Function(int) onDurationSelected;
  final List<int> availableDurations;

  const SlotDurationSelector({
    Key? key,
    required this.selectedDuration,
    required this.onDurationSelected,
    this.availableDurations = const [2, 3, 4, 5],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            itemCount: availableDurations.length,
            itemBuilder: (context, index) {
              final duration = availableDurations[index];
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
                    color: isSelected 
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$duration min',
                      style: TextStyle(
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
