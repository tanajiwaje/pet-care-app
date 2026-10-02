// Initializes the Flutter application, Firebase, startup experience, and error logging.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/app_shell/presentation/pages/app_shell_page.dart';
import 'services/audit_log_service.dart';

/// Initializes Flutter, installs application error logging, and launches PetCare.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorLogging();

  runApp(const PetCareApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AuditLogService.instance.pruneExpiredEntries());
  });
}

/// Registers Flutter and platform error handlers that persist uncaught errors.
void _installErrorLogging() {
  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      AuditLogService.instance.recordError(
        entity: 'Application',
        message: 'An uncaught UI exception occurred',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
      ),
    );
    if (previousFlutterErrorHandler != null) {
      previousFlutterErrorHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformErrorHandler = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      AuditLogService.instance.recordError(
        entity: 'Application',
        message: 'An uncaught application exception occurred',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return previousPlatformErrorHandler?.call(error, stackTrace) ?? false;
  };
}

/// Owns Firebase startup, the animated loading/error states, and the root app theme.
class PetCareApp extends StatefulWidget {
  final Future<void> Function()? firebaseInitializer;

  /// Creates the application and optionally accepts a Firebase initializer for tests.
  const PetCareApp({super.key, this.firebaseInitializer});

  /// Creates the state that initializes Firebase and runs the startup animation.
  @override
  State<PetCareApp> createState() => _PetCareAppState();
}

/// Manages the state and lifecycle of pet care app.
class _PetCareAppState extends State<PetCareApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pawAnimationController;
  bool _isInitializing = true;
  Object? _initializationError;

  /// Initializes pet care app state state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    _pawAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _initializeFirebase();
  }

  /// Initializes Firebase and transitions startup to the app or error screen.
  Future<void> _initializeFirebase() async {
    _pawAnimationController.repeat();
    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    try {
      final firebaseInitializer = widget.firebaseInitializer;
      if (firebaseInitializer != null) {
        await firebaseInitializer();
      } else if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (!mounted) return;
      _pawAnimationController.stop();
      setState(() => _isInitializing = false);
    } catch (error) {
      if (!mounted) return;
      _pawAnimationController.stop();
      setState(() {
        _isInitializing = false;
        _initializationError = error;
      });
    }
  }

  /// Releases resources owned by pet care app state, including controllers and subscriptions.
  @override
  void dispose() {
    _pawAnimationController.dispose();
    super.dispose();
  }

  /// Builds the widget tree for pet care app state.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _isInitializing
          ? _StartupLoadingPage(animation: _pawAnimationController)
          : _initializationError == null
          ? const AppShellPage()
          : _StartupErrorPage(
              error: _initializationError!,
              onRetry: _initializeFirebase,
            ),
    );
  }
}

/// Displays the branded animated startup screen while Firebase initializes.
class _StartupLoadingPage extends StatelessWidget {
  final Animation<double> animation;

  /// Creates the animated startup view using the supplied pet animation.
  const _StartupLoadingPage({required this.animation});

  /// Builds the widget tree for startup loading page.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.56),
              colorScheme.surface,
              colorScheme.tertiaryContainer.withValues(alpha: 0.48),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 270,
                  height: 210,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(38),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 28,
                        left: 26,
                        child: _FloatingPet(animation: animation, phase: 0),
                      ),
                      Positioned(
                        top: 22,
                        right: 26,
                        child: _FloatingPet(
                          animation: animation,
                          phase: math.pi,
                          isDog: true,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                final phase =
                                    (animation.value * 2 * math.pi -
                                        index * 0.85) %
                                    (2 * math.pi);
                                final opacity =
                                    0.28 + (math.sin(phase) + 1) * 0.32;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Opacity(
                                    opacity: opacity,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'PetCare',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A little care goes a long way.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 130,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: null,
                      minHeight: 5,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Getting everything ready...',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds an animated floating pet illustration for startup.
class _FloatingPet extends StatelessWidget {
  final Animation<double> animation;
  final double phase;
  final bool isDog;

  /// Creates a floating cat or dog illustration at the supplied animation phase.
  const _FloatingPet({
    required this.animation,
    required this.phase,
    this.isDog = false,
  });

  /// Builds the widget tree for floating pet.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = isDog ? const Color(0xFFD98A55) : colors.primary;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final angle = animation.value * 2 * math.pi + phase;
        return Transform.translate(
          offset: Offset(0, math.sin(angle) * 7),
          child: Transform.rotate(angle: math.sin(angle) * 0.045, child: child),
        );
      },
      child: Container(
        width: 104,
        height: 112,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Semantics(
          label: isDog ? 'Animated dog' : 'Animated cat',
          child: CustomPaint(
            size: const Size(94, 102),
            painter: _PetFacePainter(
              furColor: isDog
                  ? const Color(0xFFD98A55)
                  : const Color(0xFF16827E),
              muzzleColor: const Color(0xFFFFF8E9),
              isDog: isDog,
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the illustrated pet face used in the startup screen.
class _PetFacePainter extends CustomPainter {
  final Color furColor;
  final Color muzzleColor;
  final bool isDog;

  /// Configures the pet-face painter with its animation and animal type.
  const _PetFacePainter({
    required this.furColor,
    required this.muzzleColor,
    required this.isDog,
  });

  /// Draws pet face painter on the supplied canvas.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 108);

    final fur = Paint()..color = furColor;
    final innerEar = Paint()..color = const Color(0xFFFFC5B7);
    final dark = Paint()
      ..color = const Color(0xFF293D40)
      ..style = PaintingStyle.fill;
    final nose = Paint()..color = const Color(0xFF604A4A);

    if (isDog) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(17, 48), width: 27, height: 48),
        fur,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(83, 48), width: 27, height: 48),
        fur,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(17, 50), width: 11, height: 28),
        innerEar,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(83, 50), width: 11, height: 28),
        innerEar,
      );
    } else {
      final leftEar = Path()
        ..moveTo(13, 39)
        ..lineTo(18, 5)
        ..quadraticBezierTo(19, 0, 24, 7)
        ..lineTo(39, 27)
        ..close();
      final rightEar = Path()
        ..moveTo(61, 27)
        ..lineTo(76, 7)
        ..quadraticBezierTo(81, 0, 82, 5)
        ..lineTo(87, 39)
        ..close();
      canvas.drawPath(leftEar, fur);
      canvas.drawPath(rightEar, fur);
      final leftInner = Path()
        ..moveTo(21, 27)
        ..lineTo(23, 13)
        ..lineTo(32, 27)
        ..close();
      final rightInner = Path()
        ..moveTo(68, 27)
        ..lineTo(77, 13)
        ..lineTo(79, 27)
        ..close();
      canvas.drawPath(leftInner, innerEar);
      canvas.drawPath(rightInner, innerEar);
    }

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 53), width: 70, height: 68),
      fur,
    );
    canvas.drawCircle(const Offset(37, 53), 3.2, dark);
    canvas.drawCircle(const Offset(63, 53), 3.2, dark);

    if (isDog) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 68), width: 39, height: 27),
        Paint()..color = muzzleColor,
      );
      canvas.drawCircle(const Offset(41, 66), 8, Paint()..color = muzzleColor);
      canvas.drawCircle(const Offset(59, 66), 8, Paint()..color = muzzleColor);
    } else {
      canvas.drawCircle(
        const Offset(38, 68),
        8,
        Paint()..color = const Color(0xFFFFAAA1).withValues(alpha: 0.72),
      );
      canvas.drawCircle(
        const Offset(62, 68),
        8,
        Paint()..color = const Color(0xFFFFAAA1).withValues(alpha: 0.72),
      );
    }

    final nosePath = Path()
      ..moveTo(46, 62)
      ..quadraticBezierTo(50, 59, 54, 62)
      ..lineTo(50, 67)
      ..close();
    canvas.drawPath(nosePath, nose);

    final mouthPaint = Paint()
      ..color = const Color(0xFF604A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final smile = Path()
      ..moveTo(50, 67)
      ..lineTo(50, 71)
      ..moveTo(50, 71)
      ..quadraticBezierTo(45, 76, 41, 72)
      ..moveTo(50, 71)
      ..quadraticBezierTo(55, 76, 59, 72);
    canvas.drawPath(smile, mouthPaint);

    if (isDog) {
      final spot = Paint()
        ..color = const Color(0xFFB76C45).withValues(alpha: 0.75);
      canvas.drawCircle(const Offset(74, 43), 5, spot);
      canvas.drawCircle(const Offset(70, 47), 3, spot);
    }

    canvas.restore();
  }

  /// Compares painter inputs to decide whether the custom graphic must be redrawn.
  @override
  bool shouldRepaint(covariant _PetFacePainter oldDelegate) {
    return oldDelegate.furColor != furColor ||
        oldDelegate.muzzleColor != muzzleColor ||
        oldDelegate.isDog != isDog;
  }
}

/// Displays Firebase initialization errors and a retry action.
class _StartupErrorPage extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  /// Creates the startup error view with its retry action.
  const _StartupErrorPage({required this.error, required this.onRetry});

  /// Builds the widget tree for startup error page.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'PetCare could not connect to Firebase.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
