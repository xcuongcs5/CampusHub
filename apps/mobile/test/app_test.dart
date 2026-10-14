import 'package:campus_hub/app/app.dart';
import 'package:campus_hub/features/auth/data/auth_models.dart';
import 'package:campus_hub/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  static const user = AuthUser(
    id: 'user-1',
    institutionId: 'institution-1',
    studentId: 'SV20260001',
    email: 'student@example.edu.vn',
    displayName: 'Minh Anh',
  );

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
    required bool remember,
  }) async =>
      user;

  @override
  Future<AuthUser> register({
    required String displayName,
    required String studentId,
    required String email,
    required String password,
  }) async =>
      user;

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('renders sign in and navigates to sign up', (tester) async {
    await tester.pumpWidget(CampusHubApp(authRepository: FakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);

    await tester.ensureVisible(find.text('Đăng ký'));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản của bạn'), findsOneWidget);
    expect(find.text('Mã số sinh viên'), findsOneWidget);
  });

  testWidgets('signs in and renders the Campus Hub demo shell', (
    tester,
  ) async {
    await tester.pumpWidget(CampusHubApp(authRepository: FakeAuthRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.edu.vn',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.ensureVisible(find.byKey(const Key('sign-in-submit')));
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Minh Anh 👋'), findsOneWidget);
    expect(find.text('Dịch vụ sinh viên'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Phòng'), findsOneWidget);
    expect(find.text('Thư viện'), findsOneWidget);
    expect(find.text('Sự kiện'), findsWidgets);
    expect(find.text('Cửa hàng'), findsOneWidget);
  });

  testWidgets('navigates to the room booking demo', (tester) async {
    await tester.pumpWidget(CampusHubApp(authRepository: FakeAuthRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.edu.vn',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.ensureVisible(find.byKey(const Key('sign-in-submit')));
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Phòng'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm phòng học'), findsOneWidget);
    expect(find.text('Phòng A-101'), findsOneWidget);
  });
}
