import 'package:flutter/material.dart';

import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Full-colour, built-in style sign-in (same look as the web app's sign-in).
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = p.accent;
    final dark2 = Color.lerp(a, Colors.black, .45)!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(a, Colors.black, .12)!, dark2]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  Container(
                    width: 108,
                    height: 108,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(.25)),
                    ),
                    child: const Text('S', style: TextStyle(fontSize: 58, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Salli', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  Text('MONEY MANAGER', style: TextStyle(color: Colors.white.withOpacity(.75), letterSpacing: 2.4, fontSize: 13)),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.22),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withOpacity(.16)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white.withOpacity(.14),
                          labelStyle: TextStyle(color: Colors.white.withOpacity(.85)),
                          hintStyle: TextStyle(color: Colors.white.withOpacity(.55)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(.22))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(.22))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white, width: 1.4)),
                        ),
                        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white),
                      ),
                      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _lightBtn(BuildContext c) => FilledButton.styleFrom(
      backgroundColor: const Color(0xFFF2F4F5),
      foregroundColor: Color.lerp(Palette.of(c).accent, Colors.black, .35),
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  String mode = 'signin'; // signin | signup | reset
  bool busy = false;
  bool hide = true;
  String? msg;
  bool ok = false;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    pass2.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final s = StoreScope.read(context);
    final e = email.text.trim();
    if (!e.contains('@')) {
      setState(() => msg = 'Enter a valid email address.');
      return;
    }
    if (mode != 'reset' && pass.text.length < 6) {
      setState(() => msg = 'Password must be at least 6 characters.');
      return;
    }
    if (mode == 'signup' && pass.text != pass2.text) {
      setState(() => msg = 'Passwords do not match.');
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    String? r;
    if (mode == 'signin') {
      r = await s.signIn(e, pass.text);
    } else if (mode == 'signup') {
      r = await s.signUp(e, pass.text);
      if (r == 'OK_CONFIRM') {
        r = null;
        ok = true;
        msg = 'Account created. Check your email to confirm it, then sign in. An administrator will approve your account.';
        mode = 'signin';
      }
    } else {
      r = await s.resetPassword(e);
      if (r == null) {
        ok = true;
        msg = 'Password reset email sent. Open the link in the email to choose a new password.';
      }
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r != null) {
        ok = false;
        msg = r;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final title = mode == 'signin' ? 'Welcome back' : mode == 'signup' ? 'Create account' : 'Reset password';
    final sub = mode == 'signin'
        ? 'Sign in to your secure money manager.'
        : mode == 'signup'
            ? 'Register with your email. An administrator approves new accounts.'
            : 'We will email you a link to choose a new password.';
    final showMsg = msg ?? s.message;
    return AuthShell(
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(.78))),
          const SizedBox(height: 18),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (mode != 'reset') ...[
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: hide,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white70),
                  onPressed: () => setState(() => hide = !hide),
                ),
              ),
              onSubmitted: (_) => mode == 'signin' ? submit() : null,
            ),
          ],
          if (mode == 'signup') ...[
            const SizedBox(height: 12),
            TextField(controller: pass2, obscureText: hide, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Confirm password')),
          ],
          if (showMsg != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (ok ? Colors.white : const Color(0xFF7A140A)).withOpacity(.18), borderRadius: BorderRadius.circular(10)),
              child: Text(showMsg, style: TextStyle(color: ok ? Colors.white : const Color(0xFFFFE1DC))),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: _lightBtn(context),
            onPressed: busy ? null : submit,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(mode == 'signin' ? 'Sign in' : mode == 'signup' ? 'Create account' : 'Send reset link'),
          ),
          const SizedBox(height: 10),
          if (mode == 'signin')
            TextButton(onPressed: () => setState(() {
                  mode = 'reset';
                  msg = null;
                }), child: const Text('Forgot password?', style: TextStyle(color: Colors.white))),
          TextButton(
            onPressed: () => setState(() {
              mode = mode == 'signin' ? 'signup' : 'signin';
              msg = null;
              ok = false;
            }),
            child: Text(mode == 'signin' ? 'New here? Create an account' : 'Back to sign in', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.phase});
  final Phase phase;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final rejected = phase == Phase.rejected;
    final err = phase == Phase.error;
    return AuthShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(rejected ? Icons.block : err ? Icons.wifi_off_rounded : Icons.hourglass_top_rounded, color: Colors.white, size: 40),
        const SizedBox(height: 12),
        Text(rejected ? 'Registration not approved' : err ? 'You are offline' : 'Waiting for approval',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        Text(
          rejected
              ? 'Your registration was not approved. Contact the administrator if you think this is a mistake.'
              : err
                  ? (s.message ?? 'Connect to the internet and try again.')
                  : 'Your account was created and is waiting for an administrator to approve it. You can check again any time.',
          style: TextStyle(color: Colors.white.withOpacity(.8)),
        ),
        const SizedBox(height: 20),
        if (!rejected) FilledButton(style: _lightBtn(context), onPressed: () => s.recheckApproval(), child: const Text('Check again')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => s.signOut(), child: const Text('Sign out', style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final name = TextEditingController(), phone = TextEditingController(), country = TextEditingController();
  bool busy = false;
  String? msg;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return AuthShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Complete your profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Your registration has been approved. Add a few details before entering your money manager.', style: TextStyle(color: Colors.white.withOpacity(.78))),
        const SizedBox(height: 16),
        TextField(controller: name, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 12),
        TextField(controller: phone, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Phone number (optional)')),
        const SizedBox(height: 12),
        TextField(controller: country, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Country (optional)')),
        if (msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(msg!, style: const TextStyle(color: Color(0xFFFFE1DC)))),
        const SizedBox(height: 20),
        FilledButton(
          style: _lightBtn(context),
          onPressed: busy
              ? null
              : () async {
                  if (name.text.trim().isEmpty) {
                    setState(() => msg = 'Please enter your full name.');
                    return;
                  }
                  setState(() => busy = true);
                  final r = await s.saveProfileDetails(name.text, phone.text, country.text);
                  if (mounted) {
                    setState(() {
                      busy = false;
                      msg = r;
                    });
                  }
                },
          child: Text(busy ? 'Saving…' : 'Save and continue'),
        ),
      ]),
    );
  }
}

class ConflictScreen extends StatelessWidget {
  const ConflictScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return AuthShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.sync_problem_rounded, color: Colors.white, size: 40),
        const SizedBox(height: 10),
        const Text('Cloud data changed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        Text('Your account was updated on another device (for example the Salli web app) while this phone had changes that were not synced yet. Choose which copy to keep.',
            style: TextStyle(color: Colors.white.withOpacity(.8))),
        const SizedBox(height: 20),
        FilledButton(style: _lightBtn(context), onPressed: () => s.resolveConflict(keepCloud: true), child: const Text('Use the cloud copy')),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
          onPressed: () => s.resolveConflict(keepCloud: false),
          child: const Text('Keep this phone’s copy'),
        ),
      ]),
    );
  }
}
