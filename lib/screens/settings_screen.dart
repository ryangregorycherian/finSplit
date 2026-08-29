import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final groupProvider = context.watch<GroupProvider>();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Saved automatically'),
            secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode),
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.qr_code_2_outlined),
            title: const Text('Invite people to this group'),
            subtitle: Text('Join code: ${groupProvider.activeJoinCode ?? '...'}'),
            trailing: const Icon(Icons.copy),
            onTap: () {
              final code = groupProvider.activeJoinCode ?? '';
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Join code "$code" copied')),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Participants'),
            subtitle: Text(groupProvider.activeParticipants.map((p) => p.name).join(', ')),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Leave this group', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Your data stays safe in the cloud — this just switches devices'),
            onTap: () => groupProvider.forgetActiveGroup(),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete group completely', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Permanently removes this group for everyone — cannot be undone'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this group?'),
                  content: Text(
                    'This permanently deletes "${groupProvider.activeGroupName}" and every expense, '
                    'settlement, and participant in it — for everyone in the group. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete forever'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await groupProvider.deleteActiveGroupCompletely();
              }
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Campus QuickSplit — share the join code above so friends can hop into this group instantly, no signup required.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
