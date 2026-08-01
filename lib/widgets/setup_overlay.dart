import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../src/rust/api.dart' as rust_api;
import '../theme/app_colors.dart';

class SetupOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const SetupOverlay({super.key, required this.child});

  @override
  ConsumerState<SetupOverlay> createState() => _SetupOverlayState();
}

class _SetupOverlayState extends ConsumerState<SetupOverlay> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _checks = [];

  @override
  void initState() {
    super.initState();
    _runPreflight();
  }

  Future<void> _runPreflight() async {
    final checks = await rust_api.runPreflightChecks();
    final failed = checks.any((c) => c.status != 'Ok'); // Assume 'Ok' status
    
    if (mounted) {
      setState(() {
        _checks = checks;
        _loading = false;
        if (failed) _error = rust_api.formatPreflightChecks(checks);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(_error, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _runPreflight(),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
