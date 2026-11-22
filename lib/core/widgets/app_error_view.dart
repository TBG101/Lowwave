import 'package:flutter/material.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: compact ? 40 : 56,
          color: scheme.onSurfaceVariant,
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(height: compact ? 12 : 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 32,
          vertical: compact ? 12 : 24,
        ),
        child: content,
      ),
    );
  }
}
