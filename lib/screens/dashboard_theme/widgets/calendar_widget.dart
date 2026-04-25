import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../utils/car_dashboard_theme.dart';

class CalendarWidget extends StatefulWidget {
  final bool isDarkMode;
  const CalendarWidget({super.key, required this.isDarkMode});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Events: Map<DateString, List<EventMap>>
  // EventMap: { "text": "...", "type": "note"|"reminder" }
  Map<String, List<Map<String, String>>> _events = {};

  final Map<String, String> _indianHolidays = {
    '01-26': 'Republic Day',
    '08-15': 'Independence Day',
    '10-02': 'Gandhi Jayanti',
    '12-25': 'Christmas',
    '01-14': 'Makar Sankranti',
    '03-14': 'Holi (Expected)', 
    '10-20': 'Diwali (Expected)',
    '05-01': 'Labor Day',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }
  
  Future<void> _loadEvents() async {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     final userId = provider.userProfile?.uid ?? 'guest';
     final prefs = await SharedPreferences.getInstance();
     final stored = prefs.getString('calendar_events_v2_$userId'); 
     if (stored != null) {
        try {
           final decoded = json.decode(stored) as Map<String, dynamic>;
           setState(() {
              _events = decoded.map((k, v) => MapEntry(k, List<Map<String, String>>.from(
                 (v as List).map((e) => Map<String, String>.from(e))
              )));
           });
        } catch (e) { /* Error ignored */ }
     }
  }

  Future<void> _saveEvents() async {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     final userId = provider.userProfile?.uid ?? 'guest';
     final prefs = await SharedPreferences.getInstance();
     await prefs.setString('calendar_events_v2_$userId', json.encode(_events));
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
     final dateKey = DateFormat('yyyy-MM-dd').format(day);
     final monthDayKey = DateFormat('MM-dd').format(day);
     
     List<Map<String, String>> dayEvents = _events[dateKey] ?? [];
     
     // Add Holiday as a virtual event
     if (_indianHolidays.containsKey(monthDayKey)) {
        return [...dayEvents, {"text": _indianHolidays[monthDayKey]!, "type": "holiday"}];
     }
     
     return dayEvents;
  }
  
  void _addEvent(String type) {
     if (_selectedDay == null) return;
     
     TextEditingController controller = TextEditingController();
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: Text("Add $type for ${DateFormat('MMM d').format(_selectedDay!)}"),
           content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: "Enter $type details..."),
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                 onPressed: () {
                    if (controller.text.isNotEmpty) {
                       setState(() {
                          final key = DateFormat('yyyy-MM-dd').format(_selectedDay!);
                          if (_events[key] == null) _events[key] = [];
                          _events[key]!.add({
                             "text": controller.text, 
                             "type": type.toLowerCase()
                          });
                          _saveEvents();
                       });
                    }
                    Navigator.pop(ctx);
                 },
                 child: const Text("Save"),
              )
           ],
        )
     );
  }

  void _deleteEvent(int index) {
     setState(() {
        final key = DateFormat('yyyy-MM-dd').format(_selectedDay!);
        if (_events[key] != null) {
           _events[key]!.removeAt(index);
           if (_events[key]!.isEmpty) _events.remove(key);
           _saveEvents();
        }
     });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = CarDashboardTheme.backgroundColor(isDark);
    final cardColor = CarDashboardTheme.cardColor(isDark);
    final textColor = CarDashboardTheme.textColor(isDark);

    return Scaffold(
       backgroundColor: bgColor,
       body: SafeArea(
         child: Column(
            children: [
               // HEADER
               Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text("Calendar & Notes", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                        // CLOSE BUTTON
                        InkWell(
                           onTap: () => Navigator.pop(context),
                           child: Container(
                              width: 36, 
                              height: 36,
                              decoration: BoxDecoration(
                                 color: Colors.redAccent,
                                 borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                           ),
                        )
                     ],
                  ),
               ),
               
               // MAIN CONTENT
               Expanded(
                 child: Row(
                   children: [
                      // Left Side: Calendar (Flex 2)
                      Expanded(
                         flex: 2,
                         child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                               color: cardColor,
                               borderRadius: BorderRadius.circular(24),
                               boxShadow: CarDashboardTheme.cardShadow(isDark),
                            ),
                            child: TableCalendar(
                               firstDay: DateTime.utc(2020, 1, 1),
                               lastDay: DateTime.utc(2030, 12, 31),
                               focusedDay: _focusedDay,
                               calendarFormat: _calendarFormat,
                               shouldFillViewport: true,
                               daysOfWeekHeight: 40,
                               rowHeight: 60,
                               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                               
                               // Load events (map to generic list for marker check)
                               eventLoader: (day) {
                                  return _getEventsForDay(day);
                               },
                               
                               onDaySelected: (selectedDay, focusedDay) {
                                  if (!isSameDay(_selectedDay, selectedDay)) {
                                     setState(() {
                                        _selectedDay = selectedDay;
                                        _focusedDay = focusedDay;
                                     });
                                  }
                               },
                               onFormatChanged: (format) {
                                  if (_calendarFormat != format) setState(() => _calendarFormat = format);
                               },
                               onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                               
                               headerStyle: const HeaderStyle(
                                  titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.indigo, size: 30),
                                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.indigo, size: 30),
                                  headerPadding: EdgeInsets.symmetric(vertical: 8),
                               ),
                               calendarStyle: CalendarStyle(
                                  defaultTextStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 20),
                                  weekendTextStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 20),
                                  outsideTextStyle: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 20),
                                  cellMargin: const EdgeInsets.all(4),
                                  cellPadding: const EdgeInsets.all(0),
                                  cellAlignment: Alignment.center,
                                  selectedDecoration: BoxDecoration(
                                     color: Colors.indigoAccent,
                                     shape: BoxShape.circle,
                                     boxShadow: [BoxShadow(color: Colors.indigoAccent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))]
                                  ),
                                  selectedTextStyle: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  todayDecoration: BoxDecoration(
                                     color: Colors.orangeAccent.withValues(alpha: 0.8),
                                     shape: BoxShape.circle,
                                  ),
                                  todayTextStyle: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  markerDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  markersMaxCount: 3,
                                  markerSize: 8,
                                  markersAlignment: Alignment.bottomCenter,
                               ),
                               daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                                  weekendStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                               ),
                            ),
                         ),
                      ),
                      
                      // Right Side: Notes & Details (Flex 1)
                      Expanded(
                         flex: 1,
                         child: Container(
                            margin: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                               color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                               borderRadius: BorderRadius.circular(24),
                               border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.2)),
                               boxShadow: CarDashboardTheme.cardShadow(isDark),
                            ),
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: [
                                  // Selected Date Header
                                  Text(
                                     _selectedDay != null ? DateFormat('EEEE').format(_selectedDay!) : "Select Day",
                                     style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                                  ),
                                  Text(
                                     _selectedDay != null ? DateFormat('MMMM d, y').format(_selectedDay!) : "",
                                     style: TextStyle(fontSize: 20, color: textColor.withValues(alpha: 0.7)),
                                  ),
                                  const Divider(height: 32),
                                  
                                  // Events List
                                  Expanded(
                                     child: _selectedDay == null ? Container() : 
                                     ListView(
                                        children: [
                                           if (_getEventsForDay(_selectedDay!).isEmpty)
                                              const Padding(
                                                 padding: EdgeInsets.only(top: 32),
                                                 child: Center(child: Text("No events or notes.", style: TextStyle(color: Colors.grey, fontSize: 18))),
                                              ),
                                              
                                           ..._getEventsForDay(_selectedDay!).asMap().entries.map((entry) {
                                              int idx = entry.key;
                                              Map<String, String> event = entry.value;
                                              bool isHoliday = event['type'] == 'holiday';
                                              bool isReminder = event['type'] == 'reminder';
                                              
                                              Color itemColor = isHoliday ? Colors.orange 
                                                              : isReminder ? Colors.purpleAccent 
                                                              : Colors.blue;
                                              
                                              IconData itemIcon = isHoliday ? Icons.star 
                                                                : isReminder ? Icons.alarm 
                                                                : Icons.note;

                                              return Container(
                                                 margin: const EdgeInsets.only(bottom: 12),
                                                 padding: const EdgeInsets.all(12),
                                                 decoration: BoxDecoration(
                                                    color: itemColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: itemColor.withValues(alpha: 0.5)),
                                                 ),
                                                 child: Row(
                                                    children: [
                                                       Icon(itemIcon, size: 24, color: itemColor),
                                                       const SizedBox(width: 12),
                                                       Expanded(child: Text(event['text']!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor))),
                                                       
                                                       // DELETE BUTTON (If not holiday)
                                                       if (!isHoliday)
                                                       IconButton(
                                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                          onPressed: () => _deleteEvent(idx),
                                                       )
                                                    ],
                                                 ),
                                              );
                                           })
                                        ],
                                     ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  // ACTION BUTTONS
                                  Row(
                                     children: [
                                        Expanded(
                                           child: ElevatedButton.icon(
                                              icon: const Icon(Icons.note_add, size: 20),
                                              label: const Text("Note", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                 backgroundColor: Colors.indigoAccent,
                                                 foregroundColor: Colors.white,
                                                 padding: const EdgeInsets.symmetric(vertical: 20),
                                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                 elevation: 2
                                              ),
                                              onPressed: () => _addEvent("Note"),
                                           ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                           child: ElevatedButton.icon(
                                              icon: const Icon(Icons.alarm_add, size: 20),
                                              label: const Text("Reminder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                 backgroundColor: Colors.purple, // Different color for reminder
                                                 foregroundColor: Colors.white,
                                                 padding: const EdgeInsets.symmetric(vertical: 20),
                                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                 elevation: 2
                                              ),
                                              onPressed: () => _addEvent("Reminder"),
                                           ),
                                        ),
                                     ],
                                  )
                               ],
                            ),
                         ),
                      )
                   ],
                 ),
               ),
            ],
         ),
       ),
    );
  }
}
