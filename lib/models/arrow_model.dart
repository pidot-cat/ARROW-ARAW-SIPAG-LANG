import 'package:flutter/material.dart';

enum ArrowDirection { up, down, left, right, white }

class ArrowSegment {
  final int x;
  final int y;

  ArrowSegment({required this.x, required this.y});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrowSegment &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class ArrowModel {
  final List<ArrowSegment> segments; // The path of the arrow
  final ArrowDirection direction; // The direction the head points
  final Color color;
  final double size; // Thickness/scale factor
  bool isEscaping;
  bool isRemoved;

  ArrowModel({
    required this.segments,
    required this.direction,
    required this.color,
    this.size = 1.0,
    this.isEscaping = false,
    this.isRemoved = false,
  });

  // Helper to get the head (last segment)
  ArrowSegment get head => segments.last;

  // Helper to get the tail (first segment)
  ArrowSegment get tail => segments.first;

  ArrowModel copyWith({
    List<ArrowSegment>? segments,
    ArrowDirection? direction,
    Color? color,
    double? size,
    bool? isEscaping,
    bool? isRemoved,
  }) {
    return ArrowModel(
      segments: segments ?? this.segments,
      direction: direction ?? this.direction,
      color: color ?? this.color,
      size: size ?? this.size,
      isEscaping: isEscaping ?? this.isEscaping,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }
}
