import 'package:flutter/material.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';

/// Infers the on-screen keyboard mode name from a [TextInputType].
///
/// Returns `'numeric'` for number / phone / decimal inputs,
/// `'default'` for everything else (normal QWERTY).
String _inferKeyboardMode(TextInputType? type) {
  if (type == null) return 'default';
  if (type == TextInputType.number ||
      type == TextInputType.phone ||
      type == const TextInputType.numberWithOptions(decimal: true) ||
      type == const TextInputType.numberWithOptions(signed: true) ||
      type ==
          const TextInputType.numberWithOptions(decimal: true, signed: true)) {
    return 'numeric';
  }
  // Check the index — TextInputType uses indices internally.
  // number = 2, phone = 3. This catches custom numberWithOptions combos.
  final idx = type.index;
  if (idx == 2 || idx == 3) return 'numeric';
  return 'default';
}

/// A drop-in replacement for [TextField] that automatically uses the
/// [OnscreenKeyboardTextField] on tablet/desktop when the feature is enabled,
/// and falls back to a plain [TextField] otherwise.
///
/// When [useOnscreenKeyboard] is true the widget also auto-selects the right
/// keyboard mode (`'numeric'` vs `'default'`) based on [keyboardType], unless
/// [onscreenKeyboardMode] is explicitly set.
class OnscreenKeyboardAwareField extends StatelessWidget {
  /// Whether to use the on-screen keyboard overlay.
  final bool useOnscreenKeyboard;

  /// Explicit keyboard mode override. If null, inferred from [keyboardType].
  final String? onscreenKeyboardMode;

  // ── Mirror the most-used TextField props ──────────────────────────────
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextDirection? textDirection;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool? enabled;
  final Color? cursorColor;
  final double cursorWidth;
  final double? cursorHeight;

  const OnscreenKeyboardAwareField({
    super.key,
    required this.useOnscreenKeyboard,
    this.onscreenKeyboardMode,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.enabled,
    this.cursorColor,
    this.cursorWidth = 2.0,
    this.cursorHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (useOnscreenKeyboard) {
      final mode = onscreenKeyboardMode ?? _inferKeyboardMode(keyboardType);
      return OnscreenKeyboardTextField(
        onscreenKeyboardMode: mode,
        controller: controller,
        focusNode: focusNode,
        decoration: decoration,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textAlignVertical: textAlignVertical,
        textDirection: textDirection,
        readOnly: readOnly,
        showCursor: showCursor,
        autofocus: autofocus,
        obscureText: obscureText,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onSubmitted: onSubmitted,
        enabled: enabled,
        cursorColor: cursorColor,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      readOnly: readOnly,
      showCursor: showCursor,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      enabled: enabled,
      cursorColor: cursorColor,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
    );
  }
}

/// A drop-in replacement for [TextFormField] that uses
/// [OnscreenKeyboardTextFormField] when on-screen keyboard is active,
/// otherwise falls back to a plain [TextFormField].
class OnscreenKeyboardAwareFormField extends StatelessWidget {
  final bool useOnscreenKeyboard;
  final String? onscreenKeyboardMode;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final Color? cursorColor;

  const OnscreenKeyboardAwareFormField({
    super.key,
    required this.useOnscreenKeyboard,
    this.onscreenKeyboardMode,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.validator,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorColor,
  });

  @override
  Widget build(BuildContext context) {
    if (useOnscreenKeyboard) {
      final mode = onscreenKeyboardMode ?? _inferKeyboardMode(keyboardType);
      return OnscreenKeyboardTextFormField(
        onscreenKeyboardMode: mode,
        controller: controller,
        focusNode: focusNode,
        decoration: decoration,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        style: style,
        textAlign: textAlign,
        textAlignVertical: textAlignVertical,
        readOnly: readOnly,
        autofocus: autofocus,
        obscureText: obscureText,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        enabled: enabled,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        cursorColor: cursorColor,
      );
    }

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      enabled: enabled,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorColor: cursorColor,
    );
  }
}
