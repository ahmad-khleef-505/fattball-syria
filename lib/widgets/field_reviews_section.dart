import 'package:fattball/models/field_review_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/review_service.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FieldReviewsSection extends ConsumerStatefulWidget {
  const FieldReviewsSection({
    super.key,
    required this.fieldId,
    required this.customer,
  });

  final String fieldId;
  final UserModel customer;

  @override
  ConsumerState<FieldReviewsSection> createState() =>
      _FieldReviewsSectionState();
}

class _FieldReviewsSectionState extends ConsumerState<FieldReviewsSection> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(String bookingId) async {
    if (_rating == 0) {
      _showMessage('اختر عدد النجوم قبل إرسال تقييمك.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(reviewServiceProvider).submitReview(
            fieldId: widget.fieldId,
            customer: widget.customer,
            bookingId: bookingId,
            rating: _rating,
            comment: _commentController.text,
          );
      if (!mounted) return;
      _commentController.clear();
      setState(() => _rating = 0);
      _showMessage('شكراً لك، تم نشر تقييمك.');
    } on ReviewServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(glassSnackBar(content: Text(message)));
  }

  double _average(List<FieldReviewModel> reviews) {
    if (reviews.isEmpty) return 0;
    return reviews.fold<int>(0, (sum, review) => sum + review.rating) /
        reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(fieldReviewsProvider(widget.fieldId));
    final bookingsAsync = ref.watch(
      reviewEligibleBookingsProvider((
        fieldId: widget.fieldId,
        customerId: widget.customer.uid,
      ),),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reviewsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Text('تعذر تحميل التقييمات حالياً.'),
          data: (reviews) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'تقييمات اللاعبين',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFF9800),
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reviews.isEmpty
                        ? 'جديد'
                        : '${_average(reviews).toStringAsFixed(1)} '
                            '(${reviews.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (reviews.isEmpty)
                const Text('لا توجد تقييمات بعد. كن أول من يشارك تجربته.')
              else
                ...reviews.map(_reviewTile),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.customer.role == 'customer')
          bookingsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) =>
                const Text('تعذر التحقق من الحجوزات المكتملة للتقييم.'),
            data: (bookings) {
              if (bookings.isEmpty) {
                return const Text('يمكنك تقييم الملعب بعد إكمال حجزك فيه.');
              }
              return reviewsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (reviews) {
                  if (reviews.any(
                    (review) => review.customerId == widget.customer.uid,
                  )) {
                    return const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.verified_outlined),
                      title: Text('شكراً لك، لقد قيّمت هذا الملعب مسبقاً.'),
                    );
                  }
                  return _reviewForm(bookings.first.bookingId);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _reviewTile(FieldReviewModel review) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.sports_soccer_outlined),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'لاعب موثّق',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...List.generate(
              5,
              (index) => Icon(
                index < review.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 16,
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(review.comment),
            ],
            const SizedBox(height: 5),
            Text(
              DateFormat('yyyy/MM/dd').format(review.createdAt.toLocal()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewForm(String bookingId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'كيف كانت تجربتك؟',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => IconButton(
                  tooltip: 'تقييم ${index + 1} من 5',
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFF9800),
                    size: 32,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _commentController,
              maxLength: 500,
              maxLines: 3,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'تعليقك (اختياري)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : () => _submitReview(bookingId),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('إرسال التقييم'),
            ),
          ],
        ),
      ),
    );
  }
}
