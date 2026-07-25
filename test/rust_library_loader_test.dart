import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/services/rust_library_loader.dart';

void main() {
  test('does not throw when no library is present on the test machine', () {
    // On the CI/test machine there's no packaged app bundle, so this
    // exercises the "not found -> return null" path without touching FFI.
    expect(() => tryLoadRustCoreLibrary(), returnsNormally);
  });
}
