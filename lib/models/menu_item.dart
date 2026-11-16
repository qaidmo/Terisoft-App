import 'package:flutter/material.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final String? screenNameKey;
  final Color color;

  const MenuItem({
    required this.title,
    required this.icon,
    this.screenNameKey,
    this.color = Colors.blue,
  });
}