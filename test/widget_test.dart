import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:softwareclass/core/config/app_config.dart';
import 'package:softwareclass/core/services/auth_service.dart';
import 'package:softwareclass/core/utils/formatters.dart';
import 'package:softwareclass/models/models.dart';
import 'package:softwareclass/core/constants/kzynovex_branding.dart';
import 'package:softwareclass/features/assignment_scanner/assignment_scanner_screen.dart';
import 'package:softwareclass/features/shell/main_shell.dart';
import 'package:softwareclass/features/splash/splash_screen.dart';

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
}

