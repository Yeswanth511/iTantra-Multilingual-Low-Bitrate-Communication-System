import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/main.dart';

void main() {
  testWidgets('iTantra app Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const ITantraApp());
    expect(find.text('iTantra Neural Transceiver'), findsOneWidget);
  });
}
