import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _enableHeadlessLogging = true;
  String _vSyncMode = 'VBlank (Display Native)';

  @override
  Widget build(BuildContext context) {
    // Standard Material 3 setup
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
            surfaceTintColor: colorScheme.surfaceTint,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader('Engine Core'),
              SwitchListTile(
                title: const Text('Enable Headless Logging'),
                subtitle: const Text('Pump native KrKr2 events to the Flutter console viewport.'),
                value: _enableHeadlessLogging,
                onChanged: (val) {
                  setState(() {
                    _enableHeadlessLogging = val;
                  });
                },
              ),
              ListTile(
                title: const Text('VSync Synchronization'),
                subtitle: Text(_vSyncMode),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () {
                  // Stub for future picker
                },
              ),
              const Divider(height: 32),
              _buildSectionHeader('Storage & Data'),
              ListTile(
                leading: Icon(Icons.delete_sweep, color: colorScheme.error),
                title: Text('Clear Game History', style: TextStyle(color: colorScheme.error)),
                subtitle: const Text('Removes all added game paths from the launcher.'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('game_paths');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Game history cleared! Restart necessary to reflect.')),
                    );
                  }
                },
              ),
              const Divider(height: 32),
              _buildSectionHeader('About'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Version'),
                subtitle: Text('1.0.0 (Revived)'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
