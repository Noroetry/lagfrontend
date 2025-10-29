import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart';
import 'package:lagfrontend/views/home/home_screen.dart';
import 'package:lagfrontend/views/auth/welcome_screen.dart';
import 'package:lagfrontend/models/user_model.dart';

class MockAuthController extends ChangeNotifier implements AuthController {
  bool _loading = false;
  bool _authenticated = false;
  User? _user;
  
  @override
  final storage = const FlutterSecureStorage();

  @override
  bool get isLoading => _loading;
  
  @override
  bool get isAuthenticated => _authenticated;
  
  @override
  User? get currentUser => _user;

  @override
  String? get authToken => _authenticated ? 'fake-token' : null;

  @override
  String? get errorMessage => null;

  void updateState({bool? loading, bool? authenticated, User? user}) {
    _loading = loading ?? _loading;
    _authenticated = authenticated ?? _authenticated;
    _user = user;
    notifyListeners();
  }

  @override
  Future<void> checkAuthenticationStatus() async {}

  @override
  Future<void> login(String usernameOrEmail, String password) async {}

  @override
  Future<void> registerAndLogin(String username, String email, String password) async {}

  @override
  Future<void> logout() async {
    _authenticated = false;
    _user = null;
    notifyListeners();
  }
}

void main() {
  late MockAuthController mockAuthController;

  setUp(() {
    mockAuthController = MockAuthController();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthController>.value(
        value: mockAuthController,
        child: const AuthGate(),
      ),
    );
  }

  testWidgets('Muestra loading mientras isLoading es true', (tester) async {
    mockAuthController.updateState(loading: true, authenticated: false);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Verificando sesión...'), findsOneWidget);
  });

  testWidgets('Navega a HomeScreen si está autenticado', (tester) async {
    mockAuthController.updateState(
      loading: false,
      authenticated: true,
      user: User(id: '1', username: 'test', email: 't@t.com', isAdmin: false)
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('Navega a WelcomeScreen si NO está autenticado', (tester) async {
    mockAuthController.updateState(
      loading: false,
      authenticated: false,
      user: null
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Transición loading -> autenticado -> HomeScreen', (tester) async {
    // Empezamos con loading
    mockAuthController.updateState(loading: true, authenticated: false);

    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Cambiamos a autenticado
    mockAuthController.updateState(
      loading: false,
      authenticated: true,
      user: User(id: '1', username: 'test', email: 't@t.com', isAdmin: false)
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Transición loading -> no autenticado -> WelcomeScreen', (tester) async {
    // Empezamos con loading
    mockAuthController.updateState(loading: true, authenticated: false);

    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Cambiamos a no autenticado
    mockAuthController.updateState(
      loading: false,
      authenticated: false,
      user: null
    );

    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}