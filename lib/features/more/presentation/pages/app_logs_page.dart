// Displays, filters, refreshes, and clears locally stored activity and error logs.

import 'package:flutter/material.dart';

import '../../../../services/audit_log_service.dart';

/// Defines the categories available for filtering activity-log entries.
enum _LogFilter { all, activity, errors }

/// Presents and manages locally stored activity and error entries.
class AppLogsPage extends StatefulWidget {
  /// Creates the screen for reviewing and filtering local app logs.
  const AppLogsPage({super.key});

  /// Creates the state that manages log loading and filtering.
  @override
  State<AppLogsPage> createState() => _AppLogsPageState();
}

/// Loads, filters, refreshes, and clears local log entries.
class _AppLogsPageState extends State<AppLogsPage> {
  final _logService = AuditLogService.instance;
  late Future<List<AuditLogEntry>> _entriesFuture;
  _LogFilter _filter = _LogFilter.all;

  /// Initializes activity log state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    _entriesFuture = _logService.getEntries();
  }

  /// Refreshes the current screen data from its local or remote source.
  void _reload() {
    setState(() => _entriesFuture = _logService.getEntries());
  }

  /// Confirms removal of all locally stored activity and error entries.
  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear activity log?'),
        content: const Text(
          'This removes all activity and error entries saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear log'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _logService.clear();
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear activity log: $error')),
      );
    }
  }

  /// Builds the widget tree for app logs page state.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity log'),
        actions: [
          IconButton(
            tooltip: 'Refresh activity log',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Clear activity log',
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<AuditLogEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LogMessageState(
              icon: Icons.error_outline_rounded,
              message: 'Could not load activity log.',
              detail: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = snapshot.data!;
          final entries = allEntries.where((entry) {
            return switch (_filter) {
              _LogFilter.all => true,
              _LogFilter.activity => entry.category == 'activity',
              _LogFilter.errors => entry.category == 'error',
            };
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: colors.primary,
                            size: 23,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Saved privately on this device. Entries are automatically removed after one month.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        _filterChip('All', _LogFilter.all, allEntries.length),
                        _filterChip(
                          'Activity',
                          _LogFilter.activity,
                          allEntries
                              .where((entry) => entry.category == 'activity')
                              .length,
                        ),
                        _filterChip(
                          'Errors',
                          _LogFilter.errors,
                          allEntries
                              .where((entry) => entry.category == 'error')
                              .length,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const _LogMessageState(
                        icon: Icons.receipt_long_outlined,
                        message: 'No entries to show',
                        detail:
                            'Changes and application errors will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _reload(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _LogEntryCard(entry: entries[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds a selectable log filter chip with its result count.
  Widget _filterChip(String label, _LogFilter filter, int count) {
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

/// Renders one activity or error log entry.
class _LogEntryCard extends StatelessWidget {
  final AuditLogEntry entry;

  /// Creates a card for one local activity or error entry.
  const _LogEntryCard({required this.entry});

  /// Builds the widget tree for log entry card.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = entry.category == 'error';
    final color = isError ? colors.error : colors.primary;
    final localTime = entry.timestamp.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(localTime);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(localTime));
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isError
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.message,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$date • $time  ·  ${entry.entity}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entry.recordId != null) ...[
              const SizedBox(height: 10),
              Text(
                'Record ID: ${entry.recordId}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (isError && entry.error != null) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                dense: true,
                title: const Text('Error details'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      [
                        entry.error!,
                        if (entry.stackTrace != null) entry.stackTrace!,
                      ].join('\n\n'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders a loading, error, or empty state for the activity log.
class _LogMessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String detail;
  final VoidCallback? onRetry;

  /// Creates a loading, error, or empty message for the log screen.
  const _LogMessageState({
    required this.icon,
    required this.message,
    required this.detail,
    this.onRetry,
  });

  /// Builds the widget tree for log message state.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
