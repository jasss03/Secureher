import 'package:flutter/material.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Tips & Guides')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TipCard(
            title: 'Stay aware of your surroundings',
            body: 'Trust your instincts. If something feels off, leave.',
          ),
          _TipCard(
            title: 'Emergency numbers',
            body: 'Know local emergency numbers and quick dial shortcuts.',
          ),
          _TipCard(
            title: 'Share your route',
            body: 'Use Route Guard to share live trip status.',
          ),
          _TipCard(
            title: 'Keep your phone charged',
            body:
                'Always carry a power bank or keep your phone battery above 50% when heading out.',
          ),
          _TipCard(
            title: 'Avoid poorly lit areas',
            body:
                'Stick to well-lit, busy streets whenever possible, especially at night.',
          ),
          _TipCard(
            title: 'Learn self-defense basics',
            body:
                'Basic self-defense skills can boost confidence and safety in emergencies.',
          ),
          _TipCard(
            title: 'Trustworthy transportation',
            body:
                'Verify ride-sharing driver details before entering the vehicle and share ride info with someone you trust.',
          ),
          _TipCard(
            title: 'Keep important items handy',
            body:
                'Carry essentials like pepper spray, a whistle, or a small flashlight for emergencies.',
          ),
          _TipCard(
            title: 'Stay alert in public spaces',
            body:
                'Avoid being distracted by headphones or phones when walking alone.',
          ),
          _TipCard(
            title: 'Use safety apps',
            body:
                'Download apps with SOS or location-sharing features for quick help when needed.',
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String body;
  const _TipCard({required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
