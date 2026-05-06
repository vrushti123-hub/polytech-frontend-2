import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PolytechApp());

    expect(find.text('Swami Polytech'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
