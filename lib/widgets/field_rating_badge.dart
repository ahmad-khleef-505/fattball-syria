import 'package:fattball/services/review_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FieldRatingBadge extends ConsumerWidget {
  const FieldRatingBadge({super.key, required this.fieldId});

  final String fieldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(fieldReviewsProvider(fieldId));
    return reviews.when(
      loading: () => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return Text('جديد', style: Theme.of(context).textTheme.labelSmall);
        }
        final average =
            items.fold<int>(0, (total, review) => total + review.rating) /
                items.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFF9800), size: 17),
            const SizedBox(width: 2),
            Text(
              '${average.toStringAsFixed(1)} (${items.length})',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        );
      },
    );
  }
}
