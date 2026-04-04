import 'package:flutter_test/flutter_test.dart';

import 'package:passguard_vault/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PassGuardVaultApp());
    await tester.pumpAndSettle();
  });
}
