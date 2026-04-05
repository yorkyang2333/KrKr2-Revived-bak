import 'package:flutter/material.dart';
import '../engine_controller.dart';

class ConsoleView extends StatefulWidget {
  const ConsoleView({super.key});

  @override
  State<ConsoleView> createState() => _ConsoleViewState();
}

class _ConsoleViewState extends State<ConsoleView> {
  final EngineController _engine = EngineController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          Expanded(
            child: StreamBuilder<String>(
              stream: _engine.logStream,
              builder: (context, snapshot) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _engine.logs.length,
                  itemBuilder: (context, index) {
                    final logLine = _engine.logs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text.rich(
                        _colorizeLog(logLine),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  TextSpan _colorizeLog(String log) {
    // Simple RegEx coloring for standard engine logs.
    Color baseColor = Theme.of(context).colorScheme.onSurface;
    
    if (log.contains(RegExp(r'(error|exception|fail)', caseSensitive: false))) {
      baseColor = Colors.redAccent;
    } else if (log.contains(RegExp(r'(warn|warning)', caseSensitive: false))) {
      baseColor = Colors.orangeAccent;
    } else if (log.contains(RegExp(r'(info|success|bound|start)', caseSensitive: false))) {
      baseColor = Colors.lightGreen;
    }

    // Split components if it follows [LEVEL] Format
    final match = RegExp(r'^(\[\d+\])\s*(.*)').firstMatch(log);
    if (match != null) {
      return TextSpan(
        children: [
          TextSpan(
            text: '${match.group(1)} ',
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: match.group(2) ?? '',
            style: TextStyle(color: baseColor),
          ),
        ],
      );
    }
    return TextSpan(text: log, style: TextStyle(color: baseColor));
  }
}
