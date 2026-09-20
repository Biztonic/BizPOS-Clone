import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/widgets/chart_legend_indicator.dart';
import 'package:biztonic_pos/widgets/report_stat_card.dart';

void main() {
  group('Presentation Widget Tests', () {
    testWidgets('ChartLegendIndicator renders circular dot and text label',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChartLegendIndicator(
              color: Colors.blue,
              text: 'Dine In Sales',
              isSquare: false,
            ),
          ),
        ),
      );

      expect(find.text('Dine In Sales'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, Colors.blue);
    });

    testWidgets('ChartLegendIndicator renders square dot when isSquare is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChartLegendIndicator(
              color: Colors.green,
              text: 'Takeaway',
              isSquare: true,
            ),
          ),
        ),
      );

      expect(find.text('Takeaway'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      expect(decoration.color, Colors.green);
    });

    testWidgets(
        'ReportStatCard renders title, value, icon, and optional subtitle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ReportStatCard(
                  title: 'Total Revenue',
                  value: '₹1,24,500',
                  icon: Icons.currency_rupee,
                  baseColor: Colors.indigo,
                  subtitle: '+12% from yesterday',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('₹1,24,500'), findsOneWidget);
      expect(find.text('+12% from yesterday'), findsOneWidget);
      expect(find.byIcon(Icons.currency_rupee), findsOneWidget);
    });
  });
}
