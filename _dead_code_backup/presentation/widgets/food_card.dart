import 'dart:io';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_constants.dart';
import '../../../core/utils/app_translations.dart';
import '../../../data/models/food_item.dart';

class FoodCard extends StatelessWidget {
  final FoodItem food;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showAnimation;

  const FoodCard({
    super.key,
    required this.food,
    this.onTap,
    this.onDelete,
    this.showAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);

    if (showAnimation) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }

  Widget _buildCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.primary),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            _buildImage(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: AppTextStyles.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            timeago.format(food.timestamp, locale: 'es'),
                            style: AppTextStyles.caption,
                          ),
                        ),
                        if (food.aiModel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentCalories.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              food.aiModel!.split('/').last,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.accentCalories.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMacroChips(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Container(
      width: 90,
      height: 90,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.secondary),
        color: AppColors.background,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.secondary),
        child: food.imageUrl != null && food.imageUrl!.isNotEmpty
            ? Image.file(
                File(food.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.accentCalories.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 32,
          color: AppColors.accentCalories.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMacroChips(BuildContext context) {
    final t = AppTranslations.of(context);
    return Row(
      children: [
        _MacroChip(
          label: '${food.calories.toInt()}',
          suffix: t.translate('kcal'),
          color: AppColors.accentCalories,
        ),
        const SizedBox(width: 8),
        _MacroChip(
          label: '${food.protein.toInt()}',
          suffix: t.translate('p_short'),
          color: AppColors.accentProtein,
        ),
        const SizedBox(width: 8),
        _MacroChip(
          label: '${food.carbs.toInt()}',
          suffix: t.translate('c_short'),
          color: AppColors.accentCarbs,
        ),
        const SizedBox(width: 8),
        _MacroChip(
          label: '${food.fat.toInt()}',
          suffix: t.translate('g_short'),
          color: AppColors.accentFat,
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String suffix;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            suffix,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
