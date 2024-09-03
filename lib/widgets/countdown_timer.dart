import 'package:flutter/material.dart';

class CountdownTimer extends StatelessWidget {
  final Duration duration;

  const CountdownTimer({Key? key, required this.duration}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Duration>(
      tween: Tween(begin: duration, end: Duration.zero),
      duration: duration,
      onEnd: () {
        print('Ride starting now!');
      },
      builder: (BuildContext context, Duration value, Widget? child) {
        return Text(
          _formatTimeRemaining(value),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
        );
      },
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
