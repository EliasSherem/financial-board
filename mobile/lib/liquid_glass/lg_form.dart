import 'package:flutter/material.dart';

import 'lg_tokens.dart';

class LGForm {
  const LGForm._();

  static const double fieldMinHeight = 58;
  static const EdgeInsets fieldContentPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 17,
  );

  static InputDecoration solidInputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return _baseDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      fillColor: LGColors.surfaceSolid(context),
      borderColor: LGColors.alpha(LGColors.textSecondary(context), 0.20),
    );
  }

  static InputDecoration glassInputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return _baseDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      fillColor: LGColors.glassStrong(context),
      borderColor: LGColors.glassStroke(context),
    );
  }

  static InputDecoration dropdownDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return solidInputDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
    );
  }

  static InputDecoration textAreaDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
  }) {
    return solidInputDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
    ).copyWith(alignLabelWithHint: true);
  }

  static InputDecoration dateFieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    VoidCallback? onCalendarTap,
  }) {
    return solidInputDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      suffixIcon: IconButton(
        onPressed: onCalendarTap,
        icon: const Icon(Icons.calendar_today_outlined),
      ),
    );
  }

  static OutlineInputBorder border(
    BuildContext context, {
    Color? color,
    double radius = LGRadius.lg,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: color ?? LGColors.alpha(LGColors.textSecondary(context), 0.20),
      ),
    );
  }

  static InputDecoration _baseDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
    required Color fillColor,
    required Color borderColor,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      isDense: false,
      filled: true,
      fillColor: fillColor,
      constraints: const BoxConstraints(minHeight: fieldMinHeight),
      contentPadding: fieldContentPadding,
      border: border(context, color: borderColor),
      enabledBorder: border(context, color: borderColor),
      focusedBorder: border(context, color: LGColors.primaryBlue),
      errorBorder: border(context, color: LGColors.danger),
      focusedErrorBorder: border(context, color: LGColors.danger),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        color: LGColors.textSecondary(context),
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(
        color: LGColors.primaryBlue,
        fontWeight: FontWeight.w800,
        backgroundColor: fillColor,
      ),
      hintStyle: TextStyle(
        color: LGColors.alpha(LGColors.textSecondary(context), 0.72),
      ),
    );
  }
}
