String sanitizePhoneNumber(String? phone) {
  if (phone == null || phone.trim().isEmpty) return '';

  // 1. Remove all flag emojis & regional indicator symbols & misc unicode emojis
  String s = phone
      .replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true), '')
      .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
      .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
      .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
      .trim();

  // 2. Fix duplicate '+' or multiple dial code segments (e.g. "+1 🇨🇦 +14384545648", "+1 +1438...", "+1+1438...")
  if (s.contains('+')) {
    final plusMatches = RegExp(r'\+\d+').allMatches(s).toList();
    if (plusMatches.length >= 2) {
      // Pick the longest matched segment starting with '+' (e.g. "+14384545648" over "+1")
      String longest = plusMatches.first.group(0)!;
      for (final m in plusMatches) {
        if (m.group(0)!.length > longest.length) {
          longest = m.group(0)!;
        }
      }
      s = longest;
    }
  }

  // 3. Remove consecutive leading plus signs e.g. "++1..."
  while (s.startsWith('++')) {
    s = s.substring(1);
  }

  // 4. Extract digits
  final digits = s.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';

  // Check for duplicated country code "11..." for North America (11 digits starting with 11)
  if (s.startsWith('+')) {
    if (digits.startsWith('11') && digits.length == 11) {
      return '+${digits.substring(1)}';
    }
    return '+$digits';
  }

  // If no plus, but 11 digits starting with 11
  if (digits.startsWith('11') && digits.length == 11) {
    return '+${digits.substring(1)}';
  }

  return s;
}
