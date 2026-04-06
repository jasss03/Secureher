import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secureher/features/women_essential/product_listing_screen.dart';
import '../../widgets/branding.dart';
import 'product_listing_screen.dart';

/// Women Essential Screen
/// This screen provides essential women's products and a menstrual cycle calculator
class WomenEssentialScreen extends StatefulWidget {
  const WomenEssentialScreen({super.key});

  @override
  State<WomenEssentialScreen> createState() => _WomenEssentialScreenState();
}

class _WomenEssentialScreenState extends State<WomenEssentialScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for UI elements
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Cycle calculator variables
  DateTime _lastPeriodDate = DateTime.now().subtract(const Duration(days: 28));
  int _cycleLength = 28;
  int _periodLength = 5;

  // Text editing controllers for form fields
  TextEditingController _lastPeriodController = TextEditingController();
  TextEditingController _cycleLengthController = TextEditingController();
  TextEditingController _periodLengthController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    // Initialize text controllers with default values
    _lastPeriodController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(_lastPeriodDate);
    _cycleLengthController.text = _cycleLength.toString();
    _periodLengthController.text = _periodLength.toString();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _lastPeriodController.dispose();
    _cycleLengthController.dispose();
    _periodLengthController.dispose();
    super.dispose();
  }

  /// Calculate the next period date based on inputs
  DateTime _calculateNextPeriod() {
    return _lastPeriodDate.add(Duration(days: _cycleLength));
  }

  /// Calculate the fertile window (typically 12-16 days before next period)
  List<DateTime> _calculateFertileWindow() {
    final nextPeriod = _calculateNextPeriod();
    final fertileStart = nextPeriod.subtract(Duration(days: 16));
    final fertileEnd = nextPeriod.subtract(Duration(days: 12));
    return [fertileStart, fertileEnd];
  }

  /// Calculate days until next period
  int _daysUntilNextPeriod() {
    final now = DateTime.now();
    final next = _calculateNextPeriod();
    return next.difference(now).inDays;
  }

  /// Calculate current cycle day
  int _getCurrentCycleDay() {
    final now = DateTime.now();
    return now.difference(_lastPeriodDate).inDays % _cycleLength + 1;
  }

  /// Show date picker for last period date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastPeriodDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE91E63), // Pink primary color
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _lastPeriodDate) {
      setState(() {
        _lastPeriodDate = picked;
        _lastPeriodController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Build product category card
  Widget _buildProductCategoryCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle, // Using the parameter directly
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate cycle information
    final nextPeriod = _calculateNextPeriod();
    final fertileWindow = _calculateFertileWindow();
    final daysUntil = _daysUntilNextPeriod();
    final currentCycleDay = _getCurrentCycleDay();

    // Format dates for display
    final nextPeriodFormatted = DateFormat('MMM d, yyyy').format(nextPeriod);
    final fertileStartFormatted = DateFormat('MMM d').format(fertileWindow[0]);
    final fertileEndFormatted = DateFormat('MMM d').format(fertileWindow[1]);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Women\'s Essentials',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFFCE4EC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFCE4EC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Essential Products & Tools',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Everything you need for your well-being',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

            // Menstrual Cycle Tracker Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xFFE91E63),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Menstrual Cycle Tracker',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message:
                                'Track your cycle to predict your next period and fertile window',
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),

                      // Cycle Progress Indicator
                      _buildCycleProgressIndicator(currentCycleDay),
                      const SizedBox(height: 16),

                      // Cycle Day Information
                      Center(
                        child: Text(
                          'Day $currentCycleDay of $_cycleLength day cycle',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Prediction Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildCyclePredictionCard(
                              'Next Period',
                              nextPeriodFormatted,
                              'In $daysUntil days',
                              Icons.calendar_today,
                              const Color(0xFFE91E63),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCyclePredictionCard(
                              'Fertile Window',
                              '$fertileStartFormatted - $fertileEndFormatted',
                              'Plan accordingly',
                              Icons.favorite,
                              const Color(0xFF9C27B0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Cycle Calculator
                      _buildCycleCalculator(),
                    ],
                  ),
                ),
              ),
            ),

            // Essential Products Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Essential Products',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Product Categories Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductListingScreen(
                                category: 'Menstrual Products',
                                color: Color(0xFFE91E63),
                                icon: Icons.spa,
                              ),
                            ),
                          );
                        },
                        child: _buildProductCategoryCard(
                          'Menstrual Products',
                          'Pads, tampons, cups',
                          Icons.spa,
                          const Color(0xFFE91E63),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductListingScreen(
                                category: 'Hygiene Products',
                                color: Color(0xFF9C27B0),
                                icon: Icons.opacity,
                              ),
                            ),
                          );
                        },
                        child: _buildProductCategoryCard(
                          'Hygiene Products',
                          'Washes, wipes, sprays',
                          Icons.opacity,
                          const Color(0xFF9C27B0),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductListingScreen(
                                category: 'Pain Relief',
                                color: Color(0xFF2196F3),
                                icon: Icons.healing,
                              ),
                            ),
                          );
                        },
                        child: _buildProductCategoryCard(
                          'Pain Relief',
                          'Medication, heat pads',
                          Icons.healing,
                          const Color(0xFF2196F3),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductListingScreen(
                                category: 'Wellness',
                                color: Color(0xFF4CAF50),
                                icon: Icons.favorite,
                              ),
                            ),
                          );
                        },
                        child: _buildProductCategoryCard(
                          'Wellness',
                          'Vitamins, supplements',
                          Icons.favorite,
                          const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Safety Tools Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Safety Tools',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Safety Tools List
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSafetyToolItem(
                            'Personal Alarms',
                            'Compact devices that emit loud sounds to deter attackers',
                            Icons.volume_up,
                          ),
                          const Divider(),
                          _buildSafetyToolItem(
                            'Pepper Sprays',
                            'Legal self-defense sprays that temporarily disable attackers',
                            Icons.invert_colors,
                          ),
                          const Divider(),
                          _buildSafetyToolItem(
                            'Safety Apps',
                            'Mobile applications for emergency contacts and location sharing',
                            Icons.phone_android,
                          ),
                          const Divider(),
                          _buildSafetyToolItem(
                            'Self-Defense Keychains',
                            'Discreet tools that can be used for protection',
                            Icons.vpn_key,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Branding
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'SecureHer - Women Safety App',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // SOS functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS feature activated'),
              backgroundColor: Colors.red,
            ),
          );
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.sos),
      ),
    );
  }

  /// Build cycle calculator widget
  Widget _buildCycleCalculator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Your Cycle Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE91E63),
          ),
        ),
        const SizedBox(height: 16),

        // Last Period Date Input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lastPeriodController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Last Period Start Date',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFFE91E63),
                  ),
                  helperText: 'Tap to select date',
                ),
                onTap: () => _selectDate(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cycle Length and Period Length Inputs
        Row(
          children: [
            // Cycle Length Input
            Expanded(
              child: TextFormField(
                controller: _cycleLengthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cycle Length (days)',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Usually 21-35 days',
                  suffixIcon: Tooltip(
                    message:
                        'The number of days from the first day of your period to the day before your next period',
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _cycleLength = int.parse(value);
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),

            // Period Length Input
            Expanded(
              child: TextFormField(
                controller: _periodLengthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Period Length (days)',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Usually 3-7 days',
                  suffixIcon: Tooltip(
                    message: 'The number of days your period typically lasts',
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _periodLength = int.parse(value);
                    });
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Calculate Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Recalculate and refresh UI
              setState(() {});

              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cycle information updated'),
                  backgroundColor: Color(0xFFE91E63),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Update Cycle Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Build cycle progress indicator
  Widget _buildCycleProgressIndicator(int currentCycleDay) {
    // Calculate progress percentage
    final int cycleLength = 28; // Fixed value
    final int periodLength = 5; // Fixed value
    final progress = currentCycleDay / cycleLength;

    return Column(
      children: [
        const SizedBox(height: 8),

        // Progress Text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Day 1',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Day $cycleLength',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Progress Bar
        Stack(
          children: [
            // Background Track
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            // Progress Indicator
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            // Current Day Marker
            Positioned(
              left: (progress * MediaQuery.of(context).size.width - 64) - 8,
              top: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE91E63), width: 3),
                ),
              ),
            ),

            // Period Phase Indicator (if in period)
            if (currentCycleDay <= periodLength)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: periodLength / cycleLength,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Fertile Window Indicator
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (cycleLength - 12) / cycleLength,
                child: FractionallySizedBox(
                  alignment: Alignment.centerRight,
                  widthFactor: 5 / (cycleLength - 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Period', const Color(0xFFE91E63)),
            const SizedBox(width: 16),
            _buildLegendItem('Fertile Window', const Color(0xFF9C27B0)),
            const SizedBox(width: 16),
            _buildLegendItem(
              'Current Day',
              Colors.white,
              borderColor: const Color(0xFFE91E63),
            ),
          ],
        ),
      ],
    );
  }

  /// Build legend item for cycle progress indicator
  Widget _buildLegendItem(String label, Color color, {Color? borderColor}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null
                ? Border.all(color: borderColor, width: 2)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  /// Build prediction card for cycle information
  Widget _buildCyclePredictionCard(
    String title,
    String date,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// Build safety tool item
  Widget _buildSafetyToolItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFE91E63), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description, // Using the parameter directly
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
