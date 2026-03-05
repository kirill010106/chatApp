import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final String? avatarUrl;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size = 48,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppTheme.cardColor,
      child: Text(
        letter,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
