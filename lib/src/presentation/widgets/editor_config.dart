import 'package:flutter/widgets.dart';

import '../../domain/entities/l10n_catalog.dart';

/// Opens the app's own way of granting edit access: a login screen, an OTP
/// prompt, a confirmation, or nothing at all. [context] is below the app's
/// Navigator, so it can show dialogs and push routes.
typedef L10nAccessRequest = Future<void> Function(BuildContext context);

/// Settings the editor widgets read, provided by `InContextEditor`.
class EditorConfig {
  /// Creates the settings.
  const EditorConfig({
    required this.catalog,
    this.label,
    this.onRequestAccess,
    this.onSignOut,
    this.navigatorKey,
  });

  /// Every ARB key of the app.
  final L10nCatalog catalog;

  /// Shown in the toolbar, e.g. the backend project name.
  final String? label;

  /// Shows the Edit button for people without access when set.
  final L10nAccessRequest? onRequestAccess;

  /// Shows a sign-out button in the toolbar when set.
  final Future<void> Function()? onSignOut;

  /// The app's Navigator; found automatically when null.
  final GlobalKey<NavigatorState>? navigatorKey;
}
