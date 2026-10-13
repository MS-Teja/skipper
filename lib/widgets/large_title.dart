import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// An iOS-style page: a large title at the top of the content that scrolls
/// away under a compact bar. The bar is invisible at rest and only gains a
/// background, hairline and small title once content scrolls beneath it
/// (solid, not frosted: a blur costs a whole frame on mid-range phones).
///
/// It listens to scroll notifications and rebuilds only when a threshold is
/// crossed, never per pixel.
class LargeTitleScrollView extends StatefulWidget {
  const LargeTitleScrollView({
    super.key,
    required this.title,
    required this.slivers,
    this.overline,
    this.trailing,
    this.leading,
    this.bottomPadding = 120,
  });

  final String title;

  /// Small caps line above the title, e.g. "WEDNESDAY 7 OCTOBER".
  final String? overline;

  /// Shown beside the large title, and in the bar once it collapses.
  final Widget? trailing;

  /// Always-visible bar button on the left (e.g. back on a pushed page).
  final Widget? leading;
  final List<Widget> slivers;

  /// Room for the floating tab bar.
  final double bottomPadding;

  @override
  State<LargeTitleScrollView> createState() => _LargeTitleScrollViewState();
}

class _LargeTitleScrollViewState extends State<LargeTitleScrollView> {
  static const _barHeight = 44.0;
  final _under = ValueNotifier(false);
  final _collapsed = ValueNotifier(false);

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final p = n.metrics.pixels;
    _under.value = p > 1;
    _collapsed.value = p > (widget.overline == null ? 34 : 52);
    return false;
  }

  @override
  void dispose() {
    _under.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final leading = widget.leading;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Space.gutter,
                  top + (leading == null ? 10 : _barHeight + 2),
                  Space.gutter,
                  18,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.overline != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  widget.overline!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: body(
                                    13,
                                    color: c.muted,
                                    weight: 600,
                                  ).copyWith(letterSpacing: 0.4),
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.title,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 8),
                        widget.trailing!,
                      ],
                    ],
                  ),
                ),
              ),
              ...widget.slivers,
              SliverToBoxAdapter(child: SizedBox(height: widget.bottomPadding)),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + _barHeight,
            child: ValueListenableBuilder<bool>(
              valueListenable: _collapsed,
              builder: (context, collapsed, _) => ValueListenableBuilder<bool>(
                valueListenable: _under,
                builder: (context, under, _) => IgnorePointer(
                  ignoring: !collapsed && leading == null,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: under ? 1 : 0,
                          duration: Motion.d(context, Motion.fast),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.bg,
                              border: Border(
                                bottom: BorderSide(
                                  color: c.line,
                                  width: hairline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: top,
                        left: 0,
                        right: 0,
                        height: _barHeight,
                        child: NavigationToolbar(
                          leading: leading == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: leading,
                                ),
                          middle: AnimatedOpacity(
                            opacity: collapsed ? 1 : 0,
                            duration: Motion.d(context, Motion.fast),
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(17, color: c.text, weight: 600),
                            ),
                          ),
                          trailing: widget.trailing == null
                              ? null
                              : IgnorePointer(
                                  ignoring: !collapsed,
                                  child: AnimatedOpacity(
                                    opacity: collapsed ? 1 : 0,
                                    duration: Motion.d(context, Motion.fast),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Transform.scale(
                                        scale: 0.82,
                                        child: widget.trailing,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
