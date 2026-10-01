import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymind/presentation/widgets/common.dart';

void main() {
  testWidgets('StatTile shows label and value', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatTile(label: 'Savings', value: '₹50,000'))));
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('₹50,000'), findsOneWidget);
  });

  testWidgets('EmptyState button fires its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyState(icon: Icons.inbox, title: 'Nothing here', actionLabel: 'Add', onAction: () => tapped = true)),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Add'));
    expect(tapped, true);
  });

  testWidgets('StatusChip renders its label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusChip('Paid', Colors.green))));
    expect(find.text('Paid'), findsOneWidget);
  });
}
