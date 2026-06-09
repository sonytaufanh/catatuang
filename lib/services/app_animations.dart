import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 360);
  static const Curve curveIn = Curves.easeOutCubic;
  static const Curve curveOut = Curves.easeInOutCubic;

  static Route<T> fadeSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: curveIn,
          reverseCurve: curveOut,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(curved),
            child: RepaintBoundary(child: child),
          ),
        );
      },
    );
  }
}

class TabActivationScope extends InheritedNotifier<ValueNotifier<int>> {
  const TabActivationScope({
    super.key,
    required ValueNotifier<int> activeIndexListenable,
    required super.child,
  }) : super(notifier: activeIndexListenable);

  static ValueNotifier<int>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TabActivationScope>()
        ?.notifier;
  }
}

class AnimatedTabReveal extends StatefulWidget {
  const AnimatedTabReveal({
    super.key,
    required this.tabIndex,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppAnimations.normal,
    this.beginOffset = const Offset(0, 0.028),
  });

  final int tabIndex;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  @override
  State<AnimatedTabReveal> createState() => _AnimatedTabRevealState();
}

class _AnimatedTabRevealState extends State<AnimatedTabReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: widget.beginOffset,
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  ValueNotifier<int>? _scope;
  bool _isActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScope = TabActivationScope.maybeOf(context);
    if (_scope != nextScope) {
      _scope?.removeListener(_handleTabChanged);
      _scope = nextScope;
      _scope?.addListener(_handleTabChanged);
    }
    _syncWithActiveTab(initial: true);
  }

  void _handleTabChanged() {
    _syncWithActiveTab();
  }

  void _syncWithActiveTab({bool initial = false}) {
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final activeIndex = _scope?.value;
    final nextIsActive = activeIndex == widget.tabIndex;
    if (disableMotion) {
      _isActive = nextIsActive;
      _controller.value = 1;
      return;
    }
    if (initial && nextIsActive) {
      _isActive = true;
      _controller.value = 0;
      Future<void>.delayed(widget.delay, () {
        if (!mounted) return;
        _controller.forward();
      });
      return;
    }
    if (nextIsActive && !_isActive) {
      _isActive = true;
      _controller.value = 0;
      Future<void>.delayed(widget.delay, () {
        if (!mounted) return;
        _controller.forward();
      });
      return;
    }
    if (!nextIsActive && _isActive) {
      _isActive = false;
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _scope?.removeListener(_handleTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableMotion) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.pressedScale = 0.97,
    this.duration = AppAnimations.fast,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double pressedScale;
  final Duration duration;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    final scale = disableMotion || widget.onTap == null
        ? 1.0
        : (_pressed ? widget.pressedScale : 1.0);

    return AnimatedScale(
      scale: scale,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          splashFactory: InkRipple.splashFactory,
          child: widget.child,
        ),
      ),
    );
  }
}

class AnimatedFadeSlide extends StatefulWidget {
  const AnimatedFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppAnimations.normal,
    this.beginOffset = const Offset(0, 0.02),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  @override
  State<AnimatedFadeSlide> createState() => _AnimatedFadeSlideState();
}

class _AnimatedFadeSlideState extends State<AnimatedFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: widget.beginOffset,
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableMotion) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
