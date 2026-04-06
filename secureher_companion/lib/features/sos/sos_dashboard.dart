import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:secureher_companion/services/notification_service.dart';
import 'package:secureher_companion/features/checkin/check_in_screen.dart';

class SosDashboard extends StatefulWidget {
  const SosDashboard({super.key});

  @override
  State<SosDashboard> createState() => _SosDashboardState();
}

class _SosDashboardState extends State<SosDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _sosAlerts = [];
  List<Map<String, dynamic>> _checkIns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupListeners();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load SOS and Trip alerts
      final alertsSnapshot = await _firestore
          .collection('alerts')
          .where('type', whereIn: ['sos', 'trip', 'missed_checkin'])
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final alerts = alertsSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'type': data['type'] ?? 'sos',
          'message': data['message'] ?? 'Alert',
          'timestamp': data['createdAt'] ?? Timestamp.now(),
          'location': data['currentLocation'] != null
              ? LatLng(data['currentLocation']['lat'], data['currentLocation']['lng'])
              : null,
          'active': data['active'] ?? false,
        };
      }).toList();

      // Load check-ins
      final checkInsSnapshot = await _firestore
          .collection('check_ins')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final checkIns = checkInsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'message': data['message'] ?? 'Check-in',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'nextCheckIn': data['nextCheckIn'],
        };
      }).toList();

      setState(() {
        _sosAlerts = alerts;
        _checkIns = checkIns;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupListeners() {
    // Listen for new alerts (SOS + Trips)
    _firestore
        .collection('alerts')
        .where('type', whereIn: ['sos', 'trip', 'missed_checkin'])
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data()!;

              // Show notification for new SOS alert
              NotificationService.showSosNotification(
                title: 'SOS Alert!',
                body: data['message'] ?? 'Someone needs your help!',
                payload: 'sos',
              );

              _loadData(); // Refresh data
            }
          }
        });

    // Listen for new check-ins
    _firestore.collection('check_ins').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _loadData(); // Refresh data
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureHer Companion'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildSosSection(),
                    const SizedBox(height: 24),
                    _buildCheckInSection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CheckInScreen()),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.add_alarm),
        label: const Text('Schedule Check-in'),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Companion Dashboard',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor SOS alerts and check-ins from your loved ones',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Alerts & Trips',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _sosAlerts.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No SOS alerts found')),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sosAlerts.length,
                itemBuilder: (context, index) {
                  final alert = _sosAlerts[index];
                  final isTrip = alert['type'] == 'trip';
                  final isSos = alert['type'] == 'sos';
                  final statusColor = isSos ? Colors.red : (isTrip ? Colors.blue : Colors.orange);
                  final label = isSos ? 'EMERGENCY SOS' : (isTrip ? 'ACTIVE TRIP' : 'ALERT');

                  final timestamp = alert['timestamp'] as Timestamp;
                  final date = timestamp.toDate();
                  final formattedDate = DateFormat(
                    'MMM d, yyyy - h:mm a',
                  ).format(date);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: alert['active']
                          ? BorderSide(
                              color: statusColor,
                              width: 2,
                            )
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Icon(
                            isSos ? Icons.warning_rounded : (isTrip ? Icons.directions_walk : Icons.info),
                            color: alert['active']
                                ? statusColor
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            alert['active'] ? 'ACTIVE $label' : label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: alert['active']
                                  ? statusColor
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(alert['message']),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (alert['location'] != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.map),
                              label: const Text('View Location'),
                              onPressed: () {
                                // TODO: Open map with location
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildCheckInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Check-ins',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _checkIns.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No check-ins found')),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _checkIns.length,
                itemBuilder: (context, index) {
                  final checkIn = _checkIns[index];
                  final timestamp = checkIn['timestamp'] as Timestamp;
                  final date = timestamp.toDate();
                  final formattedDate = DateFormat(
                    'MMM d, yyyy - h:mm a',
                  ).format(date);

                  Timestamp? nextCheckInTimestamp = checkIn['nextCheckIn'];
                  String nextCheckInText = 'No scheduled check-in';

                  if (nextCheckInTimestamp != null) {
                    final nextDate = nextCheckInTimestamp.toDate();
                    if (nextDate.isAfter(DateTime.now())) {
                      nextCheckInText =
                          'Next: ${DateFormat('h:mm a').format(nextDate)}';
                    } else {
                      nextCheckInText = 'Missed check-in';
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Check-in',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(checkIn['message'] ?? 'Check-in received'),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nextCheckInText,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: nextCheckInText == 'Missed check-in'
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}
