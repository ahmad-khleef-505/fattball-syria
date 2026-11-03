import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';

class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;
  static const double maxContentWidth = 1200;

  static bool isMobile(double width) => width < mobile;
  static bool isDesktop(double width) => width > tablet;

  static int gridColumns(double width) {
    if (isMobile(width)) return 1;
    if (isDesktop(width)) return width >= 1400 ? 4 : 3;
    return 2;
  }
}

class ResponsiveDestination {
  const ResponsiveDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.actions,
    this.floatingActionButton,
    this.constrainBody = true,
  });

  final String title;
  final Widget body;
  final List<ResponsiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool constrainBody;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = AppBreakpoints.isMobile(width);
        final isDesktop = AppBreakpoints.isDesktop(width);
        final content = constrainBody
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxContentWidth,
                  ),
                  child: body,
                ),
              )
            : body;
        final animatedContent = content
            .animate()
            .fadeIn(duration: 320.ms)
            .slideY(
              begin: 0.025,
              end: 0,
              duration: 320.ms,
              curve: Curves.easeOutCubic,
            );

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: actions,
          ),
          body: isMobile
              ? animatedContent
              : Row(
                  children: [
                    NavigationRail(
                      extended: isDesktop,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      labelType:
                          isDesktop ? null : NavigationRailLabelType.all,
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(
                              destination.selectedIcon ?? destination.icon,
                            ),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: animatedContent),
                  ],
                ),
          bottomNavigationBar: isMobile
              ? BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: onDestinationSelected,
                  type: BottomNavigationBarType.fixed,
                  items: [
                    for (final destination in destinations)
                      BottomNavigationBarItem(
                        icon: Icon(destination.icon),
                        activeIcon: Icon(
                          destination.selectedIcon ?? destination.icon,
                        ),
                        label: destination.label,
                      ),
                  ],
                )
              : null,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
