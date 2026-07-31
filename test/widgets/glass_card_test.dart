import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/theme/app_theme_style.dart';
import 'package:passguard_vault/utils/app_theme.dart';
import 'package:passguard_vault/widgets/glass_card.dart';

void main() {
  testWidgets('renders a rounded card with a coloured left accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(AppThemeStyle.vault, Brightness.dark),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              GlassCard(
                leftAccentColor: Colors.teal,
                padding: EdgeInsets.all(16),
                child: Text('Tagged entry'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Tagged entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
