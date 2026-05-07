// lib/constants/app_styles.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyles {
  static TextStyle titleStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textColor,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textColor,
  );

  static const TextStyle hintTextStyle = TextStyle(
    fontSize: 16,
    color: AppColors.white,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  static const TextStyle smallTextStyle = TextStyle(
    fontSize: 14,
    color: AppColors.textColor,
  );

  static const TextStyle errorStyle = TextStyle(
    fontSize: 14,
    color: AppColors.errorText,
  );

  // تعديلات إضافية:
  static const TextStyle bodyTextStyle = TextStyle(
    fontFamily: 'Roboto', // أو font آخر حسب اختيارك
    fontWeight: FontWeight.normal,
  );

  static TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    color: Colors.grey[700],
    height: 1.5,
  );

  // مثال: نمط لعناوين الشاشات الفرعية
  static const TextStyle screenTitleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textColor,
  );

  // مثال: نمط لنص وصفي أصغر
  static TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textColor.withOpacity(0.7),
  );

  // مثال: نمط للنص العادي المستخدم في القوائم أو البطاقات
  static const TextStyle listItemTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textColor,
  );

  // مثال: نمط لنص وصفي في البطاقات
  static TextStyle listItemSubtitleStyle = TextStyle(
    fontSize: 14,
    color: Colors.grey[600],
  );
}
