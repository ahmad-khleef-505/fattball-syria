import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/core/theme.dart';
import 'package:fattball/models/booking_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/owner_analytics_calculator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class OwnerAnalyticsPanel extends StatelessWidget {
  const OwnerAnalyticsPanel({
    super.key,
    required this.owner,
    required this.fields,
    required this.hasInvalidFieldData,
  });

  final UserModel owner;
  final List<FieldModel> fields;
  final bool hasInvalidFieldData;

  @override
  Widget build(BuildContext context) {
    final bookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: owner.uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AnalyticsMessage(
            message: _errorMessage(snapshot.error),
            icon: Icons.error_outline,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AnalyticsMessage(
            message: 'جاري تحميل ملخص الأداء...',
            loading: true,
          );
        }

        try {
          final bookings = (snapshot.data?.docs ?? [])
              .map(
                (document) => BookingModel.fromMap(
                  document.id,
                  document.data(),
                ),
              )
              .toList();
          final analytics = OwnerAnalyticsCalculator.calculate(
            bookings: bookings,
            fields: fields,
            owner: owner,
            now: DateTime.now(),
          );
          return _AnalyticsContent(
            analytics: analytics,
            hasInvalidFieldData: hasInvalidFieldData,
          );
        } on FormatException {
          return const _AnalyticsMessage(
            message: 'تعذر احتساب الإحصائيات بسبب بيانات غير صالحة.',
            icon: Icons.warning_amber_rounded,
          );
        } on TypeError {
          return const _AnalyticsMessage(
            message: 'تعذر قراءة بيانات أحد الحجوزات أو الملاعب.',
            icon: Icons.warning_amber_rounded,
          );
        } on ArgumentError {
          return const _AnalyticsMessage(
            message: 'توجد حالة حجز غير معروفة، تعذر احتساب الإحصائيات.',
            icon: Icons.warning_amber_rounded,
          );
        }
      },
    );
  }

  String _errorMessage(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'ليست لديك صلاحية عرض تحليلات الحجوزات.',
        'unavailable' => 'الخدمة غير متاحة حالياً. تحقق من اتصالك.',
        'failed-precondition' =>
          'تعذر تحميل التحليلات؛ تحقق من فهارس Firestore.',
        _ => 'تعذر تحميل الإحصائيات. يرجى المحاولة مجدداً.',
      };
    }
    return 'تعذر تحميل الإحصائيات. يرجى المحاولة مجدداً.';
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({
    required this.analytics,
    required this.hasInvalidFieldData,
  });

  final OwnerAnalyticsData analytics;
  final bool hasInvalidFieldData;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ملخص الأداء',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  'هذا الشهر',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            if (hasInvalidFieldData) ...[
              const SizedBox(height: 10),
              const _AnalyticsWarning(
                message:
                    'بعض بيانات الملاعب غير صالحة؛ قد لا تشمل نسبة الإشغال '
                    'كل الملاعب.',
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 3
                    : constraints.maxWidth >= 340
                        ? 2
                        : 1;
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _AnalyticsMetric(
                        label: 'الأرباح المكتملة',
                        value:
                            '${analytics.monthlyRevenue.toStringAsFixed(2)} \$',
                        icon: Icons.payments_outlined,
                        color: AppTheme.sportsOrange,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _AnalyticsMetric(
                        label: 'حجوزات مكتملة',
                        value: '${analytics.completedBookings}',
                        icon: Icons.task_alt_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _AnalyticsMetric(
                        label: 'إشغال الساعات',
                        value: '${(analytics.occupancyRate * 100).round()}%',
                        detail: analytics.availableHours == 0
                            ? 'لا توجد ساعات متاحة'
                            : '${analytics.bookedHours.toStringAsFixed(1)}'
                                ' / ${analytics.availableHours.toStringAsFixed(1)} ساعة',
                        icon: Icons.pie_chart_outline,
                        color: AppTheme.neonGreen,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'أرباح أيام الأسبوع',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: _WeeklyEarningsChart(values: analytics.weeklyEarnings),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyEarningsChart extends StatelessWidget {
  const _WeeklyEarningsChart({required this.values});

  final List<double> values;

  static const _days = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    final maxY = maxValue <= 0 ? 10.0 : maxValue * 1.2;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        );

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(2)} \$',
                TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 0.6,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  value == 0 ? '0' : value.toStringAsFixed(0),
                  style: labelStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _days.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(_days[index], style: labelStyle),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          7,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                color: color,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: color.withValues(alpha: 0.07),
                ),
              ),
            ],
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _AnalyticsWarning extends StatelessWidget {
  const _AnalyticsWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AnalyticsMessage extends StatelessWidget {
  const _AnalyticsMessage({
    required this.message,
    this.icon,
    this.loading = false,
  });

  final String message;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon ?? Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
