import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _nameCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController(text: 'My Squad');
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _groupNameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _groupNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name and a group name');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<GroupProvider>().createGroup(_groupNameCtrl.text.trim(), _nameCtrl.text.trim());
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name and the join code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await context.read<GroupProvider>().joinGroup(_codeCtrl.text.trim(), _nameCtrl.text.trim());
      if (!ok) setState(() => _error = "That code doesn't match any group");
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus QuickSplit'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Create group'), Tab(text: 'Join group')]),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  ListView(
                    children: [
                      TextField(
                        controller: _groupNameCtrl,
                        decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _create,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _loading ? const CircularProgressIndicator() : const Text('Create group'),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    children: [
                      TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Join code (e.g. K3F9QZ)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _join,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _loading ? const CircularProgressIndicator() : const Text('Join group'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
