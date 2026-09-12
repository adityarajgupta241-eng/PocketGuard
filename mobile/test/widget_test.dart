import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pocketguard/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard renders today total', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PocketGuardApp(initialHost: ''));
    expect(find.text('PocketGuard'), findsOneWidget);
    expect(find.text('Total spent today'), findsOneWidget);
    expect(find.textContaining('₹'), findsWidgets);
  });
}
