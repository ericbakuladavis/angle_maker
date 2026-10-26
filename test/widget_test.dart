import 'package:flutter_test/flutter_test.dart';
import 'package:angle_maker/main.dart';

void main() {
  testWidgets('Angle Maker smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AngleDrawerApp());

    // Verify that title and initial angle display exist.
    expect(find.text('Angle Maker'), findsWidgets);
    expect(find.text('Angle: 45°'), findsOneWidget);
  });
}
