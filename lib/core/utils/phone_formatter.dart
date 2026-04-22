import 'package:flutter/services.dart';

/// +998 XX XXX-XX-XX formatida telefon raqam formatlash
/// TextField.prefixText = '+998 ' bilan birga ishlatiladi.
/// Controller.text faqat variable qismni saqlaydi: "XX XXX-XX-XX"
class UzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 9 ? digits.substring(0, 9) : digits;

    final buf = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 2) buf.write(' ');
      if (i == 5) buf.write('-');
      if (i == 7) buf.write('-');
      buf.write(capped[i]);
    }

    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// "90 123-45-67" → "+998901234567"
String phoneToRaw(String formatted) =>
    '+998${formatted.replaceAll(RegExp(r'\D'), '')}';

/// "+998901234567" → "998901234567@uyborapp.uz"
String phoneToSyntheticEmail(String rawPhone) =>
    '${rawPhone.replaceAll('+', '')}@uyborapp.uz';
