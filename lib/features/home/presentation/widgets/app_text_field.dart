// lib/features/home/presentation/widgets/app_text_field.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

const kInputDecoration = InputDecoration(
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  filled: false,
  isDense: true,
  contentPadding: EdgeInsets.zero,
);

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final bool readOnly;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    this.controller,
    required this.hint,
    this.readOnly = false,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: const Color(0xFF2D3748)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: keyboardType,
              cursorColor: AppColors.primary,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: kInputDecoration.copyWith(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              onChanged: onChanged,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            suffix!,
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}