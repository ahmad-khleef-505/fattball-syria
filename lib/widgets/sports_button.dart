import 'package:fattball/core/theme.dart';
import 'package:flutter/material.dart';

class SportsButton extends StatelessWidget {
  const SportsButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = enabled
        ? const [AppTheme.pitchGreen, Color(0xFF2E7D32)]
        : [Colors.grey.shade600, Colors.grey.shade500];
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppTheme.neonGreen.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 44 : 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 20,
                  vertical: compact ? 8 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                        child: IconTheme(
                          data: const IconThemeData(color: Colors.white),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
