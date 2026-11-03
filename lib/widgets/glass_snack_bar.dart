import 'dart:ui';

import 'package:flutter/material.dart';

SnackBar glassSnackBar({
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    content: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.82),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.12),
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                        child: content,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: action.onPressed,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(action.label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
  );
}
