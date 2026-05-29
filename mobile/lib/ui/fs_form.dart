import 'package:flutter/material.dart';

import 'tokens.dart';

class FSForm {
  const FSForm._();

  static InputDecoration textFieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return _baseDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  static InputDecoration dropdownDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return _baseDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
    );
  }

  static InputDecoration dateFieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    VoidCallback? onCalendarTap,
  }) {
    return _baseDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      suffixIcon: IconButton(
        onPressed: onCalendarTap,
        icon: const Icon(Icons.calendar_today_outlined),
      ),
    );
  }

  static InputDecoration textAreaDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
  }) {
    return _baseDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      alignLabelWithHint: true,
    );
  }

  static OutlineInputBorder border(BuildContext context, {Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(FSRadius.md),
      borderSide: BorderSide(color: color ?? FSColors.border(context)),
    );
  }

  static InputDecoration _baseDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    final fillColor =
        FSColors.isDark(context)
            ? FSColors.alpha(FSColors.surfaceDark, 0.88)
            : Colors.white;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.lg,
        vertical: FSSpacing.md,
      ),
      border: border(context),
      enabledBorder: border(context),
      focusedBorder: border(context, color: FSColors.primary),
      errorBorder: border(context, color: FSColors.danger),
      focusedErrorBorder: border(context, color: FSColors.danger),
    );
  }
}
