import 'package:flutter/material.dart';

class ProductListingScreen extends StatelessWidget {
  final String category;
  final Color color;
  final IconData icon;

  const ProductListingScreen({
    Key? key,
    required this.category,
    required this.color,
    required this.icon,
  }) : super(key: key);

  // Get products based on category
  List<Map<String, dynamic>> _getProducts() {
    switch (category) {
      case 'Menstrual Products':
        return [
          {
            'name': 'Whisper Ultra Soft Pads (Pack of 20)',
            'price': '₹199',
            'description': 'Extra comfort with wings, 8-hour protection',
          },
          {
            'name': 'Tampax Pearl Tampons (Pack of 18)',
            'price': '₹349',
            'description': 'Regular absorbency, easy insertion',
          },
          {
            'name': 'Sirona Menstrual Cup',
            'price': '₹399',
            'description': 'Medical-grade silicone, reusable for years',
          },
          {
            'name': 'Nua Period Pads (Pack of 12)',
            'price': '₹249',
            'description': 'Ultra-thin, rash-free protection',
          },
          {
            'name': 'Carmesi Natural Sanitary Pads',
            'price': '₹299',
            'description': 'Made with bamboo fiber, biodegradable',
          },
        ];
      case 'Self-Defense Tools':
        return [
          {
            'name': 'Sabre Red Pepper Spray',
            'price': '₹799',
            'description': 'Police-strength formula, 10ft range',
          },
          {
            'name': 'Personal Safety Alarm Keychain',
            'price': '₹499',
            'description': '130dB alarm, pull-pin activation',
          },
          {
            'name': 'Tactical Pen with Glass Breaker',
            'price': '₹899',
            'description': 'Aircraft aluminum construction, writes smoothly',
          },
          {
            'name': 'Kubotan Self Defense Keychain',
            'price': '₹599',
            'description': 'Pressure point tool, legal to carry',
          },
        ];
      case 'Health Supplements':
        return [
          {
            'name': 'Ferrazone Iron Supplement',
            'price': '₹450',
            'description': '60 tablets, combats anemia and fatigue',
          },
          {
            'name': 'Calcium + Vitamin D3 Tablets',
            'price': '₹399',
            'description': '90 tablets, supports bone health',
          },
          {
            'name': 'Women\'s Multivitamin Complex',
            'price': '₹799',
            'description': '30-day supply, complete nutrition',
          },
          {
            'name': 'Evening Primrose Oil Capsules',
            'price': '₹649',
            'description': 'Helps with PMS symptoms, 60 softgels',
          },
          {
            'name': 'Folic Acid + B12 Supplement',
            'price': '₹349',
            'description': 'Essential for reproductive health',
          },
        ];
      case 'Safety Gadgets':
        return [
          {
            'name': 'Mini GPS Tracker',
            'price': '₹1,999',
            'description': 'Real-time location tracking, SOS button',
          },
          {
            'name': 'Smart Safety Wristband',
            'price': '₹2,499',
            'description': 'Sends location alerts, panic button',
          },
          {
            'name': 'Doorbell Camera',
            'price': '₹3,999',
            'description': 'Motion detection, two-way audio',
          },
          {
            'name': 'Personal Safety App Subscription',
            'price': '₹499/year',
            'description': 'Location sharing, emergency contacts',
          },
        ];
      case 'Emergency Contraception':
        return [
          {
            'name': 'i-pill Emergency Contraceptive',
            'price': '₹120',
            'description': 'Take within 72 hours, single dose',
          },
          {
            'name': 'Unwanted-72 Tablet',
            'price': '₹100',
            'description': 'Effective up to 3 days after unprotected sex',
          },
          {
            'name': 'Preventol Contraceptive Pills',
            'price': '₹150',
            'description': 'Levonorgestrel 1.5mg, single tablet',
          },
          {
            'name': 'Contraceptive Consultation',
            'price': '₹500',
            'description': 'Online doctor consultation for options',
          },
        ];
      case 'Hygiene Products':
        return [
          {
            'name': 'Intimate Wash',
            'price': '₹299',
            'description': 'pH balanced, gentle formula',
          },
          {
            'name': 'Antibacterial Hand Sanitizer',
            'price': '₹149',
            'description': '70% alcohol, travel size',
          },
          {
            'name': 'Biodegradable Intimate Wipes',
            'price': '₹199',
            'description': 'Pack of 25, fragrance-free',
          },
          {
            'name': 'Menstrual Hygiene Kit',
            'price': '₹599',
            'description': 'Complete kit with pads, wipes, and disposal bags',
          },
          {
            'name': 'Reusable Cotton Pads',
            'price': '₹449',
            'description': 'Eco-friendly, washable, pack of 6',
          },
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _getProducts();

    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: color,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.all(16),
            color: color.withOpacity(0.1),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${products.length} products available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Product list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product['description'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product['price'],
                              style: TextStyle(
                                color: color,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.shopping_cart, size: 18),
                              label: const Text('Add to Cart'),
                            ),
                          ],
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
    );
  }
}
