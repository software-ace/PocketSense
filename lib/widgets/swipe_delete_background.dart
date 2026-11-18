import 'package:flutter/material.dart';

/// The red trash area a row shows while it is swiped away to delete.
class SwipeDeleteBackground extends StatelessWidget {
  /// For a card: its margin and corner radius, so the red matches its shape.
  final EdgeInsetsGeometry? margin;
  final double radius;
  const SwipeDeleteBackground({super.key, this.margin, this.radius = 0});

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(radius)),
    alignment: AlignmentDirectional.centerEnd,
    padding: const EdgeInsetsDirectional.only(end: 20),
    child: const Icon(Icons.delete, color: Colors.white),
  );
}
