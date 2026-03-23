import 'package:flutter/material.dart';

import '../brand.dart';
import '../dimensions.dart';

class ResFormField extends StatelessWidget {
  const ResFormField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: ResColors.foreground,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ResColors.mutedForeground,
        ),
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ResColors.mutedForeground,
        ),
        filled: true,
        fillColor: ResColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.destructive, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );
  }
}

class ResDropdownField<T> extends StatelessWidget {
  const ResDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: ResColors.foreground,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ResColors.mutedForeground,
        ),
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ResColors.mutedForeground,
        ),
        filled: true,
        fillColor: ResColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResRadius.md),
          borderSide: BorderSide(color: ResColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}