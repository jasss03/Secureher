import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/checkin_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _svc = CheckInService();
  Timer? _tick;
  int? _remaining;
  final _minutesCtrl = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    _refresh();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final rem = await _svc.getRemainingSeconds();
    setState(() => _remaining = rem);
  }

  Future<void> _start() async {
    final m = int.tryParse(_minutesCtrl.text.trim()) ?? 30;
    await _svc.startCheckIn(Duration(minutes: m));
    await _refresh();
  }

  Future<void> _cancel() async {
    await _svc.cancel();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    String status;
    if (_remaining == null) {
      status = 'No active check-in.';
    } else if (_remaining == 0) {
      status = 'Missed check-in. Alerts sent.';
    } else {
      final mm = (_remaining! ~/ 60).toString().padLeft(2, '0');
      final ss = (_remaining! % 60).toString().padLeft(2, '0');
      status = 'Remaining: $mm:$ss';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In Timer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _start, child: const Text('Start')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'If you don\'t check in by the deadline, your trusted contacts will be alerted automatically.',
            ),
          ],
        ),
      ),
    );
  }
}
