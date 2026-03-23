import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:validators/validators.dart';

class ItemLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final FontWeight? weight;
  final bool isDisable;
  final bool isEditable;
  final Function()? onEdit;
  final Function()? onDelete;
  const ItemLabel(
    this.label,
    this.value, {
    this.color,
    this.weight,
    this.isDisable = false,
    this.isEditable = false,
    this.onDelete,
    this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isEditable)
          Text(
            label,
            style: AppCss.minimumBold
                .copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.8),
                )
                .copyWith(
                  decoration: isDisable ? TextDecoration.lineThrough : null,
                  color: isDisable
                      ? AppColors.black.withValues(alpha: 0.3)
                      : null,
                ),
          ),
        if (isEditable)
          GestureDetector(
            onTap: () => onEdit?.call(),
            child: Row(
              children: [
                Text(
                  label,
                  style: AppCss.minimumBold
                      .copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: AppColors.black.withValues(alpha: 0.8),
                      )
                      .copyWith(
                        decoration: isDisable
                            ? TextDecoration.lineThrough
                            : null,
                        color: isDisable
                            ? AppColors.black.withValues(alpha: 0.3)
                            : null,
                      ),
                ),
                const W(5),
                GestureDetector(
                  onTap: () => onEdit?.call(),
                  child: Icon(Icons.edit, size: 14, color: Colors.grey[700]!),
                ),
                if (onDelete != null) const W(5),
                if (onDelete != null)
                  GestureDetector(
                    onTap: () => onDelete?.call(),
                    child: Icon(
                      Icons.delete,
                      size: 14,
                      color: Colors.grey[700]!,
                    ),
                  ),
              ],
            ),
          ),
        Builder(
          builder: (context) {
            final isAUrl = isURL(value);
            return InkWell(
              onTap: isAUrl ? () {
                if (isAUrl) {
                  launchUrl(Uri.parse(value));
                }
              } : null,
              child: Text(
                value,
                style: AppCss.mediumRegular
                    .setColor(color ?? AppColors.black)
                    .copyWith(
                      decorationColor: isAUrl ? Colors.blue : null,
                      decoration: isAUrl ? TextDecoration.underline : isDisable ? TextDecoration.lineThrough : null,
                      color: isAUrl ? Colors.blue : isDisable
                          ? AppColors.black.withValues(alpha: 0.3)
                          : null,
                    ),
              ),
            );
          }
        ),
      ],
    );
  }
}
