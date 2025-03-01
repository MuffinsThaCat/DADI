import 'package:flutter/material.dart';
import '../models/device_control_slot.dart';

class TimeSlotSelector extends StatefulWidget {
  final List<DeviceControlSlot> slots;
  final Function(DeviceControlSlot)? onSlotSelected;
  final DeviceControlSlot? selectedSlot;

  const TimeSlotSelector({
    Key? key,
    required this.slots,
    this.onSlotSelected,
    this.selectedSlot,
  }) : super(key: key);

  @override
  _TimeSlotSelectorState createState() => _TimeSlotSelectorState();
}

class _TimeSlotSelectorState extends State<TimeSlotSelector> {
  DeviceControlSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.selectedSlot;
  }

  @override
  void didUpdateWidget(TimeSlotSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSlot != oldWidget.selectedSlot) {
      _selectedSlot = widget.selectedSlot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Select Time Slot',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.slots.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No available time slots for this auction'),
          )
        else
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.slots.length,
              itemBuilder: (context, index) {
                final slot = widget.slots[index];
                final isSelected = _selectedSlot == slot;
                final isAvailable = slot.isAvailable;
                
                return GestureDetector(
                  onTap: isAvailable ? () {
                    setState(() {
                      _selectedSlot = slot;
                    });
                    widget.onSlotSelected?.call(slot);
                  } : null,
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : isAvailable 
                              ? Colors.white 
                              : Colors.grey.shade200,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slot.displayTimeRange,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isAvailable ? Colors.black : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${slot.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.black54 : Colors.grey,
                          ),
                        ),
                        if (!isAvailable)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
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
