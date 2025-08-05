import 'package:flutter/material.dart';

class FlexibleBottomActionBar extends StatelessWidget {
  final VoidCallback? primaryAction;
  final String primaryLabel;
  final IconData primaryIcon;
  final Color? primaryColor;
  final VoidCallback? secondaryAction;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final Color? secondaryColor;

  const FlexibleBottomActionBar({
    super.key,
    this.primaryAction,
    required this.primaryLabel,
    required this.primaryIcon,
    this.primaryColor,
    this.secondaryAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (secondaryAction != null && secondaryLabel != null && secondaryIcon != null) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: secondaryAction,
                  icon: Icon(secondaryIcon),
                  label: Text(secondaryLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor ?? Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: primaryAction,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAction != null 
                      ? (primaryColor ?? Theme.of(context).primaryColor)
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}