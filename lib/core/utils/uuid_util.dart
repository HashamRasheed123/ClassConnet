import 'dart:math';

/// Utility to generate and validate standard RFC 4122 Version 4 UUIDs
/// Compatible with PostgreSQL and Supabase uuid column types
class UuidUtil {
  static final _random = Random();

  /// Generates a valid UUID v4 string (e.g. "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d")
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Validates whether a given string is a valid UUID
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  /// Converts any string (like 'sub-1', 'slot-1792348572') into a consistent, valid UUID
  static String fromString(String input) {
    if (isValidUuid(input)) return input.toLowerCase();

    // Known mock subject mappings matching Supabase seed data
    switch (input) {
      case 'sub-1':
        return '11111111-1111-1111-1111-111111111111';
      case 'sub-2':
        return '22222222-2222-2222-2222-222222222222';
      case 'sub-3':
        return '33333333-3333-3333-3333-333333333333';
      case 'sub-4':
        return '44444444-4444-4444-4444-444444444444';
    }

    // Deterministic 16-byte derivation from input string
    final utf8Bytes = input.codeUnits;
    final bytes = List<int>.filled(16, 0);
    for (int i = 0; i < utf8Bytes.length; i++) {
      bytes[i % 16] = (bytes[i % 16] ^ (utf8Bytes[i] + i * 31)) & 0xFF;
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
