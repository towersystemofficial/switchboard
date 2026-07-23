import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/system_provider.dart';
import 'home_shell.dart';
import 'setup/setup_wizard_screen.dart';

/// Shown briefly on every app launch: "Welcome back, {system name}" with
/// the system avatar, then auto-advances into the app. Skipped entirely
/// on a first-ever run (no system configured yet) -- the normal vault
/// setup flow takes over immediately in that case.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _navigated = false;
  bool _sequenceStarted = false;

  static const _animDuration = Duration(milliseconds: 700);
  static const _holdDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeShell(key: homeShellKey)),
    );
  }

  void _proceedToSetup() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
    );
  }

  void _startSequence() {
    if (_sequenceStarted) return;
    _sequenceStarted = true;
    _controller.forward();
    Future.delayed(_animDuration + _holdDuration, _proceed);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (provider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // First-ever run, or vault not connected yet -- nothing to "welcome
    // back" to, so skip straight past this screen.
    if (!provider.isVaultConfigured || provider.systemName.trim().isEmpty) {
      if (!_navigated) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _proceedToSetup());
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    _startSequence();

    final path = provider.avatarPath(provider.systemAvatarFilename);
    final hasAvatarFile = path != null && File(path).existsSync();

    return Scaffold(
      body: GestureDetector(
        onTap: _proceed,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  hasAvatarFile
                      ? CircleAvatar(radius: 56, backgroundImage: FileImage(File(path)))
                      : CircleAvatar(
                          radius: 56,
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(Icons.groups, size: 48, color: Colors.white70),
                        ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back, ${provider.systemName}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}