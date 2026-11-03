import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SportsShimmer extends StatelessWidget {
  const SportsShimmer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF252D27) : const Color(0xFFE2E9E1),
      highlightColor:
          isDark ? const Color(0xFF3A463C) : const Color(0xFFF7FAF6),
      child: child,
    );
  }
}

class BookingListShimmer extends StatelessWidget {
  const BookingListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => SportsShimmer(
        child: Container(
          height: 142,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class FieldGridShimmer extends StatelessWidget {
  const FieldGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600
            ? 1
            : constraints.maxWidth > 1024
                ? (constraints.maxWidth >= 1400 ? 4 : 3)
                : 2;
        return GridView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 96),
          itemCount: columns * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 184,
          ),
          itemBuilder: (context, index) => SportsShimmer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SportsEmptyState extends StatelessWidget {
  const SportsEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.secondary.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.sports_soccer,
                  size: 64,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.sports_soccer),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
