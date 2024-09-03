import 'package:flutter/material.dart';

class HourglassAnimation extends StatefulWidget {
  final Duration duration;

  const HourglassAnimation({Key? key, required this.duration}) : super(key: key);

  @override
  _HourglassAnimationState createState() => _HourglassAnimationState();
}

class _HourglassAnimationState extends State<HourglassAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return RotationTransition(
          turns: _rotationAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Icon(
              Icons.hourglass_top,
              size: 40,
              color: Colors.yellow[700],
            ),
          ),
        );
      },
    );
  }
}
