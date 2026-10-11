import 'dart:async';

import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

class FakeOnboardingPreferences implements OnboardingPreferences {
  FakeOnboardingPreferences({this.value});
  Object? value;
  int reads = 0;
  int writes = 0;
  bool failRead = false;
  bool failSave = false;
  Completer<void>? readGate;
  Completer<void>? saveGate;

  @override
  Future<Object?> readVersion() async {
    reads++;
    if (readGate != null) await readGate!.future;
    if (failRead) throw StateError('Synthetic read failure');
    return value;
  }

  @override
  Future<void> saveVersion(int version) async {
    writes++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Synthetic save failure');
    value = version;
  }
}
