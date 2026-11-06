import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:flutter/material.dart';

class FieldReviewsSection extends StatefulWidget {
  const FieldReviewsSection({
    super.key,
    required this.fieldId,
    required this.customer,
  });

  final String fieldId;
  final UserModel customer;

  @override
  State<FieldReviewsSection> createState() => _FieldReviewsSectionState();
}

class _FieldReviewsSectionState extends State<FieldReviewsSection> {
  bool _isCheckingPermission = false;

  Future<void> _addReview() async {
    setState(() => _isCheckingPermission = true);
    try {
      // التحقق من أن العميل أكمل حجزاً في هذا الملعب
      final bookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: widget.customer.uid)
          .where('fieldId', isEqualTo: widget.fieldId)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();

      if (bookings.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            glassSnackBar(
              content: const Text('يمكنك تقييم الملعب فقط بعد إكمال حجزك فيه.'),
            ),
          );
        }
        return;
      }

      // إذا كان لديه حجز مكتمل، افتح نافذة إضافة التقييم
      if (mounted) _showAddReviewDialog();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: const Text('حدث خطأ أثناء التحقق من صلاحية التقييم.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  void _showAddReviewDialog() {
    double selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('أضف تقييمك'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = index + 1.0),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقك هنا (اختياري)...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context); // إغلاق النافذة
                await _submitReview(selectedRating, commentController.text.trim());
              },
              child: const Text('نشر التقييم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview(double rating, String comment) async {
    try {
      await FirebaseFirestore.instance.collection('reviews').add({
        'fieldId': widget.fieldId,
        'customerId': widget.customer.uid,
        'customerName': widget.customer.name,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: const Text('تم نشر تقييمك بنجاح. شكراً لك!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          glassSnackBar(content: const Text('تعذر نشر التقييم. حاول مجدداً.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('fieldId', isEqualTo: widget.fieldId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل التقييمات حالياً.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        final reviews = snapshot.data?.docs ?? [];
        
        // حساب متوسط التقييم
        double averageRating = 0;
        if (reviews.isNotEmpty) {
          double total = 0;
          for (var doc in reviews) {
            total += (doc.data() as Map<String, dynamic>)['rating'] ?? 0;
          }
          averageRating = total / reviews.length;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التقييمات (${reviews.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (reviews.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                    ],
                  )
              ],
            ),
            const SizedBox(height: 12),

            // زر إضافة تقييم
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCheckingPermission ? null : _addReview,
                icon: _isCheckingPermission 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.rate_review_outlined),
                label: const Text('أضف تقييمك للملعب'),
              ),
            ),
            const SizedBox(height: 16),

            // قائمة التقييمات
            if (reviews.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('لا توجد تقييمات بعد. كن أول من يقيم هذا الملعب!'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final review = reviews[index].data() as Map<String, dynamic>;
                  final rating = (review['rating'] as num?)?.toDouble() ?? 0;
                  final name = review['customerName'] as String? ?? 'مستخدم';
                  final comment = review['comment'] as String? ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: List.generate(5, (starIndex) {
                                return Icon(
                                  starIndex < rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(comment, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}