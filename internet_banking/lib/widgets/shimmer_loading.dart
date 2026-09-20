import 'package:flutter/material.dart';

/// Reusable zero-dependency shimmer effect widget.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor = const Color(0xFFE5E9EB),
    this.highlightColor = const Color(0xFFF7F9FA),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Generic rounded placeholder box for skeletons.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.color = const Color(0xFFE5E9EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Complete Skeleton Loader for the Home Screen.
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Skeleton
            Row(
              children: [
                const SkeletonBox(width: 42, height: 42, borderRadius: 21),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 100, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      SkeletonBox(width: 60, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const SkeletonBox(width: 42, height: 42, borderRadius: 21),
                const SizedBox(width: 8),
                const SkeletonBox(width: 42, height: 42, borderRadius: 21),
              ],
            ),
            const SizedBox(height: 24),

            // Credit Card Skeleton
            const SkeletonBox(
              width: double.infinity,
              height: 205,
              borderRadius: 24,
            ),
            const SizedBox(height: 20),

            // Balance Row Skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 90, height: 12, borderRadius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: 160, height: 28, borderRadius: 6),
                  ],
                ),
                Row(
                  children: [
                    const SkeletonBox(width: 70, height: 36, borderRadius: 14),
                    const SizedBox(width: 8),
                    const SkeletonBox(width: 70, height: 36, borderRadius: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4 Action Buttons Skeleton
            Row(
              children: List.generate(4, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index < 3 ? 8.0 : 0.0),
                    child: const SkeletonBox(
                      height: 85,
                      borderRadius: 18,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // Recent Transactions Section Header Skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonBox(width: 120, height: 16, borderRadius: 4),
                const SkeletonBox(width: 70, height: 14, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 16),

            // Transaction List Skeletons
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const SkeletonBox(width: 44, height: 44, borderRadius: 22),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 130, height: 14, borderRadius: 4),
                          SizedBox(height: 6),
                          SkeletonBox(width: 80, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    const SkeletonBox(width: 75, height: 16, borderRadius: 4),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton Loader for Transaction History List.
class TransactionListSkeleton extends StatelessWidget {
  final int itemCount;

  const TransactionListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, borderRadius: 22),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 14, borderRadius: 4),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const SkeletonBox(width: 80, height: 16, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}
