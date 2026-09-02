// AdminUser is now just an alias for the shared AppUser model — the admin
// dashboard's user directory and the citizen's own profile are the same
// shape, so they share one implementation. Import AppUser from `user.dart`
// directly in new code.
import 'user.dart';

typedef AdminUser = AppUser;
