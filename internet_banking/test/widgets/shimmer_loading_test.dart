import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/widgets/shimmer_loading.dart';

void main() {
  group('ShimmerLoading and Skeleton Tests', () {
    testWidgets('ShimmerLoading renders child when not loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: false,
              child: Text('Content Loaded'),
            ),
          ),
        ),
      );

      expect(find.text('Content Loaded'), findsOneWidget);
    });

    testWidgets('ShimmerLoading renders child with shader mask when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: true,
              child: Text('Pulsing Content'),
            ),
          ),
        ),
      );

      expect(find.text('Pulsing Content'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Pulsing Content'), findsOneWidget);
    });

    testWidgets('SkeletonBox renders with correct dimensions and decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonBox(
              width: 120,
              height: 40,
              borderRadius: 12,
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('HomeScreenSkeleton renders multiple placeholder blocks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeScreenSkeleton(),
          ),
        ),
      );

      expect(find.byType(HomeScreenSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('TransactionListSkeleton renders requested item count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransactionListSkeleton(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(TransactionListSkeleton), findsOneWidget);
      // Each transaction row has 4 SkeletonBoxes (circle avatar, 2 text lines, 1 amount box)
      // 4 rows * 4 = 16 SkeletonBoxes
      expect(find.byType(SkeletonBox), findsNWidgets(16));
    });
  });
}
