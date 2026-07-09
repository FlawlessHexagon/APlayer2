import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplayer2/main.dart'; // Adjust import to your actual project name if different, usually aplayer2 but wait: wait I don't know the package name
import 'package:aplayer2/theme/app_theme.dart';

void main() {
  testWidgets('Theme and Routing Test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: APlayerApp()));
    await tester.pumpAndSettle();

    // 1. Verify Home Screen is present
    expect(find.text('Library (Home)'), findsOneWidget);
    expect(find.text('Go to Now Playing'), findsOneWidget);

    // 2. Verify Theme Colors on Home Screen
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);
    expect(theme.scaffoldBackgroundColor, equals(AppColors.deepPurple));

    // 3. Verify Routing
    await tester.tap(find.text('Go to Now Playing'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing Dummy'), findsOneWidget);
    expect(find.text('Library (Home)'), findsNothing);
    
    // Verify font is applied
    expect(theme.textTheme.bodyLarge?.fontFamily, contains('JetBrainsMono'));
  });
}
