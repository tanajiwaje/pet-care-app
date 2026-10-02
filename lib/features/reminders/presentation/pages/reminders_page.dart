// Manages reminder calendar and list views, reminder actions, and notifications.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/customer_search_field.dart';
import '../../../../models/customer_model.dart';
import '../../../../models/reminder_model.dart';
import '../../../../repositories/firestore_customer_repository.dart';
import '../../../../repositories/firestore_page_controller.dart';
import '../../../../repositories/firestore_reminder_repository.dart';
import '../../../../services/reminder_notification_service.dart';

/// Presents the reminder calendar, list, and reminder actions.
class RemindersPage extends StatefulWidget {
  final VoidCallback? onNotificationOpened;

  /// Creates the reminder calendar and list screen.
  const RemindersPage({super.key, this.onNotificationOpened});

  /// Creates the state that manages calendar, reminder, and notification behavior.
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

/// Manages reminder queries, calendar/list state, notifications, and reminder actions.
class _RemindersPageState extends State<RemindersPage> {
  static const _snoozeOptions = <(String, Duration)>[
    ('10 minutes', Duration(minutes: 10)),
    ('15 minutes', Duration(minutes: 15)),
    ('1 hour', Duration(hours: 1)),
    ('2 hours', Duration(hours: 2)),
    ('6 hours', Duration(hours: 6)),
    ('1 day', Duration(days: 1)),
    ('2 days', Duration(days: 2)),
  ];

  final _customerRepository = FirestoreCustomerRepository();
  final _reminderRepository = FirestoreReminderRepository();
  final _notificationService = ReminderNotificationService.instance;
  final _listSearchController = TextEditingController();
  final _reminderListScrollController = ScrollController();
  late final Stream<List<CustomerModel>> _customersStream;
  late final FirestorePageController<ReminderModel> _reminderPages;
  late final StreamSubscription<String> _notificationSubscription;
  Stream<List<ReminderModel>>? _cachedMonthRemindersStream;
  DateTime? _cachedMonth;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime? _listFilterDate;
  bool _showListView = false;
  String? _pendingNotificationReminderId;
  bool _loadingPendingNotification = false;
  String? _notificationSetupMessage;
  static const double _expandedCalendarHeight = 360;
  static const double _collapsedCalendarHeight = 78;

  /// Initializes reminder calendar and list state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    _customersStream = _customerRepository.watchCustomers();
    _reminderPages = FirestorePageController(
      fetchPage: _reminderRepository.fetchReminderPage,
    )..addListener(_onReminderPageChanged);
    _reminderListScrollController.addListener(_loadMoreRemindersNearEnd);
    _notificationSubscription = _notificationService.openedReminderIds.listen(
      _onNotificationOpened,
    );
    unawaited(_initializeNotifications());
  }

  /// Releases resources owned by reminder calendar and list, including controllers and subscriptions.
  @override
  void dispose() {
    _notificationSubscription.cancel();
    _listSearchController.dispose();
    _reminderListScrollController
      ..removeListener(_loadMoreRemindersNearEnd)
      ..dispose();
    _reminderPages
      ..removeListener(_onReminderPageChanged)
      ..dispose();
    super.dispose();
  }

  /// Refreshes the reminder list when its pagination controller changes.
  void _onReminderPageChanged() {
    if (mounted) setState(() {});
  }

  /// Requests another reminder page when scrolling close to the end of the list.
  void _loadMoreRemindersNearEnd() {
    if (!_reminderListScrollController.hasClients) return;
    if (_reminderListScrollController.position.extentAfter < 320 &&
        _reminderPages.hasMore &&
        !_reminderPages.isLoading) {
      unawaited(_reminderPages.loadMore());
    }
  }

  /// Switches between reminder calendar and list modes, loading the first list page when needed.
  void _toggleListView() {
    final showList = !_showListView;
    setState(() => _showListView = showList);
    if (showList && _reminderPages.items.isEmpty) {
      unawaited(_reminderPages.refresh());
    }
  }

  /// Returns a cached live stream for reminders scheduled during the visible month.
  Stream<List<ReminderModel>> _watchVisibleMonth() {
    final month = DateTime(_visibleMonth.year, _visibleMonth.month);
    if (_cachedMonth == month && _cachedMonthRemindersStream != null) {
      return _cachedMonthRemindersStream!;
    }
    _cachedMonth = month;
    _cachedMonthRemindersStream = _reminderRepository.watchRemindersInRange(
      start: month,
      end: DateTime(month.year, month.month + 1),
    );
    return _cachedMonthRemindersStream!;
  }

  /// Requests notification permission, publishes setup status, and delivers pending notification taps.
  Future<void> _initializeNotifications() async {
    try {
      final permissionGranted = await _notificationService.requestPermission();
      if (!mounted) return;
      setState(() {
        _notificationSetupMessage = permissionGranted
            ? null
            : 'Notifications are disabled. Tap here to allow reminder alerts in your device settings.';
      });
      _notificationService.deliverPendingReminder();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationSetupMessage =
            'Notifications could not be initialized: $error';
      });
    }
  }

  /// Requests notification permission again and updates the visible permission guidance.
  Future<void> _requestNotificationPermission() async {
    try {
      final permissionGranted = await _notificationService.requestPermission();
      if (!mounted) return;
      setState(() {
        _notificationSetupMessage = permissionGranted
            ? null
            : 'Notifications are still disabled. Enable them in your device settings to receive reminder alerts.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationSetupMessage =
            'Notification permission could not be requested: $error';
      });
    }
  }

  /// Selects the reminder tab and records the reminder ID opened from a notification.
  void _onNotificationOpened(String reminderId) {
    if (!mounted) return;
    widget.onNotificationOpened?.call();
    setState(() => _pendingNotificationReminderId = reminderId);
  }

  /// Builds the widget tree for reminders page state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton.filledTonal(
            tooltip: _showListView ? 'Show calendar' : 'Show reminder list',
            onPressed: _toggleListView,
            icon: Icon(
              _showListView
                  ? Icons.calendar_month_outlined
                  : Icons.view_agenda_outlined,
            ),
          ),
          if (!_showListView)
            IconButton(
              tooltip: 'Go to today',
              onPressed: () {
                final today = DateUtils.dateOnly(DateTime.now());
                setState(() {
                  _selectedDate = today;
                  _visibleMonth = DateTime(today.year, today.month);
                });
              },
              icon: const Icon(Icons.today_outlined),
            ),
        ],
      ),
      body: StreamBuilder<List<CustomerModel>>(
        stream: _customersStream,
        builder: (context, customerSnapshot) {
          if (customerSnapshot.hasError) {
            return _errorMessage(
              'Could not load customers: ${customerSnapshot.error}',
            );
          }
          if (!customerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = customerSnapshot.data!;
          final customerById = {for (final item in customers) item.id: item};
          return StreamBuilder<List<ReminderModel>>(
            stream: _watchVisibleMonth(),
            builder: (context, reminderSnapshot) {
              if (reminderSnapshot.hasError) {
                return _errorMessage(
                  'Could not load reminders: ${reminderSnapshot.error}',
                );
              }
              if (!reminderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final reminders = reminderSnapshot.data!;
              _openPendingNotification(reminders, customerById);
              final selectedReminders =
                  reminders
                      .where(
                        (reminder) =>
                            _sameDay(reminder.scheduledAt, _selectedDate),
                      )
                      .toList()
                    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              final query = _listSearchController.text.trim().toLowerCase();
              final listReminders =
                  _reminderPages.items.where((reminder) {
                      if (_listFilterDate != null &&
                          !_sameDay(reminder.scheduledAt, _listFilterDate!)) {
                        return false;
                      }
                      if (query.isEmpty) return true;
                      final customer = customerById[reminder.customerId];
                      final name = customer == null
                          ? ''
                          : _customerName(customer);
                      return name.toLowerCase().contains(query) ||
                          (customer?.mobile.toLowerCase().contains(query) ??
                              false) ||
                          reminder.code.toLowerCase().contains(query);
                    }).toList()
                    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              final canAddReminder = customers.any(
                (customer) => customer.isActive,
              );

              if (_showListView) {
                return _buildReminderListView(
                  reminders: listReminders,
                  hasMore: _reminderPages.hasMore,
                  isLoadingMore: _reminderPages.isLoading,
                  loadError: _reminderPages.error,
                  customerById: customerById,
                  customers: customers,
                  canAddReminder: canAddReminder,
                );
              }

              return CustomScrollView(
                slivers: [
                  if (_notificationSetupMessage != null)
                    SliverToBoxAdapter(
                      child: _notificationNotice(_notificationSetupMessage!),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ReminderCalendarHeaderDelegate(
                      expandedHeight: _expandedCalendarHeight,
                      collapsedHeight: _collapsedCalendarHeight,
                      expanded: _buildMonthHeader(reminders),
                      collapsed: _buildCollapsedDateHeader(
                        selectedReminders.length,
                      ),
                    ),
                  ),
                  if (selectedReminders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyDay(canAddReminder),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: selectedReminders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _reminderCard(
                          selectedReminders[index],
                          customerById[selectedReminders[index].customerId],
                          customers,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'reminders-add',
        onPressed: _createReminder,
        icon: const Icon(Icons.add),
        label: const Text('Reminder'),
      ),
    );
  }

  /// Builds reminder data required by reminder calendar and list.
  Future<void> _createReminder() async {
    try {
      final customers = await _customerRepository.watchCustomers().first;
      if (!mounted) return;
      await _showReminderForm(customers: customers);
    } catch (error) {
      _showMessage('Could not load customers: $error');
    }
  }

  /// Builds the reminder list view UI section using current reminder calendar and list data and state.
  Widget _buildReminderListView({
    required List<ReminderModel> reminders,
    required bool hasMore,
    required bool isLoadingMore,
    required Object? loadError,
    required Map<String, CustomerModel> customerById,
    required List<CustomerModel> customers,
    required bool canAddReminder,
  }) {
    final colors = Theme.of(context).colorScheme;
    final filterDate = _listFilterDate;
    return Column(
      children: [
        if (_notificationSetupMessage != null)
          _notificationNotice(_notificationSetupMessage!),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      filterDate == null
                          ? 'All reminders'
                          : 'Reminders by date',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${reminders.length}${hasMore ? '+' : ''}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _listSearchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search customer name, mobile, or code',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _listSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _listSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        filterDate == null
                            ? 'Filter by date'
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(filterDate),
                      ),
                      onPressed: _selectListFilterDate,
                    ),
                    if (filterDate != null)
                      ActionChip(
                        avatar: const Icon(Icons.clear_rounded),
                        label: const Text('Clear date'),
                        onPressed: () => setState(() => _listFilterDate = null),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reminderPages.refresh,
            child: ListView.separated(
              controller: _reminderListScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: reminders.isEmpty
                  ? 1 + (hasMore || isLoadingMore || loadError != null ? 1 : 0)
                  : reminders.length +
                        (hasMore || isLoadingMore || loadError != null ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (reminders.isEmpty && index == 0) {
                  return SizedBox(
                    height: 150,
                    child: _emptyReminderList(
                      canAddReminder: canAddReminder,
                      isFiltered:
                          filterDate != null ||
                          _listSearchController.text.trim().isNotEmpty,
                    ),
                  );
                }
                if (index < reminders.length) {
                  final reminder = reminders[index];
                  return _reminderCard(
                    reminder,
                    customerById[reminder.customerId],
                    customers,
                  );
                }
                if (isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (loadError != null) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => unawaited(_reminderPages.loadMore()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Could not load more. Retry'),
                    ),
                  );
                }
                return Center(
                  child: TextButton.icon(
                    onPressed: () => unawaited(_reminderPages.loadMore()),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Load more reminders'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Sets or clears the date filter used by the reminder list.
  Future<void> _selectListFilterDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _listFilterDate ?? _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10),
    );
    if (selected != null && mounted) {
      setState(() => _listFilterDate = DateUtils.dateOnly(selected));
    }
  }

  /// Builds the empty state shown when no reminders match the list filters.
  Widget _emptyReminderList({
    required bool canAddReminder,
    required bool isFiltered,
  }) {
    final colors = Theme.of(context).colorScheme;
    final message = isFiltered
        ? 'No reminders match those filters.'
        : canAddReminder
        ? 'No reminders yet. Add one to get started.'
        : 'Add a customer before creating a reminder.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.tertiaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.search_off_rounded
                    : Icons.event_available_outlined,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a visible error state for reminder calendar and list.
  Widget _errorMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Builds the reminder notification permission or setup notice.
  Widget _notificationNotice(String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: colors.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onTertiaryContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry notification setup',
            onPressed: _requestNotificationPermission,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  /// Builds the month heading and reminder count for the calendar.
  Widget _buildMonthHeader(List<ReminderModel> reminders) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _expandedCalendarHeight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMonthYear(_visibleMonth),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${_monthReminderCount(reminders)} reminders this month',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Previous month',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Next month',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: _buildCalendar(reminders)),
        ],
      ),
    );
  }

  /// Counts reminders in the visible calendar month.
  int _monthReminderCount(List<ReminderModel> reminders) {
    return reminders
        .where(
          (reminder) =>
              reminder.scheduledAt.year == _visibleMonth.year &&
              reminder.scheduledAt.month == _visibleMonth.month,
        )
        .length;
  }

  /// Moves the calendar by the requested number of months and updates the visible month.
  void _changeMonth(int increment) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + increment,
      );
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  /// Moves the selected calendar date by the requested number of days.
  void _changeSelectedDate(int increment) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(
        _selectedDate.add(Duration(days: increment)),
      );
      _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
    });
  }

  /// Builds the compact selected-date header for the collapsed calendar.
  Widget _buildCollapsedDateHeader(int selectedReminderCount) {
    final colors = Theme.of(context).colorScheme;
    final weekday = MaterialLocalizations.of(
      context,
    ).narrowWeekdays[_selectedDate.weekday % DateTime.daysPerWeek];
    return Material(
      color: colors.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_selectedDate.day}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onPrimary,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_selectedDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$selectedReminderCount ${selectedReminderCount == 1 ? 'reminder' : 'reminders'} scheduled',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Previous day',
              onPressed: () => _changeSelectedDate(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: () => _changeSelectedDate(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the interactive month calendar with booked-date markers.
  Widget _buildCalendar(List<ReminderModel> reminders) {
    final localizations = MaterialLocalizations.of(context);
    final firstDay = localizations.firstDayOfWeekIndex;
    final weekdayLabels = localizations.narrowWeekdays;
    final leadingDays =
        (DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday %
                DateTime.daysPerWeek -
            firstDay) %
        DateTime.daysPerWeek;
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final calendarWeekCount = ((leadingDays + daysInMonth + 6) ~/ 7);
    final calendarCellCount = calendarWeekCount * DateTime.daysPerWeek;
    final reminderDates = <String>{};
    for (final reminder in reminders) {
      reminderDates.add(_dateKey(reminder.scheduledAt));
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.5),
            colors.tertiary.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            children: [
              Row(
                children: List.generate(
                  DateTime.daysPerWeek,
                  (index) => Expanded(
                    child: Center(
                      child: Text(
                        weekdayLabels[(firstDay + index) %
                            DateTime.daysPerWeek],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: calendarCellCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: DateTime.daysPerWeek,
                  mainAxisExtent: 40,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - leadingDays + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month,
                    dayNumber,
                  );
                  final isToday = _sameDay(date, today);
                  final isSelected = _sameDay(date, _selectedDate);
                  final hasReminder = reminderDates.contains(_dateKey(date));
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedDate = date),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          colors.primary,
                                          colors.tertiary,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? null
                                    : hasReminder
                                    ? const Color(0xFFFFD66B)
                                    : isToday
                                    ? colors.primaryContainer
                                    : null,
                                border: Border.all(
                                  color: hasReminder && !isSelected
                                      ? const Color(0xFFDA8A00)
                                      : isToday && !isSelected
                                      ? colors.primary
                                      : Colors.transparent,
                                  width: hasReminder || isToday ? 1.5 : 0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.24,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                '$dayNumber',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: isSelected
                                          ? colors.onPrimary
                                          : hasReminder && !isSelected
                                          ? const Color(0xFF513600)
                                          : colors.onSurface,
                                      fontWeight: isToday || isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        if (isToday)
                          Positioned(
                            bottom: 2,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.tertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the calendar-day empty state and optional add-reminder action.
  Widget _emptyDay(bool canAddReminder) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              canAddReminder
                  ? 'No reminders for this date'
                  : 'Add a customer before creating a reminder.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a reminder card with its schedule, customer details, and actions.
  Widget _reminderCard(
    ReminderModel reminder,
    CustomerModel? customer,
    List<CustomerModel> customers,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isStopped = reminder.status == 'stopped';
    final statusColor = isStopped
        ? colors.onSurfaceVariant
        : reminder.status == 'snoozed'
        ? const Color(0xFFB76516)
        : colors.primary;
    final customerName = customer == null
        ? 'Customer unavailable'
        : _customerName(customer);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.55),
            colors.tertiary.withValues(alpha: 0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 5, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primaryContainer.withValues(alpha: 0.82),
                    colors.tertiaryContainer.withValues(alpha: 0.62),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.alarm_rounded, color: statusColor),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.code.isEmpty ? 'Reminder' : reminder.code,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(reminder.scheduledAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TimeOfDay.fromDateTime(
                            reminder.scheduledAt,
                          ).format(context),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          reminder.status.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                fontSize: 9,
                              ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Reminder options',
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _showReminderForm(
                            customers: customers,
                            reminder: reminder,
                          );
                          break;
                        case 'snooze':
                          _chooseSnooze(reminder, customer);
                          break;
                        case 'stop':
                          _confirmStop(reminder);
                          break;
                        case 'delete':
                          _deleteReminder(reminder);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit reminder'),
                      ),
                      if (!isStopped)
                        const PopupMenuItem(
                          value: 'snooze',
                          child: Text('Snooze'),
                        ),
                      if (!isStopped)
                        const PopupMenuItem(
                          value: 'stop',
                          child: Text('Stop notifications'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete reminder'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.secondaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          size: 19,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          customerName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  if (customer != null &&
                      (customer.mobile.isNotEmpty ||
                          customer.address.isNotEmpty)) ...[
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.only(left: 46),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (customer.mobile.isNotEmpty)
                            _reminderDetail(
                              Icons.phone_outlined,
                              customer.mobile,
                            ),
                          if (customer.address.isNotEmpty)
                            _reminderDetail(
                              Icons.location_on_outlined,
                              customer.address,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays one labeled reminder detail row with its icon.
  Widget _reminderDetail(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// Opens the reminder create/edit form and saves the selected schedule.
  Future<void> _showReminderForm({
    required List<CustomerModel> customers,
    ReminderModel? reminder,
  }) async {
    if (reminder != null &&
        !customers.any((customer) => customer.id == reminder.customerId)) {
      _showMessage(
        'The linked customer could not be found. The reminder cannot be edited.',
      );
      return;
    }
    final availableCustomers = customers
        .where(
          (customer) =>
              customer.isActive || customer.id == reminder?.customerId,
        )
        .toList();
    if (availableCustomers.isEmpty) {
      _showMessage('Add an active customer before creating a reminder.');
      return;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    var selectedCustomerId =
        availableCustomers.any(
          (customer) => customer.id == reminder?.customerId,
        )
        ? reminder!.customerId
        : availableCustomers.first.id;
    var selectedDate = DateUtils.dateOnly(
      reminder?.scheduledAt ?? _selectedDate,
    );
    if (selectedDate.isBefore(today)) selectedDate = today;
    var selectedTime = reminder == null
        ? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)))
        : TimeOfDay.fromDateTime(reminder.scheduledAt);
    String? validationError;

    final draft = await showDialog<_ReminderDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(reminder == null ? 'Add reminder' : 'Edit reminder'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomerSearchField(
                    customers: availableCustomers,
                    selectedCustomerId: selectedCustomerId,
                    onChanged: (value) {
                      setDialogState(() => selectedCustomerId = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: today,
                        lastDate: DateTime(today.year + 5),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = DateUtils.dateOnly(picked);
                          validationError = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      MaterialLocalizations.of(
                        dialogContext,
                      ).formatMediumDate(selectedDate),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                          validationError = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(selectedTime.format(dialogContext)),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'A notification will be scheduled one hour before the reminder.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final scheduledAt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                if (!scheduledAt.isAfter(DateTime.now())) {
                  setDialogState(
                    () => validationError =
                        'Choose a future date and time for this reminder.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _ReminderDraft(
                    customerId: selectedCustomerId,
                    scheduledAt: scheduledAt,
                  ),
                );
              },
              child: Text(reminder == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (draft == null || !mounted) return;
    final selectedCustomer = availableCustomers.firstWhere(
      (customer) => customer.id == draft.customerId,
    );
    var notificationsAllowed = false;
    try {
      notificationsAllowed = await _notificationService.requestPermission();
      if (mounted) {
        setState(() {
          _notificationSetupMessage = notificationsAllowed
              ? null
              : 'Notifications are disabled. Reminders will be saved without an alert until you enable notifications.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _notificationSetupMessage =
              'Reminder notifications could not be enabled: $error';
        });
      }
    }
    try {
      final reminderId = reminder == null
          ? await _reminderRepository.addReminder(
              customerId: draft.customerId,
              scheduledAt: draft.scheduledAt,
            )
          : reminder.id;
      if (reminder != null) {
        await _reminderRepository.updateReminder(
          id: reminderId,
          customerId: draft.customerId,
          scheduledAt: draft.scheduledAt,
        );
      }
      if (_showListView) await _reminderPages.refresh();
      if (!mounted) return;
      setState(() {
        _selectedDate = DateUtils.dateOnly(draft.scheduledAt);
        _visibleMonth = DateTime(
          draft.scheduledAt.year,
          draft.scheduledAt.month,
        );
      });
      if (!notificationsAllowed) {
        _showMessage(
          reminder == null
              ? 'Reminder created, but notifications are disabled.'
              : 'Reminder updated, but notifications are disabled.',
        );
        return;
      }
      try {
        final scheduled = await _notificationService.schedule(
          reminderId: reminderId,
          customerName: _customerName(selectedCustomer),
          customerMobile: selectedCustomer.mobile,
          customerAddress: selectedCustomer.address,
          scheduledAt: draft.scheduledAt,
          notifyAt: draft.scheduledAt.subtract(const Duration(hours: 1)),
        );
        _showMessage(
          scheduled
              ? reminder == null
                    ? 'Reminder created.'
                    : 'Reminder updated.'
              : 'Reminder saved, but notifications are disabled on this device.',
        );
      } catch (error) {
        _showMessage(
          'Reminder saved, but its notification could not be scheduled: $error',
        );
      }
    } catch (error) {
      _showMessage('Could not save the reminder: $error');
    }
  }

  /// Lets the user select a snooze duration for the reminder.
  Future<void> _chooseSnooze(
    ReminderModel reminder,
    CustomerModel? customer,
  ) async {
    final availableOptions = _availableSnoozeOptions(reminder);
    if (availableOptions.isEmpty) {
      _showMessage(
        'This reminder is too close to its scheduled time to snooze.',
      );
      return;
    }
    final choice = await showModalBottomSheet<(String, DateTime)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Snooze reminder',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ...availableOptions.map(
              (option) => ListTile(
                leading: const Icon(Icons.snooze_outlined),
                title: Text(option.$1),
                onTap: () => Navigator.pop(sheetContext, option),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _applySnooze(
      reminder,
      customer,
      notifyAt: choice.$2,
      label: choice.$1,
    );
  }

  /// Confirms stopping the reminder and updates its notification schedule.
  Future<void> _confirmStop(ReminderModel reminder) async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop notifications?'),
        content: const Text(
          'This keeps the reminder on the calendar but stops its alert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (shouldStop != true || !mounted) return;
    try {
      await _reminderRepository.stopReminder(reminder.id);
      if (_showListView) await _reminderPages.refresh();
    } catch (error) {
      _showMessage('Could not stop the reminder: $error');
      return;
    }
    try {
      await _notificationService.cancel(reminder.id);
      _showMessage('Reminder notifications stopped.');
    } catch (error) {
      _showMessage(
        'The reminder was stopped, but its local notification could not be cancelled: $error',
      );
    }
  }

  /// Confirms deletion and removes the reminder and its scheduled notification.
  Future<void> _deleteReminder(ReminderModel reminder) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete reminder?',
      message:
          'Delete ${reminder.code.isEmpty ? 'this reminder' : reminder.code}? This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _reminderRepository.deleteReminder(reminder.id);
      if (_showListView) await _reminderPages.refresh();
    } catch (error) {
      _showMessage('Could not delete the reminder: $error');
      return;
    }
    try {
      await _notificationService.cancel(reminder.id);
      _showMessage('Reminder deleted.');
    } catch (error) {
      _showMessage(
        'The reminder was deleted, but its local notification could not be cancelled: $error',
      );
    }
  }

  /// Opens a notification target once its reminder data is available.
  void _openPendingNotification(
    List<ReminderModel> reminders,
    Map<String, CustomerModel> customerById,
  ) {
    final reminderId = _pendingNotificationReminderId;
    if (reminderId == null || _loadingPendingNotification) return;
    ReminderModel? reminder;
    for (final item in reminders) {
      if (item.id == reminderId) {
        reminder = item;
        break;
      }
    }
    if (reminder == null) {
      _loadingPendingNotification = true;
      unawaited(_loadPendingNotification(reminderId, customerById));
      return;
    }
    final selectedReminder = reminder;
    _pendingNotificationReminderId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showAlarmActions(
          selectedReminder,
          customerById[selectedReminder.customerId],
        );
      }
    });
  }

  /// Fetches a notification-targeted reminder outside the currently loaded month.
  Future<void> _loadPendingNotification(
    String reminderId,
    Map<String, CustomerModel> customerById,
  ) async {
    try {
      final reminder = await _reminderRepository.getReminder(reminderId);
      if (!mounted) return;
      _pendingNotificationReminderId = null;
      if (reminder == null) {
        _showMessage('This reminder no longer exists.');
        return;
      }
      setState(() {
        _selectedDate = DateUtils.dateOnly(reminder.scheduledAt);
        _visibleMonth = DateTime(
          reminder.scheduledAt.year,
          reminder.scheduledAt.month,
        );
        _cachedMonth = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAlarmActions(reminder, customerById[reminder.customerId]);
        }
      });
    } catch (error) {
      if (!mounted) return;
      _pendingNotificationReminderId = null;
      _showMessage('Could not load the opened reminder: $error');
    } finally {
      _loadingPendingNotification = false;
    }
  }

  /// Presents available actions for a reminder opened from an alarm notification.
  Future<void> _showAlarmActions(
    ReminderModel reminder,
    CustomerModel? customer,
  ) async {
    final snoozeOptions = _availableSnoozeOptions(reminder);
    final action = await showDialog<_AlarmChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Reminder alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${customer == null ? 'Customer' : _customerName(customer)} · ${TimeOfDay.fromDateTime(reminder.scheduledAt).format(context)}',
            ),
            if (snoozeOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Snooze for',
                style: Theme.of(dialogContext).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: snoozeOptions
                    .map(
                      (option) => ActionChip(
                        label: Text(option.$1),
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          _AlarmChoice.snooze(option.$1, option.$2),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text('No snooze time remains before this reminder.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, const _AlarmChoice.stop()),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action.shouldStop) {
      try {
        await _reminderRepository.stopReminder(reminder.id);
      } catch (error) {
        _showMessage('Could not stop the reminder: $error');
        return;
      }
      try {
        await _notificationService.cancel(reminder.id);
        _showMessage('Reminder notifications stopped.');
      } catch (error) {
        _showMessage(
          'The reminder was stopped, but its local notification could not be cancelled: $error',
        );
      }
    } else if (action.notifyAt != null) {
      await _applySnooze(
        reminder,
        customer,
        notifyAt: action.notifyAt!,
        label: action.label!,
      );
    }
  }

  /// Returns valid snooze choices based on the reminder schedule.
  List<(String, DateTime)> _availableSnoozeOptions(ReminderModel reminder) {
    final now = DateTime.now();
    final options = _snoozeOptions
        .map((option) => (option.$1, now.add(option.$2)))
        .where((option) => option.$2.isBefore(reminder.scheduledAt))
        .toList();
    if (reminder.scheduledAt.isAfter(now)) {
      options.add(('At appointment time', reminder.scheduledAt));
    }
    return options;
  }

  /// Updates the reminder snooze time and reschedules its local notification.
  Future<void> _applySnooze(
    ReminderModel reminder,
    CustomerModel? customer, {
    required DateTime notifyAt,
    required String label,
  }) async {
    try {
      await _reminderRepository.snoozeReminder(
        id: reminder.id,
        notifyAt: notifyAt,
      );
    } catch (error) {
      _showMessage('Could not snooze the reminder: $error');
      return;
    }
    try {
      final scheduled = await _notificationService.schedule(
        reminderId: reminder.id,
        customerName: customer == null ? 'Customer' : _customerName(customer),
        customerMobile: customer?.mobile ?? '',
        customerAddress: customer?.address ?? '',
        scheduledAt: reminder.scheduledAt,
        notifyAt: notifyAt,
      );
      _showMessage(
        scheduled
            ? 'Reminder snoozed until $label.'
            : 'Reminder snoozed, but notifications are disabled on this device.',
      );
    } catch (error) {
      _showMessage(
        'Reminder snoozed, but its notification could not be scheduled: $error',
      );
    }
  }

  /// Combines a customer first and last name into a display label.
  String _customerName(CustomerModel customer) {
    return '${customer.firstName} ${customer.lastName}'.trim();
  }

  /// Creates a stable year-month-day key for grouping calendar dates.
  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  /// Compares two dates by year, month, and day, ignoring their times.
  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  /// Displays a brief user-facing status or validation message.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Holds validated reminder form values before saving.
class _ReminderDraft {
  final String customerId;
  final DateTime scheduledAt;

  /// Holds a customer's chosen schedule and notification timing before saving.
  const _ReminderDraft({required this.customerId, required this.scheduledAt});
}

/// Represents one selectable alarm timing option.
class _AlarmChoice {
  final String? label;
  final DateTime? notifyAt;
  final bool shouldStop;

  const _AlarmChoice.snooze(this.label, this.notifyAt) : shouldStop = false;

  const _AlarmChoice.stop() : label = null, notifyAt = null, shouldStop = true;
}

/// Builds the reminder calendar header in expanded and collapsed states.
class _ReminderCalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final double collapsedHeight;
  final Widget expanded;
  final Widget collapsed;

  /// Configures the expanded and collapsed calendar header contents and heights.
  const _ReminderCalendarHeaderDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.expanded,
    required this.collapsed,
  });

  /// Minimum header extent used while the calendar is collapsed.
  @override
  double get minExtent => collapsedHeight;

  /// Maximum header extent used while the calendar is expanded.
  @override
  double get maxExtent => expandedHeight + collapsedHeight;

  /// Builds the widget tree for reminder calendar header delegate.
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final expandedPortion = (expandedHeight - shrinkOffset).clamp(
      0.0,
      expandedHeight,
    );
    final expansion = expandedPortion / expandedHeight;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: expandedPortion,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: expandedHeight,
                maxHeight: expandedHeight,
                child: Opacity(
                  opacity: expansion,
                  child: IgnorePointer(
                    ignoring: expansion < 0.95,
                    child: expanded,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: collapsedHeight, child: collapsed),
        ],
      ),
    );
  }

  /// Rebuilds the calendar header when its size or selected state changes.
  @override
  bool shouldRebuild(covariant _ReminderCalendarHeaderDelegate oldDelegate) {
    return expandedHeight != oldDelegate.expandedHeight ||
        collapsedHeight != oldDelegate.collapsedHeight ||
        expanded != oldDelegate.expanded ||
        collapsed != oldDelegate.collapsed;
  }
}
