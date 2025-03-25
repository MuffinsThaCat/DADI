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
            child: Text('No time slots available for booking.'),
          )
        else
          Column(
            children: [
              // Debug info to verify slots
              Container(
                padding: const EdgeInsets.all(4.0),
                margin: const EdgeInsets.only(bottom: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.slots.length} available slots (5 min each)',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.slots.length,
                  itemBuilder: (context, index) {
                    final slot = widget.slots[index];
                    final isSelected = _selectedSlot == slot;
                    
                    // Verify no overlapping slots in UI
                    if (index > 0) {
                      final prevSlot = widget.slots[index-1];
                      if (prevSlot.endTime.isAfter(slot.startTime)) {
                        print('❌ UI RENDERING OVERLAP: Slot ${index-1} ends after slot $index starts');
                      }
                    }
                    
                    final startTimeStr = _formatTime(slot.startTime);
                    final endTimeStr = _formatTime(slot.endTime);
                    
                    return GestureDetector(
                      onTap: () {
                        if (slot.isAvailable) {
                          setState(() {
                            _selectedSlot = slot;
                          });
                          if (widget.onSlotSelected != null) {
                            widget.onSlotSelected!(slot);
                          }
                        }
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8.0),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : 
                                 slot.isAvailable ? Colors.white : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade400,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              startTimeStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'to',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              endTimeStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slot.isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? Colors.white : 
                                      slot.isAvailable ? Colors.green : Colors.red,
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
          ),
      ],
    );
  }
  
  // Helper to format time in a readable format
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
