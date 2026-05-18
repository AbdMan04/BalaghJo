// Helpers for working with errors thrown by the data layer
// (mainly [ApiException] from lib/data/api/api_client.dart).
//
// When a thrown error is converted to a String, Dart prepends
// `Exception:` or `ApiException(status):` — this helper strips that
// prefix so the UI shows only the user-facing message.

final _apiErrorPrefix = RegExp(r'^(Exception|ApiException\([^)]*\)):\s*');

String cleanErrorMessage(Object e) {
  return e.toString().replaceFirst(_apiErrorPrefix, '');
}
