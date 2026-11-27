import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../utils/uuid_util.dart';
import '../../models/models.dart';

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}

class AuthService {
  static const String _keyActiveSession = 'auth_active_user_session';
  static const String _keyStudentRegistry = 'auth_student_accounts_registry';
  static const String _keyAdminPasscode = 'auth_admin_master_passcode';
  static const String _keyAdminWhitelist = 'auth_admin_authorized_roll_numbers';
  static const String _keyUploaderRequests = 'auth_uploader_verification_requests';
  static const String _keyStudentVerifications =
      'auth_student_verification_requests_v1';
  static const List<String> _defaultAdminWhitelist = ['23-SE-402', 'ADMIN-01', 'CR-01'];
  static const String _salt = 'kzynovex_salt_2026_';

  /// Designated Administrator Emails loaded securely from AppConfig
  static Set<String> get adminEmails => AppConfig.adminEmails.toSet();

  static bool isAdminEmail(String? email) =>
      AppConfig.isDesignatedAdminEmail(email);

  static final AuthService instance = AuthService._();
  AuthService._();

  UserModel? _currentSession;
  UserModel? get currentSession => _currentSession;

  String _hashPin(String pin) {
    final bytes = utf8.encode('$_salt$pin');
    return sha256.convert(bytes).toString();
  }

  String _normalizeRoll(String roll) => roll.trim().toUpperCase();

  bool get _isSupabaseActive {
    if (!AppConfig.isSupabaseConfigured) return false;
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retrieve all locally registered student records
  Future<Map<String, Map<String, dynamic>>> _loadRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyStudentRegistry);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final map = decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
        // Purge legacy fake test accounts
        map.removeWhere((k, v) {
          final id = v['id'] as String? ?? '';
          final email = (v['email'] as String? ?? '').toLowerCase();
          final name = v['name'] as String? ?? '';
          return id.startsWith('user-00') ||
              id.startsWith('user-top') ||
              name.contains('Kzynovex Scholar') ||
              name == 'Sarah Kzynovex' ||
              name == 'Alex Turner' ||
              name == 'Elena Rostova' ||
              name == 'Devon Lane' ||
              name == 'Marcus Wright' ||
              email == 'rayyan@class.edu' ||
              email == 'ayesha.noor@class.edu' ||
              email == 'hamza.tariq@class.edu' ||
              email == 'fatima.zahra@class.edu';
        });
        return map;
      }
    } catch (e) {
      debugPrint('Error loading student registry: $e');
    }
    return {};
  }

  Future<void> _saveRegistry(Map<String, Map<String, dynamic>> registry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStudentRegistry, jsonEncode(registry));
    } catch (e) {
      debugPrint('Error saving student registry: $e');
    }
  }

  /// Check whether a student has an active saved session
  Future<UserModel?> getActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyActiveSession);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        var user = UserModel.fromMap(map);
        // Auto-elevate if user's email is in the designated admin list
        if (isAdminEmail(user.email) && (!user.isAdmin || !user.canUpload)) {
          user = user.copyWith(
            role: 'admin',
            canUpload: true,
            uploadRequestStatus: 'approved',
            isKzynovexVerified: true,
          );
          await _saveActiveSession(user);
        }
        _currentSession = user;
        return user;
      }
    } catch (e) {
      debugPrint('Error loading active session: $e');
    }
    _currentSession = null;
    return null;
  }

  Future<void> _saveActiveSession(UserModel user) async {
    _currentSession = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveSession, jsonEncode(user.toMap()));
    } catch (e) {
      debugPrint('Error saving active session: $e');
    }
  }

  Future<void> logout() async {
    _currentSession = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveSession);
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('Error signing out GoogleSignIn: $e');
    }
  }

  /// Register / Claim Account with Roll No, Name, and Security PIN
  Future<AuthResult> registerStudent({
    required String rollNo,
    required String name,
    required String pin,
    String? email,
  }) async {
    final cleanRoll = _normalizeRoll(rollNo);
    final cleanName = name.trim();
    final cleanPin = pin.trim();

    if (cleanRoll.isEmpty) {
      return const AuthResult(success: false, message: 'Please enter your Roll Number.');
    }
    if (cleanName.isEmpty) {
      return const AuthResult(success: false, message: 'Please enter your Full Name.');
    }
    if (cleanPin.length < 4) {
      return const AuthResult(
        success: false,
        message: 'Security PIN must be at least 4 digits.',
      );
    }

    final registry = await _loadRegistry();

    // Check if roll number is already claimed
    if (registry.containsKey(cleanRoll)) {
      return AuthResult(
        success: false,
        message:
            'Roll No "$cleanRoll" is already claimed and locked with a Security PIN. Please log in with your PIN. If someone else claimed your roll number, contact your Admin/CR.',
      );
    }

    // Also check remote Supabase if connected
    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('users')
            .select()
            .eq('roll_no', cleanRoll)
            .maybeSingle();

        if (res != null) {
          return AuthResult(
            success: false,
            message:
                'Roll No "$cleanRoll" is already registered in the database. Please log in with your PIN.',
          );
        }
      } catch (e) {
        debugPrint('Supabase roll check error (continuing local): $e');
      }
    }

    final userId = UuidUtil.generate();
    final cleanEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : '${cleanRoll.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@class.edu';

    final hashedPin = _hashPin(cleanPin);

    final user = UserModel(
      id: userId,
      name: cleanName,
      email: cleanEmail,
      role: 'student',
      rollNo: cleanRoll,
      credits: 50, // Welcome bonus
      streakCount: 1,
      isKzynovexVerified: false,
      isLoggedIn: true,
    );

    // Save locally to registry
    registry[cleanRoll] = {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'roll_no': cleanRoll,
      'pin_hash': hashedPin,
      'credits': user.credits,
      'streak_count': user.streakCount,
      'is_kzynovex_verified': false,
      'registered_at': DateTime.now().toIso8601String(),
    };
    await _saveRegistry(registry);
    await _saveActiveSession(user);

    // Attempt remote upsert if online
    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        await client.from('users').upsert({
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'role': user.role,
          'credits': user.credits,
          'streak_count': user.streakCount,
          'is_kzynovex_verified': false,
        });
      } catch (e) {
        debugPrint('Remote user creation skipped/failed: $e');
      }
    }

    return AuthResult(
      success: true,
      message: 'Account claimed successfully! Welcome, ${user.name}.',
      user: user,
    );
  }

  /// Log In with Roll No and Security PIN
  Future<AuthResult> loginStudent({
    required String rollNo,
    required String pin,
  }) async {
    final cleanRoll = _normalizeRoll(rollNo);
    final cleanPin = pin.trim();

    if (cleanRoll.isEmpty) {
      return const AuthResult(success: false, message: 'Please enter your Roll Number.');
    }
    if (cleanPin.isEmpty) {
      return const AuthResult(success: false, message: 'Please enter your Security PIN.');
    }

    final registry = await _loadRegistry();

    // If registry doesn't have it, check Supabase or prompt to Claim Account
    if (!registry.containsKey(cleanRoll)) {
      return AuthResult(
        success: false,
        message:
            'No account found for Roll No "$cleanRoll". Please tap "Claim Account" to set your Name and Security PIN first.',
      );
    }

    final record = registry[cleanRoll]!;
    final expectedHash = record['pin_hash'] as String?;
    final incomingHash = _hashPin(cleanPin);

    if (expectedHash != null && expectedHash != incomingHash) {
      return const AuthResult(
        success: false,
        message:
            'Incorrect Security PIN for this Roll Number. Impersonation attempt blocked. If you forgot your PIN, please contact your Admin/CR.',
      );
    }

    final user = UserModel(
      id: record['id'] as String? ?? UuidUtil.generate(),
      name: record['name'] as String? ?? 'Student',
      email: record['email'] as String? ?? '$cleanRoll@class.edu',
      role: record['role'] as String? ?? 'student',
      credits: (record['credits'] as num?)?.toInt() ?? 30,
      streakCount: (record['streak_count'] as num?)?.toInt() ?? 1,
      isKzynovexVerified: record['is_kzynovex_verified'] as bool? ?? false,
      rollNo: cleanRoll,
      isLoggedIn: true,
    );

    await _saveActiveSession(user);

    return AuthResult(
      success: true,
      message: 'Welcome back, ${user.name}!',
      user: user,
    );
  }

  /// Public session saver
  Future<void> saveSession(UserModel user) async {
    await _saveActiveSession(user);
  }

  /// Verify Admin Passcode to unlock admin features (case-insensitive with environment configuration)
  Future<bool> verifyAdminPasscode(String passkey) async {
    final clean = passkey.trim().toLowerCase();
    if (clean.isEmpty) return false;

    // Configured admin password from environment (.env / env.json)
    final envPass = AppConfig.adminPassword.trim().toLowerCase();
    if (envPass.isNotEmpty && clean == envPass) return true;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyAdminPasscode)?.trim().toLowerCase();
    if (saved != null && saved.isNotEmpty && clean == saved) {
      return true;
    }
    return false;
  }

  /// Retrieve authorized Admin Roll Numbers list
  Future<List<String>> getAdminWhitelist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyAdminWhitelist);
      if (list != null && list.isNotEmpty) {
        return list.map((r) => _normalizeRoll(r)).toList();
      }
    } catch (e) {
      debugPrint('Error loading admin whitelist: $e');
    }
    return List<String>.from(_defaultAdminWhitelist);
  }

  /// Check whether a student roll number is authorized for admin privileges
  Future<bool> isRollWhitelistedForAdmin(String rollNo) async {
    final clean = _normalizeRoll(rollNo);
    if (clean.isEmpty) return false;
    final list = await getAdminWhitelist();
    return list.contains(clean);
  }

  /// Add a roll number to the Admin whitelist
  Future<bool> addAdminToWhitelist(String rollNo) async {
    final clean = _normalizeRoll(rollNo);
    if (clean.isEmpty) return false;
    final current = await getAdminWhitelist();
    if (!current.contains(clean)) {
      current.add(clean);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyAdminWhitelist, current);
    }
    return true;
  }

  /// Remove a roll number from the Admin whitelist
  Future<bool> removeAdminFromWhitelist(String rollNo) async {
    final clean = _normalizeRoll(rollNo);
    final current = await getAdminWhitelist();
    if (current.remove(clean)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyAdminWhitelist, current);
      return true;
    }
    return false;
  }

  /// Strict Admin Panel Verification:
  /// BOTH conditions must be true:
  /// 1. User email MUST match designated Admin email (from AppConfig.adminEmails)
  /// 2. Admin password must be entered and valid.
  Future<AuthResult> verifyAdminAccess({
    required String? rollNo,
    required String passkey,
    String? email,
  }) async {
    // Condition 1: Email MUST match designated admin email!
    if (!isAdminEmail(email)) {
      return const AuthResult(
        success: false,
        message:
            'Access Denied: Only designated Admin Google Accounts can access the Admin Panel.',
      );
    }

    // Condition 2: Admin password MUST be valid!
    final cleanPass = passkey.trim();
    if (cleanPass.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Please enter the Admin Password.',
      );
    }

    final isPassValid = await verifyAdminPasscode(cleanPass);
    if (!isPassValid) {
      return const AuthResult(
        success: false,
        message: 'Incorrect Admin Password. Access denied.',
      );
    }

    return const AuthResult(
      success: true,
      message: 'Admin credentials and password verified. Admin Console unlocked.',
    );
  }

  /// Change Admin Passcode (Must provide current passkey)
  Future<bool> changeAdminPasscode({
    required String oldPasskey,
    required String newPasskey,
  }) async {
    if (!await verifyAdminPasscode(oldPasskey)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAdminPasscode, newPasskey.trim());
    return true;
  }

  /// Finds the registry key for a user by rollNo, email, or userId.
  String? _findRegistryKey(
    Map<String, Map<String, dynamic>> registry, {
    String? rollNo,
    String? email,
    String? userId,
  }) {
    final cleanRoll = _normalizeRoll(rollNo ?? '');
    final cleanEmail = (email ?? '').trim().toLowerCase();
    final cleanId = (userId ?? '').trim();

    if (cleanRoll.isNotEmpty && registry.containsKey(cleanRoll)) {
      return cleanRoll;
    }
    if (cleanEmail.isNotEmpty) {
      if (registry.containsKey(cleanEmail)) return cleanEmail;
      if (registry.containsKey('GOOGLE-$cleanEmail')) {
        return 'GOOGLE-$cleanEmail';
      }
    }
    if (cleanId.isNotEmpty && registry.containsKey(cleanId)) {
      return cleanId;
    }

    for (final entry in registry.entries) {
      final map = entry.value;
      final recId = (map['id'] as String? ?? '').trim();
      final recRoll = _normalizeRoll(map['roll_no'] as String? ?? '');
      final recEmail = (map['email'] as String? ?? '').trim().toLowerCase();
      final recGoogle =
          (map['google_email'] as String? ?? '').trim().toLowerCase();

      if (cleanId.isNotEmpty && recId == cleanId) return entry.key;
      if (cleanRoll.isNotEmpty && recRoll == cleanRoll) return entry.key;
      if (cleanEmail.isNotEmpty &&
          (recEmail == cleanEmail || recGoogle == cleanEmail)) {
        return entry.key;
      }
      // Also allow matching when `rollNo` parameter was passed an email or userId
      if (cleanRoll.isNotEmpty) {
        final rawLower = (rollNo ?? '').trim().toLowerCase();
        if (recEmail == rawLower ||
            recGoogle == rawLower ||
            recId.toLowerCase() == rawLower) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Admin function: Reset PIN for a student who forgot it
  Future<bool> adminResetStudentPin({
    required String rollNo,
    required String newPin,
  }) async {
    final registry = await _loadRegistry();
    final key = _findRegistryKey(registry, rollNo: rollNo, email: rollNo, userId: rollNo);
    if (key == null) return false;

    registry[key]!['pin_hash'] = _hashPin(newPin.trim());
    await _saveRegistry(registry);
    return true;
  }

  /// Seed designated admin accounts into registry and ensure all designated
  /// admin emails have full admin privileges even if registry was already populated.
  Future<void> seedDefaultAccountsIfEmpty() async {
    final adminList = AppConfig.adminEmails;
    if (adminList.isEmpty) return;

    final registry = await _loadRegistry();
    final pass = AppConfig.adminPassword.isNotEmpty
        ? AppConfig.adminPassword
        : 'admin';

    bool changed = false;
    for (int i = 0; i < adminList.length; i++) {
      final email = adminList[i].trim().toLowerCase();
      if (email.isEmpty) continue;

      final existingKey = _findRegistryKey(registry, email: email);
      if (existingKey != null) {
        final existing = registry[existingKey]!;
        if (existing['role'] != 'admin' || existing['can_upload'] != true) {
          existing['role'] = 'admin';
          existing['can_upload'] = true;
          existing['upload_request_status'] = 'approved';
          existing['is_kzynovex_verified'] = true;
          changed = true;
        }
        continue;
      }

      final username = email.split('@').first;
      final capitalized = username.isNotEmpty
          ? '${username[0].toUpperCase()}${username.substring(1)}'
          : 'Admin';
      final adminUser = UserModel(
        id: UuidUtil.fromString('admin-$email'),
        name: 'Admin $capitalized',
        email: email,
        role: 'admin',
        credits: 500,
        streakCount: 1,
        isKzynovexVerified: true,
        rollNo: 'ADMIN-${i + 1}',
        canUpload: true,
        uploadRequestStatus: 'approved',
        authProvider: 'google',
      );

      registry[email] = {
        ...adminUser.toMap(),
        'pin_hash': _hashPin(pass),
        'google_email': email,
        'registered_at': DateTime.now().toIso8601String(),
      };
      changed = true;
    }
    if (changed) {
      await _saveRegistry(registry);
    }
  }

  /// Get list of registered users as UserModels (for Admin user management)
  Future<List<UserModel>> getAllUsers() async {
    await seedDefaultAccountsIfEmpty();
    final registry = await _loadRegistry();

    if (_isSupabaseActive) {
      try {
        final rows = await Supabase.instance.client
            .from('users')
            .select()
            .timeout(const Duration(seconds: 4));
        bool changed = false;
        for (final raw in (rows as List)) {
          final remote = Map<String, dynamic>.from(raw as Map);
          final remoteId = remote['id']?.toString() ?? '';
          final remoteEmail =
              (remote['email'] as String? ?? '').trim().toLowerCase();
          final remoteRoll = remote['roll_no'] as String?;
          final isDesignatedAdmin = isAdminEmail(remoteEmail);
          final existingKey = _findRegistryKey(
            registry,
            rollNo: remoteRoll,
            email: remoteEmail,
            userId: remoteId,
          );
          if (existingKey != null) {
            final existing = registry[existingKey]!;
            existing['id'] = remoteId.isNotEmpty ? remoteId : existing['id'];
            existing['name'] = remote['name'] ?? existing['name'];
            existing['email'] = remote['email'] ?? existing['email'];
            existing['role'] = isDesignatedAdmin
                ? 'admin'
                : (remote['role'] ?? existing['role']);
            existing['credits'] = remote['credits'] ?? existing['credits'];
            existing['streak_count'] =
                remote['streak_count'] ?? existing['streak_count'];
            existing['is_kzynovex_verified'] = isDesignatedAdmin ||
                (remote['is_kzynovex_verified'] ??
                    existing['is_kzynovex_verified']);
            if (isDesignatedAdmin) {
              existing['can_upload'] = true;
              existing['upload_request_status'] = 'approved';
            } else if (remote['can_upload'] != null) {
              existing['can_upload'] = remote['can_upload'];
            }
            changed = true;
          } else {
            final newKey = (remoteRoll != null && remoteRoll.trim().isNotEmpty)
                ? _normalizeRoll(remoteRoll)
                : (remoteEmail.isNotEmpty
                    ? 'GOOGLE-$remoteEmail'
                    : (remoteId.isNotEmpty ? remoteId : UuidUtil.generate()));
            final canUp =
                isDesignatedAdmin || (remote['can_upload'] == true);
            registry[newKey] = {
              'id': remoteId.isNotEmpty ? remoteId : UuidUtil.generate(),
              'name': remote['name'] ?? 'Student',
              'email': remote['email'] ?? '',
              'role': isDesignatedAdmin
                  ? 'admin'
                  : (remote['role'] ?? 'student'),
              'roll_no': remoteRoll,
              'credits': remote['credits'] ?? (isDesignatedAdmin ? 500 : 50),
              'streak_count': remote['streak_count'] ?? 1,
              'is_kzynovex_verified':
                  isDesignatedAdmin || (remote['is_kzynovex_verified'] ?? false),
              'can_upload': canUp,
              'upload_request_status': canUp ? 'approved' : 'none',
            };
            changed = true;
          }
        }
        if (changed) {
          await _saveRegistry(registry);
        }
      } catch (e) {
        debugPrint('Supabase remote users fetch skipped: $e');
      }
    }

    final list = registry.values.map((map) => UserModel.fromMap(map)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Admin function: Create/Pre-register student with initial PIN
  Future<AuthResult> adminCreateUser({
    required UserModel user,
    required String pin,
  }) async {
    final cleanRoll = _normalizeRoll(user.rollNo ?? '');
    if (cleanRoll.isEmpty) {
      return const AuthResult(success: false, message: 'Roll Number cannot be empty.');
    }
    if (user.name.trim().isEmpty) {
      return const AuthResult(success: false, message: 'Student Name cannot be empty.');
    }

    final registry = await _loadRegistry();
    if (registry.containsKey(cleanRoll)) {
      return AuthResult(
        success: false,
        message: 'A student with Roll No "$cleanRoll" already exists.',
      );
    }

    final newUser = user.copyWith(
      id: user.id.isEmpty ? UuidUtil.generate() : user.id,
      rollNo: cleanRoll,
      name: user.name.trim(),
      email: user.email.trim(),
    );

    registry[cleanRoll] = {
      'id': newUser.id,
      'name': newUser.name,
      'email': newUser.email,
      'role': newUser.role,
      'roll_no': cleanRoll,
      'pin_hash': _hashPin(pin.trim()),
      'credits': newUser.credits,
      'streak_count': newUser.streakCount,
      'is_kzynovex_verified': newUser.isKzynovexVerified,
      'registered_at': DateTime.now().toIso8601String(),
    };

    await _saveRegistry(registry);

    if (newUser.role == 'admin') {
      await addAdminToWhitelist(cleanRoll);
    }

    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        await client.from('users').upsert({
          'id': newUser.id,
          'name': newUser.name,
          'email': newUser.email,
          'role': newUser.role,
          'credits': newUser.credits,
          'streak_count': newUser.streakCount,
          'is_kzynovex_verified': newUser.isKzynovexVerified,
        });
      } catch (e) {
        debugPrint('Supabase remote sync skipped: $e');
      }
    }

    return AuthResult(
      success: true,
      message: 'Student "${newUser.name}" ($cleanRoll) added successfully.',
      user: newUser,
    );
  }

  /// Admin function: Update user profile and optionally change role/credits/PIN
  Future<bool> adminUpdateUser(UserModel user, {String? newPin}) async {
    final cleanRoll = _normalizeRoll(user.rollNo ?? '');
    final registry = await _loadRegistry();
    final key = _findRegistryKey(
      registry,
      rollNo: user.rollNo,
      email: user.email,
      userId: user.id,
    );

    final targetKey = key ??
        (cleanRoll.isNotEmpty
            ? cleanRoll
            : (user.email.trim().isNotEmpty
                ? 'GOOGLE-${user.email.trim().toLowerCase()}'
                : user.id));
    if (targetKey.isEmpty) return false;

    final existing = registry[targetKey] ?? <String, dynamic>{'id': user.id};
    existing['id'] = user.id.isNotEmpty ? user.id : (existing['id'] ?? UuidUtil.generate());
    existing['name'] = user.name.trim();
    existing['email'] = user.email.trim();
    existing['role'] = user.role;
    if (cleanRoll.isNotEmpty) {
      existing['roll_no'] = cleanRoll;
    }
    existing['credits'] = user.credits;
    existing['streak_count'] = user.streakCount;
    existing['is_kzynovex_verified'] = user.isKzynovexVerified;
    existing['can_upload'] = user.canUpload;
    existing['upload_request_status'] = user.uploadRequestStatus;
    if (newPin != null && newPin.trim().isNotEmpty) {
      existing['pin_hash'] = _hashPin(newPin.trim());
    }
    registry[targetKey] = existing;

    await _saveRegistry(registry);

    if (cleanRoll.isNotEmpty) {
      if (user.role == 'admin') {
        await addAdminToWhitelist(cleanRoll);
      } else if (cleanRoll != '23-SE-402') {
        await removeAdminFromWhitelist(cleanRoll);
      }
    }

    // If active session belongs to this user, update active session
    final currentSession = await getActiveSession();
    if (currentSession != null) {
      final sameId = currentSession.id == user.id;
      final sameRoll = cleanRoll.isNotEmpty &&
          _normalizeRoll(currentSession.rollNo ?? '') == cleanRoll;
      final sameEmail = user.email.trim().isNotEmpty &&
          currentSession.email.trim().toLowerCase() ==
              user.email.trim().toLowerCase();
      if (sameId || sameRoll || sameEmail) {
        await _saveActiveSession(user);
      }
    }

    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        final current = await getActiveSession();
        final adminId = (current != null && current.isAdmin) ? current.id : null;
        if (adminId != null) {
          try {
            await client.rpc('admin_update_user_secure', params: {
              'p_admin_id': UuidUtil.fromString(adminId),
              'p_target_user_id': UuidUtil.fromString(user.id),
              'p_name': user.name,
              'p_email': user.email,
              'p_role': user.role,
              'p_credits': user.credits,
              'p_streak_count': user.streakCount,
              'p_is_verified': user.isKzynovexVerified,
              'p_can_upload': user.canUpload,
            }).timeout(const Duration(seconds: 6));
            return true;
          } catch (rpcErr) {
            final s = rpcErr.toString().toLowerCase();
            if (!(s.contains('pgrst202') ||
                s.contains('42883') ||
                s.contains('could not find the function'))) {
              debugPrint('admin_update_user_secure RPC failed: $rpcErr');
            }
          }
        }
        await client.from('users').upsert({
          'id': UuidUtil.fromString(user.id),
          'name': user.name,
          'email': user.email,
          'role': user.role,
          'credits': user.credits,
          'streak_count': user.streakCount,
          'is_kzynovex_verified': user.isKzynovexVerified,
          'can_upload': user.canUpload,
        }).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Supabase remote sync skipped: $e');
      }
    }

    return true;
  }

  /// Syncs a bounded credit delta via server-side SECURITY DEFINER RPCs
  /// (`award_quiz_credits` or `adjust_resource_credits`).
  Future<void> syncCreditsDelta(
    String userId,
    int delta, {
    bool isQuiz = false,
  }) async {
    if (delta == 0 || !_isSupabaseActive) return;
    try {
      final client = Supabase.instance.client;
      final rpcName =
          (isQuiz && delta > 0) ? 'award_quiz_credits' : 'adjust_resource_credits';
      await client.rpc(rpcName, params: {
        'p_user_id': UuidUtil.fromString(userId),
        'p_delta': delta,
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Supabase credit delta RPC skipped: $e');
    }
  }

  /// Admin function: Delete/unclaim user account
  Future<bool> adminDeleteUser(String rollNo) async {
    final registry = await _loadRegistry();
    final key = _findRegistryKey(
      registry,
      rollNo: rollNo,
      email: rollNo,
      userId: rollNo,
    );
    if (key == null) return false;

    final removed = registry.remove(key);
    await _saveRegistry(registry);

    // If currently logged in as this student, log out
    final currentSession = await getActiveSession();
    if (currentSession != null) {
      final removedId = removed?['id']?.toString() ?? '';
      final cleanRoll = _normalizeRoll(rollNo);
      if ((removedId.isNotEmpty && currentSession.id == removedId) ||
          (cleanRoll.isNotEmpty &&
              _normalizeRoll(currentSession.rollNo ?? '') == cleanRoll)) {
        await logout();
      }
    }

    if (_isSupabaseActive && removed != null) {
      try {
        final userId = removed['id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          final client = Supabase.instance.client;
          await client
              .from('users')
              .delete()
              .eq('id', UuidUtil.fromString(userId))
              .timeout(const Duration(seconds: 4));
        }
      } catch (e) {
        debugPrint('Supabase user delete skipped: $e');
      }
    }

    return true;
  }

  /// Get list of registered students (for Admin roster management)
  Future<List<Map<String, dynamic>>> getRegisteredStudents() async {
    await seedDefaultAccountsIfEmpty();
    final registry = await _loadRegistry();
    return registry.values.toList();
  }

  // ===================================================================
  // GOOGLE OAUTH & UPLOADER VERIFICATION REQUEST SYSTEM
  // ===================================================================

  /// Sign in with Google Account (with automatic Admin detection for designated admin emails)
  Future<AuthResult> signInWithGoogle({
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? 'Google User' : name.trim();
    final isAdmin = isAdminEmail(cleanEmail);

    final registry = await _loadRegistry();

    // Check if user already exists in registry by email, google_email or key
    Map<String, dynamic>? existingRecord;

    for (final entry in registry.entries) {
      final recEmail = (entry.value['email'] as String? ?? '').trim().toLowerCase();
      final recGoogleEmail = (entry.value['google_email'] as String? ?? '').trim().toLowerCase();
      final key = entry.key.toLowerCase();
      if (recEmail == cleanEmail ||
          recGoogleEmail == cleanEmail ||
          key == cleanEmail ||
          key == 'google-$cleanEmail') {
        existingRecord = entry.value;
        break;
      }
    }

    // Always check remote Supabase users table by email when connected so
    // an existing authoritative cloud row's UUID/credits aren't shadowed by a seeded local record.
    Map<String, dynamic>? remoteRecord;
    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('users')
            .select()
            .eq('email', cleanEmail)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (res != null) {
          remoteRecord = Map<String, dynamic>.from(res);
          existingRecord = existingRecord != null
              ? {...existingRecord, ...remoteRecord}
              : remoteRecord;
        }
      } catch (e) {
        debugPrint('Supabase remote lookup timed out or skipped: $e');
      }
    }

    final bool isNewUser = existingRecord == null;

    // Check existing uploader request for this Google email
    final requests = await getUploaderRequests();
    final userRequest = requests
        .where((r) => r.googleEmail.toLowerCase() == cleanEmail)
        .firstOrNull;

    bool canUpload = isAdmin || (userRequest != null && userRequest.isApproved) || (existingRecord?['can_upload'] as bool? ?? false);
    String uploadStatus = isAdmin
        ? 'approved'
        : (userRequest?.status ?? (existingRecord?['upload_request_status'] as String? ?? 'none'));
    String? rollNo = existingRecord?['roll_no'] as String? ?? userRequest?.rollNo;

    final userId = (remoteRecord?['id'] as String?)?.trim().isNotEmpty == true
        ? (remoteRecord!['id'] as String).trim()
        : (existingRecord?['id'] as String? ?? UuidUtil.generate());
    final resolvedName = (cleanName != 'Google User' && cleanName.isNotEmpty)
        ? cleanName
        : (existingRecord?['name'] as String? ?? 'Student');

    final user = UserModel(
      id: userId,
      name: resolvedName,
      email: cleanEmail,
      role: isAdmin ? 'admin' : (existingRecord?['role'] as String? ?? 'student'),
      credits: (existingRecord?['credits'] as num?)?.toInt() ?? (isAdmin ? 500 : 50),
      streakCount: (existingRecord?['streak_count'] as num?)?.toInt() ?? 1,
      isKzynovexVerified: isAdmin || (existingRecord?['is_kzynovex_verified'] as bool? ?? false),
      avatarUrl: avatarUrl ?? existingRecord?['avatar_url'] as String?,
      rollNo: rollNo ??
          (isAdmin
              ? (cleanEmail.contains('fanhacker')
                  ? 'ADMIN-FAN'
                  : (cleanEmail.contains('muzammil')
                      ? 'ADMIN-MUZ'
                      : 'ADMIN-KZY'))
              : null),
      isLoggedIn: true,
      canUpload: canUpload,
      uploadRequestStatus: uploadStatus,
      authProvider: 'google',
    );

    // Save/update registry
    final key = user.rollNo?.isNotEmpty == true ? user.rollNo! : 'GOOGLE-$cleanEmail';
    registry[key] = {
      ...user.toMap(),
      'google_email': cleanEmail,
      'last_login_at': DateTime.now().toIso8601String(),
    };
    await _saveRegistry(registry);
    await _saveActiveSession(user);

    if (isAdmin && user.rollNo != null) {
      await addAdminToWhitelist(user.rollNo!);
    }

    // Also upsert to remote Supabase if connected (guarded with timeout so it never hangs)
    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        await client.from('users').upsert({
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'role': user.role,
          'credits': user.credits,
          'streak_count': user.streakCount,
          'is_kzynovex_verified': user.isKzynovexVerified,
          'can_upload': user.canUpload,
        }).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Supabase remote user sync: $e');
      }
    }

    final welcomeMessage = isAdmin
        ? 'Welcome, Administrator ($cleanEmail)!'
        : isNewUser
            ? 'Account created! Welcome to Class Connect, ${user.name}!'
            : 'Welcome back, ${user.name}!';

    return AuthResult(
      success: true,
      message: welcomeMessage,
      user: user,
    );
  }

  /// Retrieve all Uploader / Contributor verification requests
  Future<List<UploaderRequestModel>> getUploaderRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUploaderRequests);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final items = list
            .map((e) => UploaderRequestModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        // Remove legacy demo requests
        items.removeWhere((r) => r.id == 'req-001' || r.id == 'req-002');
        items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        return items;
      }
    } catch (e) {
      debugPrint('Error loading uploader requests: $e');
    }
    return <UploaderRequestModel>[];
  }

  Future<void> _saveUploaderRequests(List<UploaderRequestModel> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = requests.map((r) => r.toMap()).toList();
      await prefs.setString(_keyUploaderRequests, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving uploader requests: $e');
    }
  }

  /// Submit Contributor/Upload Request
  /// STRICT RULE: Exactly ONE request allowed per Google Account!
  Future<AuthResult> submitUploaderRequest({
    required String userId,
    required String googleEmail,
    required String name,
    required String rollNo,
  }) async {
    final cleanEmail = googleEmail.trim().toLowerCase();
    final cleanRoll = _normalizeRoll(rollNo);
    final cleanName = name.trim();

    if (cleanEmail.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Google Account email is missing. Please sign in with Google.',
      );
    }
    if (cleanRoll.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Please enter your academic Roll Number (e.g. 23-SE-402).',
      );
    }
    if (cleanName.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Please enter your Full Name as registered with the university.',
      );
    }

    final requests = List<UploaderRequestModel>.from(await getUploaderRequests());

    // STRICT CHECK: Only ONE request per Google Account!
    final existingIndex = requests.indexWhere(
      (r) => r.googleEmail.toLowerCase() == cleanEmail,
    );

    if (existingIndex != -1) {
      final existing = requests[existingIndex];
      if (existing.isPending) {
        return AuthResult(
          success: false,
          message:
              'A verification request is already pending for Google account ($cleanEmail). Only one request is allowed per Google account.',
        );
      } else if (existing.isApproved) {
        return const AuthResult(
          success: false,
          message:
              'This Google account is already verified and approved for posting notes!',
        );
      } else {
        return AuthResult(
          success: false,
          message:
              'A verification request for $cleanEmail was already reviewed (${existing.status}). Only one request is allowed per Google account. Please contact an Admin for review.',
        );
      }
    }

    final newRequest = UploaderRequestModel(
      id: UuidUtil.generate(),
      userId: userId.isNotEmpty ? userId : UuidUtil.generate(),
      googleEmail: cleanEmail,
      name: cleanName,
      rollNo: cleanRoll,
      submittedAt: DateTime.now(),
      status: 'pending',
    );

    requests.insert(0, newRequest);
    await _saveUploaderRequests(requests);

    // Update active user session & registry
    final currentSession = await getActiveSession();
    if (currentSession != null) {
      final updatedUser = currentSession.copyWith(
        name: cleanName,
        rollNo: cleanRoll,
        uploadRequestStatus: 'pending',
        uploadRequestedAt: newRequest.submittedAt,
      );
      await _saveActiveSession(updatedUser);

      final registry = await _loadRegistry();
      for (final key in registry.keys) {
        if ((registry[key]!['email'] as String? ?? '').toLowerCase() == cleanEmail ||
            registry[key]!['id'] == userId) {
          registry[key]!['name'] = cleanName;
          registry[key]!['roll_no'] = cleanRoll;
          registry[key]!['upload_request_status'] = 'pending';
          registry[key]!['upload_requested_at'] = newRequest.submittedAt.toIso8601String();
          break;
        }
      }
      await _saveRegistry(registry);
    }

    return const AuthResult(
      success: true,
      message:
          'Verification request submitted successfully! Admin will verify your Roll No and authorize you to post materials.',
    );
  }

  /// Admin verifies and approves uploader request
  Future<bool> approveUploaderRequest(String requestId, {String? adminEmail}) async {
    final requests = await getUploaderRequests();
    final idx = requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = requests[idx];
    final updated = req.copyWith(
      status: 'approved',
      reviewedAt: DateTime.now(),
      reviewedBy: adminEmail ?? 'Admin',
    );
    requests[idx] = updated;
    await _saveUploaderRequests(requests);

    // Update user in registry & active session
    final registry = await _loadRegistry();
    for (final key in registry.keys) {
      if ((registry[key]!['email'] as String? ?? '').toLowerCase() == req.googleEmail.toLowerCase() ||
          registry[key]!['roll_no'] == req.rollNo) {
        registry[key]!['can_upload'] = true;
        registry[key]!['upload_request_status'] = 'approved';
        registry[key]!['name'] = req.name;
        registry[key]!['roll_no'] = req.rollNo;
        break;
      }
    }
    await _saveRegistry(registry);

    final session = await getActiveSession();
    if (session != null &&
        (session.email.toLowerCase() == req.googleEmail.toLowerCase() ||
            session.rollNo == req.rollNo)) {
      final updatedSession = session.copyWith(
        canUpload: true,
        uploadRequestStatus: 'approved',
        rollNo: req.rollNo,
        name: req.name,
      );
      await _saveActiveSession(updatedSession);
    }

    return true;
  }

  /// Admin rejects uploader request
  Future<bool> rejectUploaderRequest(String requestId, {String? reason, String? adminEmail}) async {
    final requests = await getUploaderRequests();
    final idx = requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = requests[idx];
    final updated = req.copyWith(
      status: 'rejected',
      rejectionReason: reason ?? 'Roll number verification could not be validated.',
      reviewedAt: DateTime.now(),
      reviewedBy: adminEmail ?? 'Admin',
    );
    requests[idx] = updated;
    await _saveUploaderRequests(requests);

    // Update user in registry & active session
    final registry = await _loadRegistry();
    for (final key in registry.keys) {
      if ((registry[key]!['email'] as String? ?? '').toLowerCase() == req.googleEmail.toLowerCase() ||
          registry[key]!['roll_no'] == req.rollNo) {
        registry[key]!['can_upload'] = false;
        registry[key]!['upload_request_status'] = 'rejected';
        break;
      }
    }
    await _saveRegistry(registry);

    final session = await getActiveSession();
    if (session != null &&
        (session.email.toLowerCase() == req.googleEmail.toLowerCase() ||
            session.rollNo == req.rollNo)) {
      final updatedSession = session.copyWith(
        canUpload: false,
        uploadRequestStatus: 'rejected',
      );
      await _saveActiveSession(updatedSession);
    }

    return true;
  }

  /// Deducts credits for Cosmetics Store unlocks via server-side RPC and
  /// stores [itemId] in `public.users.unlocked_cosmetics` so unlocks survive reinstalls.
  Future<void> spendCosmeticCredits(
    String userId,
    int cost, {
    String? itemId,
  }) async {
    if (cost <= 0 || !_isSupabaseActive) return;
    final client = Supabase.instance.client;
    try {
      await client.rpc('spend_cosmetic_credits', params: {
        'p_user_id': UuidUtil.fromString(userId),
        'p_cost': cost,
        'p_item_id': itemId,
      }).timeout(const Duration(seconds: 6));
      return;
    } catch (e) {
      debugPrint('spend_cosmetic_credits (3-arg) RPC skipped: $e');
    }
    try {
      await client.rpc('spend_cosmetic_credits', params: {
        'p_user_id': UuidUtil.fromString(userId),
        'p_cost': cost,
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('spend_cosmetic_credits (2-arg) RPC skipped, trying fallback: $e');
      await syncCreditsDelta(userId, -cost.clamp(1, 20));
    }
  }

  /// Fetches the authoritative user profile (credits, verified badge, role,
  /// upload permission, unlocked cosmetics) from Supabase and refreshes local session.
  Future<({UserModel? user, List<String> unlockedCosmetics})>
      fetchFreshProfileFromCloud(UserModel current) async {
    if (!_isSupabaseActive || !current.isLoggedIn) {
      return (user: null, unlockedCosmetics: const <String>[]);
    }
    try {
      final client = Supabase.instance.client;
      Map<String, dynamic>? row;
      try {
        final byId = await client
            .from('users')
            .select()
            .eq('id', UuidUtil.fromString(current.id))
            .limit(1)
            .timeout(const Duration(seconds: 5));
        if ((byId as List).isNotEmpty) {
          row = Map<String, dynamic>.from(byId.first as Map);
        }
      } catch (_) {}

      if (row == null && current.email.trim().isNotEmpty) {
        try {
          final byEmail = await client
              .from('users')
              .select()
              .eq('email', current.email.trim().toLowerCase())
              .limit(1)
              .timeout(const Duration(seconds: 5));
          if ((byEmail as List).isNotEmpty) {
            row = Map<String, dynamic>.from(byEmail.first as Map);
          }
        } catch (_) {}
      }

      if (row == null) {
        return (user: null, unlockedCosmetics: const <String>[]);
      }

      final remoteId = (row['id'] as String?)?.trim();
      final isDesignated = isAdminEmail(current.email);
      final remoteVerified = row['is_kzynovex_verified'] as bool?;
      final remoteCredits = (row['credits'] as num?)?.toInt();
      final remoteRole = row['role'] as String?;
      final remoteCanUpload = row['can_upload'] as bool?;
      final remoteRoll = row['roll_no'] as String?;
      final remoteName = row['name'] as String?;
      final remoteStreak = (row['streak_count'] as num?)?.toInt();

      final rawUnlocked = row['unlocked_cosmetics'];
      final unlockedList = rawUnlocked is List
          ? rawUnlocked.map((e) => e.toString()).toList()
          : const <String>[];

      final refreshed = current.copyWith(
        id: (remoteId != null && remoteId.isNotEmpty) ? remoteId : current.id,
        name: (remoteName != null && remoteName.trim().isNotEmpty)
            ? remoteName
            : current.name,
        rollNo: (remoteRoll != null && remoteRoll.trim().isNotEmpty)
            ? remoteRoll
            : current.rollNo,
        role: isDesignated ? 'admin' : (remoteRole ?? current.role),
        credits: remoteCredits ?? current.credits,
        streakCount: remoteStreak ?? current.streakCount,
        isKzynovexVerified: isDesignated ||
            current.isKzynovexVerified ||
            (remoteVerified ?? false),
        canUpload: isDesignated || (remoteCanUpload ?? current.canUpload),
      );

      final registry = await _loadRegistry();
      final key = _findRegistryKey(
        registry,
        rollNo: refreshed.rollNo,
        email: refreshed.email,
        userId: refreshed.id,
      );
      if (key != null && registry[key] != null) {
        registry[key]!['id'] = refreshed.id;
        registry[key]!['credits'] = refreshed.credits;
        registry[key]!['role'] = refreshed.role;
        registry[key]!['is_kzynovex_verified'] = refreshed.isKzynovexVerified;
        registry[key]!['can_upload'] = refreshed.canUpload;
        if (refreshed.rollNo != null && refreshed.rollNo!.isNotEmpty) {
          registry[key]!['roll_no'] = refreshed.rollNo;
        }
        await _saveRegistry(registry);
      }

      await _saveActiveSession(refreshed);
      return (user: refreshed, unlockedCosmetics: unlockedList);
    } catch (e) {
      debugPrint('fetchFreshProfileFromCloud skipped: $e');
      return (user: null, unlockedCosmetics: const <String>[]);
    }
  }

  /// Applies a bounty escrow or payout credit delta to local registry + active session,
  /// and attempts cloud sync when Supabase `resolve_bounty_payout` RPC is not yet deployed.
  Future<bool> applyBountyCreditsFallback({
    required String targetUserId,
    required int delta,
    String? targetRollNo,
    String? targetName,
  }) async {
    if (delta == 0) return true;
    final normTarget = UuidUtil.fromString(targetUserId);

    // 1. Update local registry so Admin Users list and local sessions stay accurate
    final registry = await _loadRegistry();
    String? key = _findRegistryKey(
      registry,
      rollNo: targetRollNo,
      userId: targetUserId,
    );
    key ??= _findRegistryKey(registry, userId: normTarget);
    if (key == null && targetName != null && targetName.trim().isNotEmpty) {
      final needle = targetName.trim().toLowerCase();
      for (final entry in registry.entries) {
        final recName = (entry.value['name'] as String? ?? '').trim().toLowerCase();
        if (recName == needle) {
          key = entry.key;
          break;
        }
      }
    }

    if (key != null && registry[key] != null) {
      final currentCredits = (registry[key]!['credits'] as num?)?.toInt() ?? 50;
      registry[key]!['credits'] = (currentCredits + delta).clamp(0, 999999);
      await _saveRegistry(registry);
    }

    // 2. Keep active session updated if it belongs to targetUserId
    final session = await getActiveSession();
    if (session != null && UuidUtil.fromString(session.id) == normTarget) {
      final nextCredits = (session.credits + delta).clamp(0, 999999);
      await _saveActiveSession(session.copyWith(credits: nextCredits));
    }

    // 3. Fallback cloud update if Supabase is configured (in bounded RPC chunks)
    if (_isSupabaseActive && targetUserId.trim().isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        int remaining = delta.abs();
        final stepMax = delta > 0 ? 50 : 20;
        final sign = delta > 0 ? 1 : -1;
        while (remaining > 0) {
          final chunk = (remaining > stepMax ? stepMax : remaining) * sign;
          await client.rpc('adjust_resource_credits', params: {
            'p_user_id': normTarget,
            'p_delta': chunk,
          }).timeout(const Duration(seconds: 6));
          remaining -= chunk.abs();
        }
        return true;
      } catch (e) {
        debugPrint('applyBountyCreditsFallback RPC skipped: $e');
        if (delta > 0) {
          try {
            final client = Supabase.instance.client;
            final rows = await client
                .from('users')
                .select('id, credits')
                .eq('id', normTarget)
                .limit(1)
                .timeout(const Duration(seconds: 4));
            if ((rows as List).isNotEmpty) {
              final cur =
                  ((rows.first as Map)['credits'] as num?)?.toInt() ?? 0;
              await client
                  .from('users')
                  .update({'credits': cur + delta})
                  .eq('id', normTarget)
                  .timeout(const Duration(seconds: 4));
            }
          } catch (_) {}
        }
      }
    }
    return key != null;
  }

  /// Claims quiz credits atomically on Supabase per `(user_id, quiz_id)` so
  /// reinstalling or clearing storage cannot re-farm credits from the same quiz.
  /// Returns server-awarded delta, or null when offline / unmigrated.
  Future<int?> claimQuizCreditsRemote({
    required String userId,
    required String quizId,
    required int score,
    required int totalQuestions,
  }) async {
    if (!_isSupabaseActive || quizId.trim().isEmpty || totalQuestions <= 0) {
      return null;
    }
    try {
      final res = await Supabase.instance.client.rpc(
        'claim_quiz_credits',
        params: {
          'p_user_id': UuidUtil.fromString(userId),
          'p_quiz_id': quizId.trim(),
          'p_score': score,
          'p_total_questions': totalQuestions,
        },
      ).timeout(const Duration(seconds: 6));
      if (res is num) return res.toInt();
    } catch (e) {
      debugPrint('claim_quiz_credits RPC fallback: $e');
    }
    return null;
  }

  // ===================================================================
  // VERIFIED STUDENT BADGE REQUESTS (Anti-Fake Account Protection)
  // ===================================================================

  Future<List<StudentVerificationRequestModel>>
      getStudentVerificationRequests() async {
    final mapById = <String, StudentVerificationRequestModel>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyStudentVerifications);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          final req = StudentVerificationRequestModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          );
          if (req.id.isNotEmpty) mapById[req.id] = req;
        }
      }
    } catch (e) {
      debugPrint('Error loading local student verification requests: $e');
    }

    if (_isSupabaseActive) {
      try {
        final client = Supabase.instance.client;
        bool fetchedTable = false;
        try {
          final rows = await client
              .from('student_verification_requests')
              .select()
              .timeout(const Duration(seconds: 5));
          for (final raw in (rows as List)) {
            if (raw is Map<String, dynamic>) {
              final req = StudentVerificationRequestModel.fromMap(raw);
              if (req.id.isNotEmpty) mapById[req.id] = req;
            }
          }
          fetchedTable = true;
        } catch (_) {}

        if (!fetchedTable) {
          final rows = await client
              .from('resources')
              .select()
              .like('url', '${StudentVerificationRequestModel.resourceUrlPrefix}%')
              .timeout(const Duration(seconds: 5));
          for (final raw in (rows as List)) {
            if (raw is Map<String, dynamic>) {
              final req =
                  StudentVerificationRequestModel.tryFromResourceMap(raw);
              if (req != null && req.id.isNotEmpty) mapById[req.id] = req;
            }
          }
        }
      } catch (e) {
        debugPrint('Supabase student verification fetch skipped: $e');
      }
    }

    final items = mapById.values.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    await _saveStudentVerificationRequests(items);
    return items;
  }

  Future<void> _saveStudentVerificationRequests(
    List<StudentVerificationRequestModel> requests,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyStudentVerifications,
        jsonEncode(requests.map((r) => r.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving student verification requests: $e');
    }
  }

  Future<void> _syncStudentVerificationRequestRemote(
    StudentVerificationRequestModel req,
  ) async {
    if (!_isSupabaseActive) return;
    final client = Supabase.instance.client;
    try {
      await client.from('student_verification_requests').upsert({
        'id': UuidUtil.fromString(req.id),
        'user_id': UuidUtil.fromString(req.userId),
        'email': req.email,
        'name': req.name,
        'roll_no': req.rollNo,
        'status': req.status,
        'rejection_reason': req.rejectionReason,
        'reviewed_by': req.reviewedBy,
        'reviewed_at': req.reviewedAt?.toIso8601String(),
        'submitted_at': req.submittedAt.toIso8601String(),
      }).timeout(const Duration(seconds: 6));
      return;
    } catch (_) {}

    try {
      final payload = req.toResourcePayload();
      payload['id'] = UuidUtil.fromString(req.id);
      payload.remove('uploader_id');
      await client
          .from('resources')
          .upsert(payload)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Fallback student verification resource sync skipped: $e');
    }
  }

  Future<AuthResult> submitStudentVerificationRequest({
    required String userId,
    required String email,
    required String name,
    required String rollNo,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanRoll = _normalizeRoll(rollNo);
    final cleanName = name.trim();

    if (cleanName.length < 2) {
      return const AuthResult(
        success: false,
        message: 'Please enter your full university name.',
      );
    }
    if (cleanRoll.length < 3) {
      return const AuthResult(
        success: false,
        message: 'Please enter a valid academic Roll Number (e.g. 23-SE-402).',
      );
    }

    final requests = List<StudentVerificationRequestModel>.from(
        await getStudentVerificationRequests());
    final normUid = UuidUtil.fromString(userId);
    final existingIdx = requests.indexWhere(
      (r) =>
          (r.userId.isNotEmpty && UuidUtil.fromString(r.userId) == normUid) ||
          (cleanEmail.isNotEmpty && r.email.toLowerCase() == cleanEmail),
    );

    if (existingIdx != -1) {
      final existing = requests[existingIdx];
      if (existing.isPending) {
        return const AuthResult(
          success: false,
          message:
              'Your Student Badge verification request is already pending admin review.',
        );
      }
      if (existing.isApproved) {
        return const AuthResult(
          success: false,
          message: 'Your account already has the Verified Student Badge!',
        );
      }
      // Replace previously rejected request so student can resubmit corrected info
      requests.removeAt(existingIdx);
    }

    final newReq = StudentVerificationRequestModel(
      id: UuidUtil.generate(),
      userId: userId.isNotEmpty ? UuidUtil.fromString(userId) : UuidUtil.generate(),
      email: cleanEmail.isNotEmpty ? cleanEmail : '$cleanRoll@campus.edu',
      name: cleanName,
      rollNo: cleanRoll,
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    requests.insert(0, newReq);
    await _saveStudentVerificationRequests(requests);
    await _syncStudentVerificationRequestRemote(newReq);

    return const AuthResult(
      success: true,
      message:
          'Verification request submitted! An admin will verify your Name & Roll No.',
    );
  }

  Future<bool> approveStudentVerificationRequest(
    String requestId, {
    required String adminId,
    String? adminEmail,
  }) async {
    final requests = List<StudentVerificationRequestModel>.from(
        await getStudentVerificationRequests());
    final idx = requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = requests[idx];
    final updated = req.copyWith(
      status: 'approved',
      reviewedAt: DateTime.now(),
      reviewedBy: adminEmail ?? 'Admin',
    );
    requests[idx] = updated;
    await _saveStudentVerificationRequests(requests);

    // Update local registry & active session if matching
    final registry = await _loadRegistry();
    final regKey = _findRegistryKey(
      registry,
      rollNo: req.rollNo,
      email: req.email,
      userId: req.userId,
    );
    if (regKey != null && registry[regKey] != null) {
      registry[regKey]!['is_kzynovex_verified'] = true;
      registry[regKey]!['name'] = req.name;
      registry[regKey]!['roll_no'] = req.rollNo;
      await _saveRegistry(registry);
    }

    final session = await getActiveSession();
    if (session != null &&
        (UuidUtil.fromString(session.id) == UuidUtil.fromString(req.userId) ||
            (req.email.isNotEmpty &&
                session.email.toLowerCase() == req.email.toLowerCase()))) {
      await _saveActiveSession(
        session.copyWith(
          isKzynovexVerified: true,
          name: req.name,
          rollNo: req.rollNo,
        ),
      );
    }

    bool usedRpc = false;
    if (_isSupabaseActive) {
      try {
        await Supabase.instance.client.rpc(
          'admin_review_student_verification',
          params: {
            'p_request_id': UuidUtil.fromString(req.id),
            'p_admin_id': UuidUtil.fromString(adminId),
            'p_approve': true,
            'p_reason': null,
          },
        ).timeout(const Duration(seconds: 6));
        usedRpc = true;
      } catch (e) {
        debugPrint('admin_review_student_verification RPC fallback: $e');
      }
    }
    if (!usedRpc) {
      await _syncStudentVerificationRequestRemote(updated);
      if (regKey != null && registry[regKey] != null) {
        final target = UserModel.fromMap(registry[regKey]!);
        await adminUpdateUser(target);
      }
    }
    return true;
  }

  Future<bool> rejectStudentVerificationRequest(
    String requestId, {
    required String adminId,
    String? reason,
    String? adminEmail,
  }) async {
    final requests = List<StudentVerificationRequestModel>.from(
        await getStudentVerificationRequests());
    final idx = requests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = requests[idx];
    final cleanReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : 'Name and Roll Number could not be matched with class roster.';
    final updated = req.copyWith(
      status: 'rejected',
      rejectionReason: cleanReason,
      reviewedAt: DateTime.now(),
      reviewedBy: adminEmail ?? 'Admin',
    );
    requests[idx] = updated;
    await _saveStudentVerificationRequests(requests);

    bool usedRpc = false;
    if (_isSupabaseActive) {
      try {
        await Supabase.instance.client.rpc(
          'admin_review_student_verification',
          params: {
            'p_request_id': UuidUtil.fromString(req.id),
            'p_admin_id': UuidUtil.fromString(adminId),
            'p_approve': false,
            'p_reason': cleanReason,
          },
        ).timeout(const Duration(seconds: 6));
        usedRpc = true;
      } catch (e) {
        debugPrint('admin_review_student_verification reject fallback: $e');
      }
    }
    if (!usedRpc) {
      await _syncStudentVerificationRequestRemote(updated);
    }
    return true;
  }
}
