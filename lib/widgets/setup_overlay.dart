import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../src/rust/api.dart' as rust_api;
import '../src/rust/doctor.dart';

/// A flag to skip preflight checks during tests.
/// Set to true before running tests, or use SetupOverlay.test() constructor.
bool skipPreflightChecks = false;

class SetupOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const SetupOverlay({super.key, required this.child});

  /// Creates a SetupOverlay that skips preflight checks.
  /// Use this in tests to avoid hanging on preflight checks.
  const SetupOverlay.test({super.key, required this.child});

  @override
  ConsumerState<SetupOverlay> createState() => _SetupOverlayState();
}

class _SetupOverlayState extends ConsumerState<SetupOverlay> {
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (!skipPreflightChecks) {
      _runPreflight();
    } else {
      _loading = false;
    }
  }

  Future<void> _runPreflight() async {
    final checks = await rust_api.runPreflightChecks();
    final failed = checks.any((c) => c.status is! CheckStatus_Ok);
    String? error;
    if (failed) {
      error = await rust_api.formatPreflightChecks(checks: checks);
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = error ?? '';
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