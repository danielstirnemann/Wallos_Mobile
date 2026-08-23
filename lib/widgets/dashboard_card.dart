import 'package:flutter/material.dart';

/// Reusable Dashboard Card Widget - Kompaktes Format
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? backgroundColor;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon links
            Icon(icon, size: 24, color: Colors.blue[700]),
            const SizedBox(width: 12),
            
            // Titel + Subtitle (expandiert)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Preis rechts (fettgedruckt)
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
