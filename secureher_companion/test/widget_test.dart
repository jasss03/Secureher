import 'package:flutter_test/flutter_test.dart';
import 'package:secureher_companion/main.dart';

void main() {
  testWidgets('Auth gate renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CompanionApp());
    expect(find.text('SecureHer Companion'), findsWidgets);
  });
}
