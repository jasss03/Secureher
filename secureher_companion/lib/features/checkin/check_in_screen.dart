import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secureher_companion/services/check_in_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final TextEditingController _messageController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _scheduleCheckIn() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await CheckInService.scheduleCheckIn(
        checkInTime: _selectedDateTime,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in scheduled successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule check-in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Check-in'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Schedule a Check-in',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Set a time for your next check-in. You\'ll receive a notification, and if you don\'t respond, your trusted contacts will be alerted.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ListTile(
                    title: const Text('Check-in Time'),
                    subtitle: Text(
                      DateFormat(
                        'MMM d, yyyy - h:mm a',
                      ).format(_selectedDateTime),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    onTap: _selectDateTime,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Check-in Message',
                      hintText: 'E.g., "Going for a run, will be back by 8 PM"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _scheduleCheckIn,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Schedule Check-in'),
                  ),
                ],
              ),
            ),
    );
  }
}
