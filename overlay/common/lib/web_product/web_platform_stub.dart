// Stub of web_platform.dart for the Dart VM (tests): storage lives in memory, nothing is fetched or navigated.
final Map<String, String> _store = {};

/// Everything stored by [storageSet] in this process (tests read and clear it).
Map<String, String> get memoryStorage => _store;

String? storageGet(String key) => _store[key];

void storageSet(String key, String value) => _store[key] = value;

Future<String?> fetchText(String url) async => null;

/// Addresses opened through [navigateTo], newest last (tests read this).
final List<String> navigated = [];

void navigateTo(String url) => navigated.add(url);

void replaceHash(String hash) {}

void keepAddressAsIs() {}
