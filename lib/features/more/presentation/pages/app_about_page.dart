// Displays PetCare application details, installed version, and open-source licenses.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Presents application version information and licenses.
class AppAboutPage extends StatelessWidget {
  /// Creates the screen that presents app information and licenses.
  const AppAboutPage({super.key});

  /// Builds the widget tree for app about page.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About PetCare')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load app information: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final info = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: colors.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 46,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      info.appName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Care made simpler.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _AboutInfoCard(
                title: 'App information',
                children: [
                  _AboutInfoRow(
                    icon: Icons.apps_rounded,
                    label: 'Application',
                    value: info.appName,
                  ),
                  _AboutInfoRow(
                    icon: Icons.sell_outlined,
                    label: 'Version',
                    value: '${info.version} (${info.buildNumber})',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: Icon(Icons.policy_outlined, color: colors.primary),
                  title: const Text(
                    'Open-source licenses',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'View licenses for the software used in this app.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: info.appName,
                    applicationVersion: '${info.version} (${info.buildNumber})',
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.pets_rounded, size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Made for the people who care for pets every day.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Groups related application information in an About screen card.
class _AboutInfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// Creates a titled card grouping related application information.
  const _AboutInfoCard({required this.title, required this.children});

  /// Builds the widget tree for about info card.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Displays one labeled application-information value.
class _AboutInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Creates a labeled row for one application-information value.
  const _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  /// Builds the widget tree for about info row.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
