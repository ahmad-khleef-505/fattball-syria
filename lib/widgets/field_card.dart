import 'package:fattball/core/theme.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/widgets/sports_button.dart';
import 'package:fattball/widgets/field_rating_badge.dart';
import 'package:flutter/material.dart';

class FieldCard extends StatefulWidget {
  const FieldCard({
    super.key,
    required this.field,
    required this.onBook,
    required this.onClose,
  });

  final FieldModel field;
  final VoidCallback onBook;
  final VoidCallback onClose;

  @override
  State<FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<FieldCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final radius = BorderRadius.circular(8);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.015 : 1,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppTheme.neonGreen.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.16),
                blurRadius: _isHovered ? 22 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onBook,
              borderRadius: radius,
              splashColor: AppTheme.neonGreen.withValues(alpha: 0.12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 124,
                    child: _FieldImage(url: field.images.firstOrNull),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        10,
                        4,
                        10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            field.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          FieldRatingBadge(fieldId: field.fieldId),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${field.governorate} - ${field.district}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppTheme.sportsOrange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${field.pricePerHour.toStringAsFixed(0)}\$ / ساعة',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                              SportsButton(
                                onPressed: widget.onBook,
                                compact: true,
                                child: const Text('احجز'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'إغلاق',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldImage extends StatelessWidget {
  const _FieldImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF1B5E20),
        child: Center(
          child: Icon(
            Icons.sports_soccer,
            size: 42,
            color: AppTheme.neonGreen,
          ),
        ),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF1B5E20),
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppTheme.neonGreen,
          ),
        ),
      ),
    );
  }
}
