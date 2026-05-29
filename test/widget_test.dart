import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:food_expiry_manager/main.dart';
import 'package:food_expiry_manager/providers/app_state.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const FoodExpiryApp(),
      ),
    );

    // Verify the app title appears
    expect(find.text('食品保质期助手'), findsOneWidget);
  });
}
