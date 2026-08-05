import 'package:flutter/material.dart';

@immutable
class KpiMetric {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const KpiMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  KpiMetric copyWith({
    String? title,
    String? value,
    IconData? icon,
    Color? color,
    String? subtitle,
  }) {
    return KpiMetric(
      title: title ?? this.title,
      value: value ?? this.value,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KpiMetric &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          value == other.value &&
          icon == other.icon &&
          color == other.color &&
          subtitle == other.subtitle;

  @override
  int get hashCode =>
      title.hashCode ^
      value.hashCode ^
      icon.hashCode ^
      color.hashCode ^
      subtitle.hashCode;
}
