import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/expense_provider.dart';
import 'providers/group_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final uid = await FirebaseService.init();
  runApp(QuickSplitApp(uid: uid));
}

class QuickSplitApp extends StatelessWidget {
  final String uid;
  const QuickSplitApp({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()..setUid(uid)),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Campus QuickSplit',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF4F86C6),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF4F86C6),
              brightness: Brightness.dark,
            ),
            home: const _RootRouter(),
          );
        },
      ),
    );
  }
}

/// Shows onboarding (create/join a group) until a group is active, then
/// hands off to the main app shell.
class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  String? _attachedGroupId;
  bool _restoreTriggered = false;

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    // Kick off the "was I already in a group?" check exactly once.
    if (!_restoreTriggered) {
      _restoreTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<GroupProvider>().tryRestoreLastGroup();
      });
    }

    // Once a group becomes active, hook the ExpenseProvider up to it (once).
    if (groupProvider.activeGroupId != null && groupProvider.activeGroupId != _attachedGroupId) {
      _attachedGroupId = groupProvider.activeGroupId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ExpenseProvider>().attachToGroup(_attachedGroupId!);
      });
    }

    if (groupProvider.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (groupProvider.activeGroupId == null) return const OnboardingScreen();
    return const HomeScreen();
  }
}
