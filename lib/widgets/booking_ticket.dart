import 'package:flutter/material.dart';

class BookingTicket extends StatelessWidget {
  const BookingTicket({
    super.key,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.startAt,
    required this.endAt,
    required this.totalPrice,
    required this.currencyCode,
    this.depositInfo,
    this.discountInfo,
    this.trainingInfo,
  });

  final Widget title;
  final String status;
  final Color statusColor;
  final String startAt;
  final String endAt;
  final String totalPrice;
  final String currencyCode;
  final String? depositInfo;
  final String? discountInfo;
  final String? trainingInfo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipPath(
      clipper: const StadiumTicketClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            right: BorderSide(color: colors.primary, width: 6),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stadium_outlined, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: title),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (discountInfo != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 17,
                      color: colors.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        discountInfo!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (depositInfo != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: colors.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        depositInfo!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (trainingInfo != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sports,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trainingInfo!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const _Perforation(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _TicketDetail(
                    icon: Icons.login,
                    label: 'من: $startAt',
                  ),
                  _TicketDetail(
                    icon: Icons.logout,
                    label: 'إلى: $endAt',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'الإجمالي: $totalPrice $currencyCode',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StadiumTicketClipper extends CustomClipper<Path> {
  const StadiumTicketClipper({this.radius = 10, this.notchRadius = 9});

  final double radius;
  final double notchRadius;

  @override
  Path getClip(Size size) {
    final midY = size.height / 2;
    return Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, midY - notchRadius)
      ..quadraticBezierTo(
        size.width - notchRadius,
        midY,
        size.width,
        midY + notchRadius,
      )
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, midY + notchRadius)
      ..quadraticBezierTo(notchRadius, midY, 0, midY - notchRadius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant StadiumTicketClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.notchRadius != notchRadius;
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => Container(
              width: 4,
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        );
      },
    );
  }
}

class _TicketDetail extends StatelessWidget {
  const _TicketDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}
