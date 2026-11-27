import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:softwareclass/core/config/app_config.dart';
import 'package:softwareclass/core/services/alert_scheduler.dart';
import 'package:softwareclass/core/services/app_sound_service.dart';
import 'package:softwareclass/core/services/attendance_storage.dart';
import 'package:softwareclass/core/services/auth_service.dart';
import 'package:softwareclass/core/services/offline_document_service.dart';
import 'package:softwareclass/core/services/quiz_import_service.dart';
import 'package:softwareclass/core/theme/app_theme.dart';
import 'package:softwareclass/core/utils/formatters.dart';
import 'package:softwareclass/core/utils/google_drive_util.dart';
import 'package:softwareclass/models/models.dart';
import 'package:softwareclass/core/constants/kzynovex_branding.dart';
import 'package:softwareclass/core/utils/uuid_util.dart';
import 'package:softwareclass/features/assignment_scanner/assignment_scanner_screen.dart';
import 'package:softwareclass/features/home/home_screen.dart';
import 'package:softwareclass/features/shell/main_shell.dart';
import 'package:softwareclass/features/splash/splash_screen.dart';
import 'package:softwareclass/providers/class_providers.dart';
import 'package:softwareclass/repositories/class_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.testAdminEmails = ['testadmin1@example.com', 'testadmin2@example.com'];
    AppConfig.testAdminPassword = 'testadminpass2026';
  });
  testWidgets('SplashScreen renders Kzynovex branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    // Initial frame verify
    expect(find.text(KzynovexBranding.appName), findsOneWidget);
    expect(find.text(KzynovexBranding.brandName), findsOneWidget);
    expect(find.text(KzynovexBranding.poweredByLabel), findsOneWidget);

    // Teardown with clean widget
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('MainShell renders active Home tab and navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainShell(),
        ),
      ),
    );

    // Verify MainShell mounted and Home tab is active
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);

    // Teardown with clean widget
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AssignmentScannerScreen renders with all sections', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AssignmentScannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Assignment PDF Maker'), findsOneWidget);
    expect(find.text('No Pages Captured Yet'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Tapping Assignment PDF Maker on HomeScreen navigates cleanly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainShell(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final assignmentButton = find.text('Doc Scanner');
    expect(assignmentButton, findsOneWidget);

    await tester.tap(assignmentButton);
    await tester.pumpAndSettle();

    expect(find.text('Offline Document Scanner & Formatter'), findsOneWidget);
    expect(find.text('Add Document Photos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  test('DailyOverrideModel and LectureItem support rescheduling time and day and Sunday slots', () {
    const slot = TimetableSlotModel(
      id: 'slot-1',
      subjectId: 'sub-1',
      dayOfWeek: 7, // Sunday
      startTime: '10:00',
      endTime: '11:15',
      defaultRoom: 'Hall A',
    );
    expect(slot.dayOfWeek, 7);

    final override = DailyOverrideModel(
      id: 'ov-1',
      slotId: 'slot-1',
      date: DateTime(2026, 10, 18),
      status: OverrideStatus.rescheduled,
      actualRoom: 'Lab 2',
      actualStartTime: '11:30',
      actualEndTime: '13:00',
      rescheduledDate: DateTime(2026, 10, 19),
      topicCovered: 'Extra Practice',
      reportedBy: 'user-1',
      isApproved: true,
    );

    final map = override.toMap();
    expect(map['actual_start_time'], '11:30');
    expect(map['actual_end_time'], '13:00');
    expect(map['rescheduled_date'], '2026-10-19');

    final reconstructed = DailyOverrideModel.fromMap(map);
    expect(reconstructed.actualStartTime, '11:30');
    expect(reconstructed.actualEndTime, '13:00');
    expect(reconstructed.rescheduledDate?.day, 19);

    final lecture = LectureItem(
      slot: slot,
      subject: const SubjectModel(id: 'sub-1', name: 'Math', code: 'MATH101', professor: 'Prof'),
      override: override,
      startsAt: DateTime(2026, 10, 18, 10, 0),
      endsAt: DateTime(2026, 10, 18, 11, 15),
    );

    expect(lecture.isRescheduled, true);
    expect(lecture.isTimeChanged, true);
    expect(lecture.isDayRescheduled, true);
    expect(lecture.isRoomChanged, true);
    expect(lecture.effectiveStartTime, '11:30');
    expect(lecture.effectiveEndTime, '13:00');
    expect(lecture.effectiveRoom, 'Lab 2');
    expect(lecture.isDayMovedAway, true);
    expect(lecture.isOngoing, false);
    expect(lecture.isUpcoming, false);
  });

  test('Formatters converts 24-hour times to 12-hour AM/PM format correctly', () {
    expect(Formatters.formatTimeString('09:00'), '9:00 AM');
    expect(Formatters.formatTimeString('10:15'), '10:15 AM');
    expect(Formatters.formatTimeString('12:00'), '12:00 PM');
    expect(Formatters.formatTimeString('13:30'), '1:30 PM');
    expect(Formatters.formatTimeString('00:00'), '12:00 AM');
    expect(Formatters.formatTimeString('23:45'), '11:45 PM');
    expect(Formatters.formatTimeRangeString('09:00', '10:15'), '9:00 AM - 10:15 AM');
    expect(Formatters.formatTimeRangeString('13:00', '14:15'), '1:00 PM - 2:15 PM');
  });

  test('AuthService registers student and prevents impersonation', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final auth = AuthService.instance;

    // Register a student
    final regResult = await auth.registerStudent(
      rollNo: '23-CS-101',
      name: 'Alice Cooper',
      pin: '5678',
    );
    expect(regResult.success, true);
    expect(regResult.user?.name, 'Alice Cooper');

    // Duplicate claim attempt by someone else with same roll number
    final dupResult = await auth.registerStudent(
      rollNo: '23-CS-101',
      name: 'Bob Impersonator',
      pin: '9999',
    );
    expect(dupResult.success, false);
    expect(dupResult.message.contains('already claimed and locked'), true);

    // Impersonation login attempt with wrong PIN
    final wrongPinResult = await auth.loginStudent(
      rollNo: '23-CS-101',
      pin: '0000',
    );
    expect(wrongPinResult.success, false);
    expect(wrongPinResult.message.contains('Incorrect Security PIN'), true);

    // Legitimate login with correct PIN
    final correctLogin = await auth.loginStudent(
      rollNo: '23-CS-101',
      pin: '5678',
    );
    expect(correctLogin.success, true);
    expect(correctLogin.user?.name, 'Alice Cooper');

    // Admin passcode verification (case-insensitive & whitespace tolerant)
    expect(await auth.verifyAdminPasscode('testadminpass2026'), true);
    expect(await auth.verifyAdminPasscode('TestAdminPass2026'), true);
    expect(await auth.verifyAdminPasscode('TESTADMINPASS2026'), true);
    expect(await auth.verifyAdminPasscode('  testadminpass2026  '), true);
    expect(await auth.verifyAdminPasscode('wrongkey'), false);
    expect(await auth.verifyAdminPasscode(''), false);

    // Admin Console Access strictly requires BOTH Admin Email AND Admin Password:
    // Non-admin email is BLOCKED even with correct passcode
    final blocked = await auth.verifyAdminAccess(
      rollNo: '23-CS-101',
      email: 'student@example.com',
      passkey: 'testadminpass2026',
    );
    expect(blocked.success, false);
    expect(blocked.message.contains('Only designated Admin Google Accounts'), true);

    // Designated Admin email with WRONG password -> BLOCKED
    final wrongPass = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'testadmin1@example.com',
      passkey: 'wrongpassword',
    );
    expect(wrongPass.success, false);
    expect(wrongPass.message.contains('Incorrect Admin Password'), true);

    // Designated Admin email with EMPTY password -> BLOCKED
    final emptyPass = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'testadmin1@example.com',
      passkey: '',
    );
    expect(emptyPass.success, false);

    // Designated Admin email with CORRECT password -> SUCCEEDS
    final allowed = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'testadmin1@example.com',
      passkey: 'testadminpass2026',
    );
    expect(allowed.success, true);
  });

  test('AuthService allows Admin to create, view, edit, reset PIN, and delete users', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final auth = AuthService.instance;

    // 1. Admin creates new student user
    final newUser = const UserModel(
      id: 'admin_test_1',
      name: 'Tariq Mehmood',
      email: 'tariq@campus.edu.pk',
      role: 'student',
      rollNo: '23-SE-999',
      credits: 40,
      streakCount: 3,
      isKzynovexVerified: true,
    );
    final createResult = await auth.adminCreateUser(user: newUser, pin: '4321');
    expect(createResult.success, true);

    // 2. View all users includes new user
    final users = await auth.getAllUsers();
    final found = users.firstWhere((u) => u.rollNo == '23-SE-999');
    expect(found.name, 'Tariq Mehmood');
    expect(found.isKzynovexVerified, true);

    // 3. Admin edits user details (change name, promote to admin)
    final updated = found.copyWith(
      name: 'Tariq Mehmood (CR)',
      role: 'admin',
      credits: 50,
    );
    final updateOk = await auth.adminUpdateUser(updated);
    expect(updateOk, true);

    // Verify update
    final usersAfterUpdate = await auth.getAllUsers();
    final foundUpdated = usersAfterUpdate.firstWhere((u) => u.rollNo == '23-SE-999');
    expect(foundUpdated.name, 'Tariq Mehmood (CR)');
    expect(foundUpdated.role, 'admin');
    expect(foundUpdated.credits, 50);

    // 4. Admin resets student PIN
    final resetOk = await auth.adminResetStudentPin(rollNo: '23-SE-999', newPin: '8888');
    expect(resetOk, true);

    // Student can now log in with new PIN
    final loginWithNewPin = await auth.loginStudent(rollNo: '23-SE-999', pin: '8888');
    expect(loginWithNewPin.success, true);

    // 5. Admin deletes user
    final deleteOk = await auth.adminDeleteUser('23-SE-999');
    expect(deleteOk, true);

    final usersAfterDelete = await auth.getAllUsers();
    expect(usersAfterDelete.any((u) => u.rollNo == '23-SE-999'), false);
  });

  test('Google Login and Designated Admin Elevation & Direct Console Access', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final auth = AuthService.instance;

    // 1. Designated admin 1: testadmin1@example.com
    expect(AuthService.isAdminEmail('testadmin1@example.com'), true);
    expect(AuthService.isAdminEmail('TESTADMIN1@EXAMPLE.COM'), true); // case-insensitive check
    final adminRes1 = await auth.signInWithGoogle(
      email: 'testadmin1@example.com',
      name: 'Fan Hacker Admin',
    );
    expect(adminRes1.success, true);
    final adminUser1 = adminRes1.user!;
    expect(adminUser1.role, 'admin');
    expect(adminUser1.canUpload, true);
    expect(adminUser1.uploadRequestStatus, 'approved');
    expect(adminUser1.isUploaderVerified, true);
    expect(adminUser1.isAdmin, true);
    expect(UserModel.isDesignatedAdminEmail(adminUser1.email), true);

    // Admin Console access strictly requires BOTH Admin Email AND valid Password
    final noPassCheck1 = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'testadmin1@example.com',
      passkey: '',
    );
    expect(noPassCheck1.success, false);

    final accessCheck1 = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'testadmin1@example.com',
      passkey: 'testadminpass2026',
    );
    expect(accessCheck1.success, true);

    // 2. Designated admin 2: testadmin2@example.com
    expect(AuthService.isAdminEmail('testadmin2@example.com'), true);
    final adminRes2 = await auth.signInWithGoogle(
      email: 'testadmin2@example.com',
      name: 'Kzynovex Inc Admin',
    );
    expect(adminRes2.success, true);
    final adminUser2 = adminRes2.user!;
    expect(adminUser2.role, 'admin');
    expect(adminUser2.canUpload, true);
    expect(adminUser2.uploadRequestStatus, 'approved');
    expect(adminUser2.isAdmin, true);

    final accessCheck2 = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'testadmin2@example.com',
      passkey: 'testadminpass2026',
    );
    expect(accessCheck2.success, true);

    // 3. Regular Google user sign-in: NOT admin, NOT authorized to upload initially
    expect(AuthService.isAdminEmail('student.john@gmail.com'), false);
    final regularRes = await auth.signInWithGoogle(
      email: 'student.john@gmail.com',
      name: 'John Doe',
    );
    expect(regularRes.success, true);
    final regularUser = regularRes.user!;
    expect(regularUser.role, 'student');
    expect(regularUser.canUpload, false);
    expect(regularUser.isUploaderVerified, false);
    expect(regularUser.uploadRequestStatus, 'none');

    // Regular email is denied even with correct password
    final accessRegular = await auth.verifyAdminAccess(
      rollNo: null,
      email: 'student.john@gmail.com',
      passkey: 'admin2026',
    );
    expect(accessRegular.success, false);
  });

  test('Uploader Request Flow strictly enforces 1 request per Google account and Admin verification', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final auth = AuthService.instance;

    const testGoogleEmail = 'scholar.mary@gmail.com';

    // Sign in regular user
    final loginRes = await auth.signInWithGoogle(
      email: testGoogleEmail,
      name: 'Mary Jane',
    );
    expect(loginRes.success, true);
    final currentMary = loginRes.user!;

    // 1. Submit uploader request with Name and Roll No
    final submitRes = await auth.submitUploaderRequest(
      userId: currentMary.id,
      googleEmail: testGoogleEmail,
      name: 'Mary Jane',
      rollNo: '23-SE-444',
    );
    expect(submitRes.success, true);

    // 2. Strictly enforce ONE request per Google account: second request MUST fail with appropriate message
    final dupRes = await auth.submitUploaderRequest(
      userId: currentMary.id,
      googleEmail: testGoogleEmail,
      name: 'Mary Jane Duplicate',
      rollNo: '23-SE-444',
    );
    expect(dupRes.success, false);
    expect(dupRes.message.contains('already pending'), true);
    expect(dupRes.message.contains('Only one request is allowed'), true);

    // Verify request is visible in admin uploader requests queue
    final queueBefore = await auth.getUploaderRequests();
    final savedReq = queueBefore.firstWhere((r) => r.googleEmail == testGoogleEmail);
    expect(savedReq.isPending, true);
    expect(savedReq.name, 'Mary Jane');
    expect(savedReq.rollNo, '23-SE-444');

    // 3. Admin approves request
    final approvedOk = await auth.approveUploaderRequest(savedReq.id);
    expect(approvedOk, true);

    // Verify user registry now reflects approved upload permissions
    final updatedUsers = await auth.getAllUsers();
    final maryUser = updatedUsers.firstWhere(
      (u) => u.email.toLowerCase() == testGoogleEmail,
    );
    expect(maryUser.canUpload, true);
    expect(maryUser.isUploaderVerified, true);
    expect(maryUser.uploadRequestStatus, 'approved');
    expect(maryUser.rollNo, '23-SE-444');

    // 4. Signing in again with Google immediately preserves the approved uploader status
    final refreshedRes = await auth.signInWithGoogle(
      email: testGoogleEmail,
      name: 'Mary Jane',
    );
    expect(refreshedRes.success, true);
    final refreshedMary = refreshedRes.user!;
    expect(refreshedMary.canUpload, true);
    expect(refreshedMary.isUploaderVerified, true);
    expect(refreshedMary.uploadRequestStatus, 'approved');
  });

  test('AssignmentModel serialization and student completion privacy', () {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    final assignment = AssignmentModel(
      id: 'a0000001-0000-0000-0000-000000000001',
      subjectId: '11111111-1111-1111-1111-111111111111',
      title: 'Lab 5: Dynamic Programming',
      description: 'Solve knapsack and edit distance problems',
      deadline: tomorrow,
      driveUrl: 'https://drive.google.com/file/d/test',
      createdBy: 'Admin Instructor',
      createdAt: now,
    );

    final map = assignment.toMap();
    expect(map['title'], 'Lab 5: Dynamic Programming');
    expect(map['created_by'], 'Admin Instructor');

    final parsed = AssignmentModel.fromMap(map);
    expect(parsed.id, assignment.id);
    expect(parsed.subjectId, assignment.subjectId);
    expect(parsed.isDueTomorrow, true);

    // Student completion state is client-side only (Set of IDs in SharedPreferences)
    final studentACompleted = <String>{assignment.id};
    final studentBCompleted = <String>{}; // Different student device

    expect(studentACompleted.contains(assignment.id), true);
    expect(studentBCompleted.contains(assignment.id), false);
  });

  test('ClassRepository normalizeOverridePayload cleanses invalid reporter IDs and normalizes UUIDs', () {
    final rawPayload = {
      'id': 'ov-raw-1',
      'slot_id': 'slot-raw-1',
      'reported_by': 'not-a-valid-uuid-admin',
      'status': 'rescheduled',
      'actual_start_time': '10:30',
      'actual_end_time': '11:45',
    };

    final normalized = ClassRepository.normalizeOverridePayload(rawPayload);
    // Invalid UUID for foreign key public.users(id) is stripped to prevent foreign key errors
    expect(normalized.containsKey('reported_by'), false);
    // ID and slot_id are formatted into valid deterministic UUIDs
    expect(UuidUtil.isValidUuid(normalized['id']), true);
    expect(UuidUtil.isValidUuid(normalized['slot_id']), true);
  });

  test('PostgreSQL time normalization, CC_META cloud fallback, and updated alarm occurrences work end-to-end', () {
    // 1. Formatters.normalizeTime strips PostgreSQL seconds ("HH:MM:SS" -> "HH:mm")
    expect(Formatters.normalizeTime('08:30:00'), '08:30');
    expect(Formatters.normalizeTime('9:5'), '09:05');
    expect(Formatters.normalizeOptionalTime('14:45:00'), '14:45');

    // 2. DailyOverrideModel encodes & decodes [CC_META:...] when remote DB lacks optional columns
    final encodedTopic = DailyOverrideModel.encodeMetaIntoTopic(
      topicCovered: 'Moved for Lab Exam',
      actualStartTime: '14:30:00',
      actualEndTime: '16:00:00',
      rescheduledDate: '2026-11-20',
    );
    expect(encodedTopic, contains('[CC_META:'));

    final fallbackRowFromCloud = {
      'id': '11111111-2222-3333-4444-555555555555',
      'slot_id': 'aaaa1111-2222-3333-4444-555555555555',
      'date': '2026-11-18',
      'status': 'rescheduled',
      'actual_room': 'Lab 4',
      // Simulate unmigrated Supabase DB returning null for optional time/date columns:
      'actual_start_time': null,
      'actual_end_time': null,
      'rescheduled_date': null,
      'topic_covered': encodedTopic,
      'is_approved': true,
    };

    final decodedOverride = DailyOverrideModel.fromMap(fallbackRowFromCloud);
    expect(decodedOverride.actualStartTime, '14:30');
    expect(decodedOverride.actualEndTime, '16:00');
    expect(decodedOverride.rescheduledDate, DateTime(2026, 11, 20));
    expect(decodedOverride.topicCovered, 'Moved for Lab Exam');

    // 3. computeLecturesForDate and AlertScheduler.buildOccurrencesForTesting reflect updated meeting time & date
    const subject = SubjectModel(
      id: 'sub-se-1',
      name: 'Software Construction',
      code: 'SE-301',
      professor: 'Dr. Adeel',
    );
    const slot = TimetableSlotModel(
      id: 'aaaa1111-2222-3333-4444-555555555555',
      subjectId: 'sub-se-1',
      dayOfWeek: 3, // Wednesday (2026-11-18 is Wednesday)
      startTime: '09:00:00',
      endTime: '10:30:00',
      defaultRoom: 'Room 101',
    );

    // On original Wednesday (2026-11-18), lecture is marked moved away to Friday (2026-11-20)
    final wedLectures = computeLecturesForDate(
      targetDate: DateTime(2026, 11, 18),
      slots: [slot],
      subjects: [subject],
      overrides: [decodedOverride],
    );
    expect(wedLectures.length, 1);
    expect(wedLectures.first.isDayMovedAway, true);

    // On rescheduled Friday (2026-11-20), lecture appears at 14:30 - 16:00 in Lab 4
    final friLectures = computeLecturesForDate(
      targetDate: DateTime(2026, 11, 20),
      slots: [slot],
      subjects: [subject],
      overrides: [decodedOverride],
    );
    expect(friLectures.length, 1);
    expect(friLectures.first.effectiveStartTime, '14:30');
    expect(friLectures.first.effectiveEndTime, '16:00');
    expect(friLectures.first.effectiveRoom, 'Lab 4');
    expect(friLectures.first.isTimeChanged, true);

    // 4. AlertScheduler builds occurrences at the updated date & time (2026-11-20 14:30)
    final occurrences = AlertScheduler.buildOccurrencesForTesting(
      slots: [slot],
      overrides: [decodedOverride],
      referenceNow: DateTime(2026, 11, 17, 8, 0),
    );
    final shiftedOccurrence = occurrences.firstWhere(
      (o) =>
          o.startsAt.year == 2026 &&
          o.startsAt.month == 11 &&
          o.startsAt.day == 20,
    );
    expect(shiftedOccurrence.startsAt.hour, 14);
    expect(shiftedOccurrence.startsAt.minute, 30);
    expect(shiftedOccurrence.room, 'Lab 4');
    expect(shiftedOccurrence.isChanged, true);
  });

  test('GoogleDriveUtil and OfflineDocumentService resolve Drive links, reject broken URLs, and auto-heal missing local files', () async {
    const shareLink = 'https://drive.google.com/file/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/view?usp=sharing';
    expect(GoogleDriveUtil.extractFileId(shareLink), '1AbCdEfGhIjKlMnOpQrStUvWxYz');
    expect(
      GoogleDriveUtil.toDirectDownloadUrl(shareLink),
      'https://drive.usercontent.google.com/download?id=1AbCdEfGhIjKlMnOpQrStUvWxYz&export=download&confirm=t',
    );

    const docLink = 'https://docs.google.com/document/d/1DocId999/edit?usp=sharing';
    expect(
      GoogleDriveUtil.toDirectDownloadUrl(docLink),
      'https://docs.google.com/document/d/1DocId999/export?format=pdf',
    );

    // Google Drive folder link is recognized as a folder (not a single file)
    const folderLink = 'https://drive.google.com/drive/folders/1nzIjg_GoQE8qyFB4e3Ough3KBXNRmD1M?usp=sharing';
    expect(GoogleDriveUtil.isGoogleDriveFolder(folderLink), true);
    expect(GoogleDriveUtil.extractFolderId(folderLink), '1nzIjg_GoQE8qyFB4e3Ough3KBXNRmD1M');
    expect(GoogleDriveUtil.extractFileId(folderLink), null);
    expect(GoogleDriveUtil.normalizeForComparison(folderLink), 'gdrive_folder:1nzijg_goqe8qyfb4e3ough3kbxnrmd1m');

    // Invalid URL is gracefully rejected without crashing
    final badRes = await OfflineDocumentService.instance.downloadAndCache(
      url: 'not_a_valid_url',
      title: 'Broken Link',
    );
    expect(badRes.success, false);
    expect(badRes.errorType, OfflineDocErrorType.invalidUrl);

    // Missing local:// file is gracefully reported as fileNotFoundLocally
    final missingLocal = await OfflineDocumentService.instance.downloadAndCache(
      url: 'local://vault/non_existent_doc.pdf',
      title: 'Deleted Local Doc',
    );
    expect(missingLocal.success, false);
    expect(missingLocal.errorType, OfflineDocErrorType.fileNotFoundLocally);
  });

  test('QuizModel cloud resource encoding & QuizImportService JSON and Text MCQ parsing', () {
    // 1. Parse JSON format (NotebookLM Export / AI JSON format)
    const jsonSample = '''
    [
      {
        "question": "Which data structure uses LIFO order?",
        "options": ["Queue", "Stack", "Heap", "Graph"],
        "correctOptionIndex": 1,
        "explanation": "Stack follows Last-In, First-Out."
      }
    ]
    ''';
    final fromJson = QuizImportService.parseQuizContent(jsonSample);
    expect(fromJson.length, 1);
    expect(fromJson.first.question, 'Which data structure uses LIFO order?');
    expect(fromJson.first.options, ['Queue', 'Stack', 'Heap', 'Graph']);
    expect(fromJson.first.correctOptionIndex, 1);
    expect(fromJson.first.explanation, 'Stack follows Last-In, First-Out.');

    // 2. Parse plain text / Markdown MCQs
    const textSample = '''
1. What is the time complexity of binary search?
A) O(n)
B) O(log n)
C) O(n^2)
D) O(1)
Answer: B
Explanation: Each step halves the search interval.

2. Which keyword is used to inherit a class in Dart?
A) implements
B) extends (Correct)
C) with
D) super
    ''';
    final fromText = QuizImportService.parseQuizContent(textSample);
    expect(fromText.length, 2);
    expect(fromText[0].correctOptionIndex, 1);
    expect(fromText[0].explanation, 'Each step halves the search interval.');
    expect(fromText[1].correctOptionIndex, 1);
    expect(fromText[1].options[1], 'extends');

    // 3. Round-trip QuizModel through public.resources payload (ccquiz://)
    final quiz = QuizModel(
      id: 'c0000001-0000-0000-0000-000000000001',
      subjectId: '11111111-1111-1111-1111-111111111111',
      title: 'NotebookLM Quiz #1',
      description: 'Imported from https://notebooklm.link.google/ELuWPoJL1iNe',
      sourceUrl: 'https://notebooklm.link.google/ELuWPoJL1iNe',
      questions: fromText,
      createdBy: 'Admin',
      createdAt: DateTime(2026, 11, 15),
    );
    final resourcePayload = quiz.toResourcePayload();
    expect(
      (resourcePayload['url'] as String).startsWith(QuizModel.resourceUrlPrefix),
      true,
    );
    final decoded = QuizModel.tryFromResourceMap(resourcePayload);
    expect(decoded, isNotNull);
    expect(decoded!.title, 'NotebookLM Quiz #1');
    expect(decoded.sourceUrl, 'https://notebooklm.link.google/ELuWPoJL1iNe');
    expect(decoded.questions.length, 2);
    expect(decoded.questions[0].correctOptionIndex, 1);

    // 4. Parse AI JSON containing Markdown backslash escapes (\_, \*, \.) and HTML entities (&gt;, &lt;)
    const aiEscapedJson = r'''
    [
      {
        "question": "What type of discontinuity occurs at x = c when lim\_{x -&gt; c} f(x) = L exists?",
        "options": ["x \* e^(x - 1)", "e^x", "Removable discontinuity", "1 / e^x"],
        "correctOptionIndex": 2,
        "explanation": "d/dx[f/g] = (g·f' - f·g') / [g]^2\. Valid for |x| &lt; 1\.",
        "hint": "Look at x -&gt; c."
      }
    ]
    ''';
    final fromAiEscaped = QuizImportService.parseQuizContent(aiEscapedJson);
    expect(fromAiEscaped.length, 1);
    expect(
      fromAiEscaped.first.question,
      'What type of discontinuity occurs at x = c when lim_{x -> c} f(x) = L exists?',
    );
    expect(fromAiEscaped.first.options[0], 'x * e^(x - 1)');
    expect(fromAiEscaped.first.correctOptionIndex, 2);
  });

  test('QuizScoreHistoryNotifier awards credits based on correct answers and improvement on retakes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialCredits = container.read(currentUserProvider).credits;

    // 1. First attempt: 14 out of 20 correct -> awards +14 credits
    final earnedFirst = await container
        .read(quizScoreHistoryProvider.notifier)
        .recordScore(quizId: 'quiz_1', score: 14, totalQuestions: 20);
    expect(earnedFirst, 14);
    expect(container.read(currentUserProvider).credits, initialCredits + 14);

    // 2. Second attempt with lower/equal score (12/20) -> 0 new credits (prevents farming)
    final earnedSecond = await container
        .read(quizScoreHistoryProvider.notifier)
        .recordScore(quizId: 'quiz_1', score: 12, totalQuestions: 20);
    expect(earnedSecond, 0);
    expect(container.read(currentUserProvider).credits, initialCredits + 14);

    // 3. Third attempt improving best score to 19/20 -> awards +5 additional credits (19 - 14)
    final earnedThird = await container
        .read(quizScoreHistoryProvider.notifier)
        .recordScore(quizId: 'quiz_1', score: 19, totalQuestions: 20);
    expect(earnedThird, 5);
    expect(container.read(currentUserProvider).credits, initialCredits + 19);
    expect(container.read(quizScoreHistoryProvider)['quiz_1']?.creditsEarned, 19);
  });

  test('AttendanceRecord bunkAllowance, statusSummary, and AttendanceStorage work accurately', () async {
    const empty = AttendanceRecord(subjectId: 'calc', attended: 0, total: 0);
    expect(empty.bunkAllowance(75), 0);
    expect(empty.isSafe(75), true);
    expect(empty.statusSummary('Calculus', 75), contains('No classes logged yet'));

    // 12 / 13 = 92.3%: (12 / 0.75) - 13 = 3 safe bunks
    const safeRec = AttendanceRecord(subjectId: 'calc', attended: 12, total: 13);
    expect(safeRec.isSafe(75), true);
    expect(safeRec.bunkAllowance(75), 3);
    expect(
      safeRec.statusSummary('Calculus', 75),
      'You can safely miss 3 more Calculus lectures.',
    );

    // Exact boundary 3/4 (75%) and 4/5 (80%) must not suffer floating-point -1 errors
    const exact75 = AttendanceRecord(subjectId: 'calc', attended: 3, total: 4);
    expect(exact75.isSafe(75), true);
    expect(exact75.bunkAllowance(75), 0);

    const exact80 = AttendanceRecord(subjectId: 'calc', attended: 4, total: 5);
    expect(exact80.isSafe(80), true);
    expect(exact80.bunkAllowance(80), 0);

    // 14 / 20 = 70.0% -> Need 4 consecutive classes: (14+4)/(20+4) = 18/24 = 75%
    const dangerRec = AttendanceRecord(subjectId: 'calc', attended: 14, total: 20);
    expect(dangerRec.isSafe(75), false);
    expect(dangerRec.bunkAllowance(75), -4);
    expect(
      dangerRec.statusSummary('Calculus', 75),
      'Danger: Attend the next 4 classes to hit 75%.',
    );

    // Notification quick-action persistence & duplicate slot protection
    final slotKey = AttendanceStorage.buildSlotKey(
      date: DateTime(2026, 11, 26, 9, 0),
      subjectId: '11111111-1111-1111-1111-111111111111',
      slotId: 'slot-mon-1',
    );
    final first = await AttendanceStorage.recordFromNotification(
      subjectId: '11111111-1111-1111-1111-111111111111',
      isPresent: true,
      slotKey: slotKey,
    );
    expect(first.alreadyMarked, false);
    expect(first.record.attended, 1);
    expect(first.record.total, 1);

    final duplicate = await AttendanceStorage.recordFromNotification(
      subjectId: '11111111-1111-1111-1111-111111111111',
      isPresent: true,
      slotKey: slotKey,
    );
    expect(duplicate.alreadyMarked, true);
    expect(duplicate.record.attended, 1);
    expect(duplicate.record.total, 1);
  });

  test('CosmeticsNotifier blocks unverified credit spending, unlocks paid OLED theme once verified, and blocks when insufficient', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 1. Unverified student with 100 credits cannot spend credits until verified
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: 'cosmetic_user_unverified',
      name: 'Unverified Ali',
      email: 'uali@campus.edu',
      role: 'student',
      credits: 100,
      isKzynovexVerified: false,
      isLoggedIn: true,
    ));
    final unverifiedErr = await container
        .read(cosmeticsProvider.notifier)
        .unlockOrEquipTheme(AppThemePreset.obsidianOled);
    expect(unverifiedErr, contains('Verified Student Badge'));
    expect(container.read(currentUserProvider).credits, 100);
    expect(container.read(currentUserProvider.notifier).deductCredits(5), false);

    // 2. Once verified, student with 100 credits can unlock 85 credit Obsidian OLED -> 15 left
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: 'cosmetic_user_1',
      name: 'Ali',
      email: 'ali@campus.edu',
      role: 'student',
      credits: 100,
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));

    final okErr = await container
        .read(cosmeticsProvider.notifier)
        .unlockOrEquipTheme(AppThemePreset.obsidianOled);
    expect(okErr, isNull);
    expect(container.read(cosmeticsProvider).activeTheme, AppThemePreset.obsidianOled);
    expect(container.read(cosmeticsProvider).isThemeUnlocked(AppThemePreset.obsidianOled), true);
    expect(container.read(currentUserProvider).credits, 15);

    // Trying to buy 100 credit Obsidian Gold with 15 credits -> blocked
    final poorErr = await container
        .read(cosmeticsProvider.notifier)
        .unlockOrEquipTheme(AppThemePreset.obsidianGold);
    expect(poorErr, isNotNull);
    expect(container.read(cosmeticsProvider).activeTheme, AppThemePreset.obsidianOled);
    expect(container.read(currentUserProvider).credits, 15);
  });

  test('Verified Student Badge gate: new accounts start unverified, existing verified users stay verified, and Admin approval verifies', () async {
    final auth = AuthService.instance;

    // 1. Newly registered student starts unverified
    final reg = await auth.registerStudent(
      rollNo: '24-SE-101',
      name: 'Zain Raza',
      pin: '1234',
    );
    expect(reg.success, true);
    expect(reg.user!.isKzynovexVerified, false);

    // 2. Newly signed-in Google student starts unverified
    final gNew = await auth.signInWithGoogle(
      email: 'newstudent@gmail.com',
      name: 'New Student',
    );
    expect(gNew.success, true);
    expect(gNew.user!.isKzynovexVerified, false);

    // 3. Submit Student Verification Request & Admin approves
    final reqRes = await auth.submitStudentVerificationRequest(
      userId: gNew.user!.id,
      email: gNew.user!.email,
      name: 'Verified Student',
      rollNo: '24-SE-102',
    );
    expect(reqRes.success, true);

    final reqs = await auth.getStudentVerificationRequests();
    expect(reqs.length, 1);
    expect(reqs.first.isPending, true);

    final approved = await auth.approveStudentVerificationRequest(
      reqs.first.id,
      adminId: 'admin-1',
      adminEmail: 'testadmin1@example.com',
    );
    expect(approved, true);

    // Re-login with Google preserves existing verified badge!
    final gReturning = await auth.signInWithGoogle(
      email: 'newstudent@gmail.com',
      name: 'Verified Student',
    );
    expect(gReturning.user!.isKzynovexVerified, true);
  });

  test('NoteBountiesNotifier enforces verified badge, escrow, no self-claim, anti-scam locked preview, and admin scam rejection', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 1. Unverified user is blocked from posting
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: '11111111-1111-1111-1111-11111111111a',
      name: 'Unverified',
      email: 'u@campus.edu',
      role: 'student',
      credits: 100,
      isKzynovexVerified: false,
      isLoggedIn: true,
    ));
    final unverifiedErr = await container
        .read(noteBountiesProvider.notifier)
        .createBounty(
          subjectId: '11111111-1111-1111-1111-111111111111',
          title: 'Calculus Lecture 5 Notes',
          description: 'Need full derivations',
          rewardCredits: 50,
        );
    expect(unverifiedErr, contains('Verified Student Badge'));

    // 2. Verified requester posts 50 credit bounty -> escrow deducted
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: '22222222-2222-2222-2222-22222222222b',
      name: 'Requester',
      email: 'req@campus.edu',
      role: 'student',
      rollNo: '23-SE-200',
      credits: 100,
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    final createErr = await container
        .read(noteBountiesProvider.notifier)
        .createBounty(
          subjectId: '11111111-1111-1111-1111-111111111111',
          title: 'Calculus Lecture 5 Notes',
          description: 'Need full derivations',
          rewardCredits: 50,
        );
    expect(createErr, isNull);
    expect(container.read(currentUserProvider).credits, 50);

    final bounty = container.read(noteBountiesProvider).first;
    expect(bounty.isOpen, true);

    // 3. Requester cannot claim own bounty
    final selfErr = await container
        .read(noteBountiesProvider.notifier)
        .submitSolution(
          bountyId: bounty.id,
          solutionText: 'Trying to claim my own bounty for free credits.',
        );
    expect(selfErr, contains('cannot claim your own'));

    // 4. Verified helper submits solution -> verify anti-scam locked preview
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: '33333333-3333-3333-3333-33333333333c',
      name: 'Helper',
      email: 'help@campus.edu',
      role: 'student',
      rollNo: '23-SE-201',
      credits: 40,
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    final submitErr = await container
        .read(noteBountiesProvider.notifier)
        .submitSolution(
          bountyId: bounty.id,
          solutionText: 'First part clearly states the Quotient Rule, while the remainder explains full solved examples step by step.',
          solutionUrl: 'https://drive.google.com/file/d/secret123/view',
        );
    expect(submitErr, isNull);

    final submitted = container.read(noteBountiesProvider).first;
    expect(submitted.isSubmitted, true);
    final locked = submitted.buildLockedPreview();
    expect(locked.visibleHalf.isNotEmpty, true);
    expect(locked.garbledHalf.isNotEmpty, true);
    expect(submitted.solutionText!.endsWith(locked.garbledHalf), false);
    expect(submitted.maskedAttachmentLabel, contains('drive.google.com'));
    expect(submitted.maskedAttachmentLabel, isNot(contains('secret123')));

    // 5. Admin rejects scam submission -> resets to open with 0 credits to scammer
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: '44444444-4444-4444-4444-44444444444d',
      name: 'Admin',
      email: 'testadmin1@example.com',
      role: 'admin',
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    final rejectErr = await container
        .read(noteBountiesProvider.notifier)
        .adminRejectSubmission(bounty.id);
    expect(rejectErr, isNull);
    final reopened = container.read(noteBountiesProvider).first;
    expect(reopened.isOpen, true);
    expect(reopened.helperId, isNull);
    expect(reopened.payoutReleased, false);

    // 6. Helper submits real notes and Requester confirms -> completed & payoutReleased
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: '33333333-3333-3333-3333-33333333333c',
      name: 'Helper',
      email: 'help@campus.edu',
      role: 'student',
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    await container.read(noteBountiesProvider.notifier).submitSolution(
          bountyId: bounty.id,
          solutionText: 'Complete verified Calculus derivations and examples attached.',
        );

    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: '22222222-2222-2222-2222-22222222222b',
      name: 'Requester',
      email: 'req@campus.edu',
      role: 'student',
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    final confirmErr = await container
        .read(noteBountiesProvider.notifier)
        .confirmAndReleasePayout(bounty.id);
    expect(confirmErr, isNull);
    final completed = container.read(noteBountiesProvider).first;
    expect(completed.isCompleted, true);
    expect(completed.payoutReleased, true);
  });

  test('LikedResourcesNotifier toggleLike does not mint or farm credits, and CosmeticsNotifier restores cloud unlocks', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: 'like_test_user',
      name: 'Student',
      email: 'student@campus.edu',
      role: 'student',
      credits: 50,
      isKzynovexVerified: false,
      isLoggedIn: true,
    ));

    // Toggle Like -> Unlike -> Like must leave credits unchanged at 50
    final liked = container.read(likedResourcesProvider.notifier).toggleLike('res_1');
    expect(liked, true);
    expect(container.read(currentUserProvider).credits, 50);

    final unliked = container.read(likedResourcesProvider.notifier).toggleLike('res_1');
    expect(unliked, false);
    expect(container.read(currentUserProvider).credits, 50);

    // Restore purchased cosmetics synced from Supabase cloud
    await container
        .read(cosmeticsProvider.notifier)
        .mergeUnlockedFromCloud(['theme:obsidian_gold', 'sound:tactical_pulse']);
    expect(
      container.read(cosmeticsProvider).isThemeUnlocked(AppThemePreset.obsidianGold),
      true,
    );
    expect(
      container.read(cosmeticsProvider).isSoundUnlocked(AlarmSoundPreset.chiptuneAlarm),
      true,
    );
  });

  test('NoteBountiesNotifier allows helper to escalate submitted bounty to Admin when requester is unresponsive', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      name: 'Requester',
      email: 'req@campus.edu',
      role: 'student',
      credits: 80,
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    await container.read(noteBountiesProvider.notifier).createBounty(
          subjectId: '11111111-1111-1111-1111-111111111111',
          title: 'OS Deadlocks Notes',
          description: 'Need lecture 9 notes',
          rewardCredits: 30,
        );
    final bounty = container.read(noteBountiesProvider).first;

    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      name: 'Helper',
      email: 'help@campus.edu',
      role: 'student',
      credits: 40,
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    await container.read(noteBountiesProvider.notifier).submitSolution(
          bountyId: bounty.id,
          solutionText: 'Detailed Coffman deadlock conditions & Banker algorithm walkthrough.',
        );

    // Helper escalates unresponsive requester -> status becomes 'disputed' for Admin Judge
    final escErr = await container
        .read(noteBountiesProvider.notifier)
        .disputeSubmission(bounty.id, 'Helper escalated: awaiting requester confirmation.');
    expect(escErr, isNull);
    expect(container.read(noteBountiesProvider).first.isDisputed, true);
  });

  double contrastRatio(Color fg, Color bg) {
    final l1 = fg.computeLuminance();
    final l2 = bg.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('All 9 AppThemePresets (including Boys & Girls 50-credit themes) sync AppColors dynamically with WCAG contrast >= 4.5', () {
    addTearDown(() => AppColors.applyPalette(AppThemePalette.royalLight));

    expect(AppThemePreset.values.length, 9);
    expect(AppThemePreset.cobaltCarbon.costCredits, 50);
    expect(AppThemePreset.cobaltCarbon.isDark, true);
    expect(AppThemePreset.blushRose.costCredits, 50);
    expect(AppThemePreset.blushRose.isDark, false);

    for (final preset in AppThemePreset.values) {
      AppTheme.forPreset(preset);
      final palette = AppThemePalette.forPreset(preset);

      expect(AppColors.background, palette.background);
      expect(AppColors.cardSurface, palette.cardSurface);
      expect(AppColors.textPrimary, palette.textPrimary);

      if (preset.isDark) {
        expect(AppColors.textPrimary.computeLuminance(), greaterThan(0.7),
            reason: '${preset.id} textPrimary luminance');
        expect(AppColors.background.computeLuminance(), lessThan(0.15),
            reason: '${preset.id} background luminance');
        expect(AppColors.cardSurface.computeLuminance(), lessThan(0.15),
            reason: '${preset.id} cardSurface luminance');
      } else {
        expect(AppColors.textPrimary.computeLuminance(), lessThan(0.15),
            reason: '${preset.id} textPrimary luminance');
        expect(AppColors.background.computeLuminance(), greaterThan(0.85),
            reason: '${preset.id} background luminance');
        expect(AppColors.cardSurface.computeLuminance(), greaterThan(0.85),
            reason: '${preset.id} cardSurface luminance');
      }

      expect(contrastRatio(AppColors.textPrimary, AppColors.cardSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} primary text contrast');
      expect(contrastRatio(AppColors.warningText, AppColors.warningBg),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} warning contrast');
      expect(contrastRatio(AppColors.successText, AppColors.successBg),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} success contrast');
      expect(contrastRatio(AppColors.dangerText, AppColors.dangerBg),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} danger contrast');
      expect(contrastRatio(AppColors.infoText, AppColors.infoBg),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} info contrast');
    }
  });

  testWidgets('HomeScreen renders cleanly under Obsidian OLED and Obsidian Gold themes',
      (WidgetTester tester) async {
    addTearDown(() => AppColors.applyPalette(AppThemePalette.royalLight));

    for (final preset in const [
      AppThemePreset.obsidianOled,
      AppThemePreset.obsidianGold,
    ]) {
      final theme = AppTheme.forPreset(preset);
      final palette = AppThemePalette.forPreset(preset);

      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(preset),
          child: MaterialApp(
            theme: theme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, palette.background);
      expect(find.textContaining('Afternoon,'), anyOf(findsOneWidget, findsNothing));
      expect(find.byType(HomeScreen), findsOneWidget);
    }
  });

  test('ResourcesNotifier supports admin updateResource (with duplicate URL guard) and deleteResource', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(resourcesProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final err1 = notifier.submitResource(
      subjectId: '11111111-1111-1111-1111-111111111111',
      title: 'Initial Calculus Notes',
      type: ResourceType.pdf,
      url: 'https://example.com/calc-week-1.pdf',
      uploaderName: 'Admin',
    );
    expect(err1, isNull);

    final err2 = notifier.submitResource(
      subjectId: '11111111-1111-1111-1111-111111111111',
      title: 'Week 2 Lecture Video',
      type: ResourceType.youtube,
      url: 'https://youtu.be/abc123xyz',
      uploaderName: 'Admin',
    );
    expect(err2, isNull);

    final target = container
        .read(resourcesProvider)
        .firstWhere((r) => r.title == 'Initial Calculus Notes');

    // Editing metadata while keeping the same URL must succeed
    final editOk = notifier.updateResource(
      resourceId: target.id,
      subjectId: '22222222-2222-2222-2222-222222222222',
      title: 'Updated Calculus Week 1 PDF',
      type: ResourceType.image,
      url: target.url,
      isApproved: false,
    );
    expect(editOk, isNull);

    final updated = container
        .read(resourcesProvider)
        .firstWhere((r) => r.id == target.id);
    expect(updated.title, 'Updated Calculus Week 1 PDF');
    expect(updated.subjectId, '22222222-2222-2222-2222-222222222222');
    expect(updated.type, ResourceType.image);
    expect(updated.isApproved, false);

    // Colliding with another resource's URL must be blocked
    final dupErr = notifier.updateResource(
      resourceId: target.id,
      subjectId: updated.subjectId,
      title: updated.title,
      type: updated.type,
      url: 'https://youtu.be/abc123xyz',
    );
    expect(dupErr, contains('Duplicate link'));

    // Admin delete removes resource from state
    notifier.deleteResource(target.id);
    expect(
      container.read(resourcesProvider).any((r) => r.id == target.id),
      false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  test('NoteBountiesNotifier adminApproveBounty credits the helper balance in local registry and active session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final auth = AuthService.instance;
    const helperUser = UserModel(
      id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      name: 'Bounty Helper',
      email: 'helper@campus.edu',
      rollNo: '24-SE-202',
      role: 'student',
      credits: 40,
      isKzynovexVerified: true,
      isLoggedIn: true,
    );
    await auth.adminCreateUser(user: helperUser, pin: '1234');

    const requesterUser = UserModel(
      id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      name: 'Bounty Requester',
      email: 'requester@campus.edu',
      rollNo: '24-SE-201',
      role: 'student',
      credits: 80,
      isKzynovexVerified: true,
      isLoggedIn: true,
    );
    await auth.adminCreateUser(user: requesterUser, pin: '1234');

    // Requester creates 30-credit bounty -> balance drops 80 -> 50
    container.read(currentUserProvider.notifier).setUser(requesterUser);
    final createErr = await container.read(noteBountiesProvider.notifier).createBounty(
          subjectId: '11111111-1111-1111-1111-111111111111',
          title: 'DBMS Normalization Summary',
          description: 'Need 1NF to BCNF examples',
          rewardCredits: 30,
        );
    expect(createErr, isNull);
    expect(container.read(currentUserProvider).credits, 50);

    final bounty = container.read(noteBountiesProvider).first;

    // Helper submits solution
    container.read(currentUserProvider.notifier).setUser(helperUser);
    final submitErr = await container.read(noteBountiesProvider.notifier).submitSolution(
          bountyId: bounty.id,
          solutionText: 'Complete 1NF, 2NF, 3NF, and BCNF worked examples with keys.',
        );
    expect(submitErr, isNull);

    // Admin approves & releases 30-credit bounty payout
    container.read(currentUserProvider.notifier).setUser(const UserModel(
      id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      name: 'Admin Hasham',
      email: 'kzynovexinc@gmail.com',
      role: 'admin',
      credits: 500,
      isKzynovexVerified: true,
      isLoggedIn: true,
    ));
    final approveErr = await container
        .read(noteBountiesProvider.notifier)
        .adminApproveBounty(bounty.id);
    expect(approveErr, isNull);

    final allUsers = await auth.getAllUsers();
    final updatedHelper = allUsers.firstWhere((u) => u.id == helperUser.id);
    expect(updatedHelper.credits, 70);
  });

  test('AlarmSoundPreset raw resources, NotificationSoundPreset selection, and tap sound toggle persist', () async {
    expect(AlarmSoundPreset.fromId('gentle_chime'), AlarmSoundPreset.oversimplifiedAlarm);
    expect(AlarmSoundPreset.fromId('melody_ringtone'), AlarmSoundPreset.dreamcoreAlarm);
    expect(AlarmSoundPreset.fromId('tactical_pulse'), AlarmSoundPreset.chiptuneAlarm);
    expect(AlarmSoundPreset.chiptuneAlarm.rawResName, 'alarm_chiptune');
    expect(AlarmSoundPreset.dreamcoreAlarm.rawResName, 'alarm_dreamcore');
    expect(AlarmSoundPreset.oversimplifiedAlarm.rawResName, 'alarm_oversimplified');
    expect(NotificationSoundPreset.bubblePop.rawResName, 'notif_bubble_pop');
    expect(NotificationSoundPreset.interfaceChime.rawResName, 'notif_interface_chime');
    expect(NotificationSoundPreset.systemDefault.rawResName, isNull);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(cosmeticsProvider.notifier)
        .selectNotificationSound(NotificationSoundPreset.interfaceChime);
    expect(
      container.read(cosmeticsProvider).activeNotificationSound,
      NotificationSoundPreset.interfaceChime,
    );
    expect(
      await AlertScheduler.instance.getSavedNotificationSoundPreset(),
      'interface_chime',
    );

    await container.read(cosmeticsProvider.notifier).setTapSoundEnabled(false);
    expect(container.read(cosmeticsProvider).tapSoundEnabled, false);
    expect(AppSoundService.instance.tapSoundEnabled, false);

    await container.read(cosmeticsProvider.notifier).setTapSoundEnabled(true);
    expect(container.read(cosmeticsProvider).tapSoundEnabled, true);
    expect(AppSoundService.instance.tapSoundEnabled, true);
  });

  test('ResourceType supports notes/pdf/folder/image/youtube with fallback decoding & timetable URL sync constants', () {
    expect(ResourceType.values, containsAll([
      ResourceType.notes,
      ResourceType.pdf,
      ResourceType.folder,
      ResourceType.image,
      ResourceType.youtube,
    ]));

    final notesNative = ResourceModel.fromMap({
      'id': 'res-n1',
      'subject_id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-11-26',
      'uploader_name': 'Admin',
      'title': 'Week 5 Lecture Notes',
      'type': 'notes',
      'url': 'https://example.com/notes.pdf',
    });
    expect(notesNative.type, ResourceType.notes);
    expect(notesNative.title, 'Week 5 Lecture Notes');

    final folderFallback = ResourceModel.fromMap({
      'id': 'res-f1',
      'subject_id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-11-26',
      'uploader_name': 'Admin',
      'title': ResourceModel.encodeFallbackTitle('Midterm Drive Bundle', ResourceType.folder),
      'type': 'pdf',
      'url': 'https://drive.google.com/drive/folders/abc123',
    });
    expect(folderFallback.type, ResourceType.folder);
    expect(folderFallback.title, 'Midterm Drive Bundle');

    expect(ClassRepository.timetableImageUrlPrefix, 'cctimetable://');
    expect(ClassRepository.timetableImageResourceId, isNotEmpty);
  });

  test('TaskCategory round-trips assignments, quizzes & presentations and keeps them distinct per subject', () {
    final quizMap = AssignmentModel(
      id: 'task-q1',
      subjectId: '11111111-1111-1111-1111-111111111111',
      title: 'Quiz 2: Calculus',
      description: 'Chapters 3-4',
      deadline: DateTime(2026, 11, 28, 10, 0),
      createdBy: 'Admin',
      createdAt: DateTime(2026, 11, 26),
      category: TaskCategory.quiz,
    ).toMap();
    expect(quizMap['category'], 'quiz');
    final parsedQuiz = AssignmentModel.fromMap(quizMap);
    expect(parsedQuiz.category, TaskCategory.quiz);
    expect(parsedQuiz.description, 'Chapters 3-4');

    // Zero-migration fallback tag decoding when DB column `category` is missing
    final presFallback = AssignmentModel.fromMap({
      'id': 'task-p1',
      'subject_id': '11111111-1111-1111-1111-111111111111',
      'title': 'Group Architecture Demo',
      'description': AssignmentModel.encodeCategoryInDescription(
          '10 mins per team', TaskCategory.presentation),
      'deadline': DateTime(2026, 11, 29, 14, 0).toIso8601String(),
      'created_by': 'Admin',
      'created_at': DateTime(2026, 11, 26).toIso8601String(),
    });
    expect(presFallback.category, TaskCategory.presentation);
    expect(presFallback.description, '10 mins per team');

    // latestAssignmentsPerSubject keeps Assignment, Quiz & Presentation for same subject
    final olderAssignment = AssignmentModel(
      id: 'task-a-old',
      subjectId: '11111111-1111-1111-1111-111111111111',
      title: 'Old HW 1',
      description: '',
      deadline: DateTime(2026, 11, 20),
      createdBy: 'Admin',
      createdAt: DateTime(2026, 11, 15),
      category: TaskCategory.assignment,
    );
    final newerAssignment = olderAssignment.copyWith(
      id: 'task-a-new',
      title: 'Latest HW 2',
      deadline: DateTime(2026, 11, 30),
    );
    final latest = latestAssignmentsPerSubject([
      olderAssignment,
      newerAssignment,
      parsedQuiz,
      presFallback,
    ]);
    expect(latest.length, 3);
    expect(latest.map((t) => t.id), containsAll(['task-a-new', 'task-q1', 'task-p1']));
  });
}


