import 'package:flutter/material.dart';

import 'spacing.dart';

/// Signs in with [email] and [password]. Returns null on success, or why it
/// failed, which the dialog shows.
typedef EmailPasswordSignIn =
    Future<String?> Function(String email, String password);

/// Shows a ready-made email/password dialog, for apps whose editors sign in
/// that way. Use it from `InContextEditor.onRequestAccess`; any other sign-in
/// UI works just as well.
///
/// The dialog closes once [signIn] returns null. Returns true when it did.
Future<bool> showEmailPasswordSignInDialog(
  BuildContext context, {
  required EmailPasswordSignIn signIn,
  String title = 'Editor sign-in',
  String? subtitle,
}) async {
  final signedIn = await showDialog<bool>(
    context: context,
    builder: (_) => EmailPasswordSignInDialog(
      signIn: signIn,
      title: title,
      subtitle: subtitle,
    ),
  );
  return signedIn ?? false;
}

/// The dialog shown by [showEmailPasswordSignInDialog].
class EmailPasswordSignInDialog extends StatefulWidget {
  /// Creates the dialog.
  const EmailPasswordSignInDialog({
    required this.signIn,
    this.title = 'Editor sign-in',
    this.subtitle,
    super.key,
  });

  /// Called with the entered credentials.
  final EmailPasswordSignIn signIn;

  /// The dialog title.
  final String title;

  /// Shown below the title, e.g. the backend project name.
  final String? subtitle;

  @override
  State<EmailPasswordSignInDialog> createState() =>
      _EmailPasswordSignInDialogState();
}

class _EmailPasswordSignInDialogState extends State<EmailPasswordSignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signingIn = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    final error = await widget.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _signingIn = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = widget.subtitle;
    final error = _error;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) ...[
                Text(subtitle, style: theme.textTheme.bodySmall),
                gapMd,
              ],
              TextField(
                controller: _email,
                enabled: !_signingIn,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              gapSm,
              TextField(
                controller: _password,
                enabled: !_signingIn,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _submit(),
              ),
              if (error != null) ...[
                gapMd,
                Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _signingIn ? null : _submit,
          child: _signingIn
              ? const SizedBox.square(
                  dimension: Spacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
      ],
    );
  }
}
