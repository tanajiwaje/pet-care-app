// Builds the Home overview, upcoming reminder agenda, and business insights.

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../../models/customer_model.dart';
import '../../../../models/payment_model.dart';
import '../../../../models/reminder_model.dart';
import '../../../../models/visit_model.dart';
import '../../../../repositories/firestore_customer_repository.dart';
import '../../../../repositories/firestore_reminder_repository.dart';
import '../../../../repositories/firestore_visit_repository.dart';

/// Presents the business overview, upcoming reminder agenda, and insights.
class PetHomePage extends StatefulWidget {
  final VoidCallback? onOpenReminders;
  final VoidCallback? onOpenVisits;

  /// Creates the Home dashboard with optional reminder and visit navigation callbacks.
  const PetHomePage({super.key, this.onOpenReminders, this.onOpenVisits});

  /// Creates the state that loads Home dashboard and insight data.
  @override
  State<PetHomePage> createState() => _PetHomePageState();
}

/// Loads dashboard data and manages overview and insight filters.
class _PetHomePageState extends State<PetHomePage> {
  final _visitRepository = FirestoreVisitRepository();
  final _reminderRepository = FirestoreReminderRepository();
  final _customerRepository = FirestoreCustomerRepository();
  final _insightSearchController = TextEditingController();
  int _selectedSection = 0;
  _InsightPeriod _insightPeriod = _InsightPeriod.today;
  _InsightChartMetric _chartMetric = _InsightChartMetric.amount;
  DateTimeRange? _customInsightRange;

  late final Stream<List<VisitModel>> _visitsStream;
  late final Stream<List<PaymentModel>> _paymentsStream;
  late final Stream<List<ReminderModel>> _remindersStream;
  late final Stream<List<CustomerModel>> _customersStream;

  /// Initializes Home overview and Insights state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _visitsStream = _visitRepository.watchVisits();
    _paymentsStream = _visitRepository.watchPayments();
    _remindersStream = _reminderRepository.watchRemindersInRange(
      start: today,
      end: today.add(const Duration(days: 2)),
    );
    _customersStream = _customerRepository.watchCustomers();
  }

  /// Releases resources owned by Home overview and Insights, including controllers and subscriptions.
  @override
  void dispose() {
    _insightSearchController.dispose();
    super.dispose();
  }

  /// Builds the widget tree for pet home page state.
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetCare'),
        actions: [
          IconButton(
            tooltip: 'Open reminders',
            onPressed: widget.onOpenReminders,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<VisitModel>>(
        stream: _visitsStream,
        builder: (context, visitsSnapshot) {
          if (visitsSnapshot.hasError) {
            return _errorState(
              'Could not load visits: ${visitsSnapshot.error}',
            );
          }
          return StreamBuilder<List<PaymentModel>>(
            stream: _paymentsStream,
            builder: (context, paymentsSnapshot) {
              if (paymentsSnapshot.hasError) {
                return _errorState(
                  'Could not load payments: ${paymentsSnapshot.error}',
                );
              }
              return StreamBuilder<List<ReminderModel>>(
                stream: _remindersStream,
                builder: (context, remindersSnapshot) {
                  if (remindersSnapshot.hasError) {
                    return _errorState(
                      'Could not load reminders: ${remindersSnapshot.error}',
                    );
                  }
                  return StreamBuilder<List<CustomerModel>>(
                    stream: _customersStream,
                    builder: (context, customersSnapshot) {
                      if (customersSnapshot.hasError) {
                        return _errorState(
                          'Could not load customers: ${customersSnapshot.error}',
                        );
                      }
                      if (!visitsSnapshot.hasData ||
                          !paymentsSnapshot.hasData ||
                          !remindersSnapshot.hasData ||
                          !customersSnapshot.hasData) {
                        return _loadingState();
                      }
                      return _buildDashboard(
                        visits: visitsSnapshot.data!,
                        payments: paymentsSnapshot.data!,
                        reminders: remindersSnapshot.data!,
                        customers: customersSnapshot.data!,
                        today: today,
                        tomorrow: tomorrow,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Calculates Home KPIs and builds the overview and reminder agenda.
  Widget _buildDashboard({
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
    required List<ReminderModel> reminders,
    required List<CustomerModel> customers,
    required DateTime today,
    required DateTime tomorrow,
  }) {
    final todayVisits = visits
        .where((visit) => _sameDay(visit.visitDate, today))
        .toList();
    final todayPayments = payments
        .where((payment) => _sameDay(payment.paymentDate, today))
        .toList();
    final totalAmount = todayVisits.fold<double>(
      0,
      (sum, visit) => sum + visit.actualAmount,
    );
    final paidAmount = todayPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final paymentsByVisit = <String, double>{};
    for (final payment in payments) {
      paymentsByVisit.update(
        payment.visitId,
        (amount) => amount + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    final pendingAmount = todayVisits.fold<double>(0, (sum, visit) {
      final pending = (visit.actualAmount - (paymentsByVisit[visit.id] ?? 0))
          .clamp(0, double.infinity)
          .toDouble();
      return sum + pending;
    });
    final customerById = {
      for (final customer in customers) customer.id: customer,
    };
    final todayReminders = _remindersForDate(reminders, today);
    final tomorrowReminders = _remindersForDate(reminders, tomorrow);

    if (_selectedSection == 1) {
      return _buildInsights(
        visits: visits,
        payments: payments,
        customers: customers,
        today: today,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _buildWelcomeCard(today),
        const SizedBox(height: 18),
        _buildSectionSwitcher(),
        const SizedBox(height: 20),
        _sectionHeading(
          context,
          title: "Today's overview",
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 12),
        _buildMetricGrid(
          context,
          visitsCount: todayVisits.length,
          paymentsCount: todayPayments.length,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          pendingAmount: pendingAmount,
        ),
        const SizedBox(height: 24),
        _buildAgendaHeader(todayReminders.length + tomorrowReminders.length),
        const SizedBox(height: 12),
        _buildAgendaSection(
          title: 'Today',
          date: today,
          reminders: todayReminders,
          customerById: customerById,
          onViewAll: widget.onOpenReminders,
        ),
        const SizedBox(height: 14),
        _buildAgendaSection(
          title: 'Tomorrow',
          date: tomorrow,
          reminders: tomorrowReminders,
          customerById: customerById,
          onViewAll: widget.onOpenReminders,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Builds the time-sensitive Home welcome card.
  Widget _buildWelcomeCard(DateTime today) {
    final colors = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : hour < 21
        ? 'Good evening'
        : 'Good night';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Care starts here.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  MaterialLocalizations.of(context).formatFullDate(today),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.pets_rounded, size: 38, color: colors.onPrimary),
          ),
        ],
      ),
    );
  }

  /// Builds the section switcher UI section using current Home overview and Insights data and state.
  Widget _buildSectionSwitcher() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _sectionTab(
            icon: Icons.dashboard_rounded,
            label: 'Overview',
            index: 0,
          ),
          _sectionTab(
            icon: Icons.insights_rounded,
            label: 'Insights',
            index: 1,
          ),
        ],
      ),
    );
  }

  /// Builds a selectable Home section tab.
  Widget _sectionTab({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedSection == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => setState(() => _selectedSection = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a section heading with supporting text and icon.
  Widget _sectionHeading(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Arranges today?s visit and payment KPIs in a responsive grid.
  Widget _buildMetricGrid(
    BuildContext context, {
    required int visitsCount,
    required int paymentsCount,
    required double totalAmount,
    required double paidAmount,
    required double pendingAmount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: 'Visits',
                value: '$visitsCount',
                caption: 'scheduled today',
                icon: Icons.event_available_rounded,
                color: const Color(0xFF3977C3),
                onTap: widget.onOpenVisits,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _metricCard(
                title: 'Payments',
                value: '$paymentsCount',
                caption: 'received today',
                icon: Icons.payments_rounded,
                color: const Color(0xFF8A58B5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: 'Visit total',
                value: _money(totalAmount),
                caption: 'billed today',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF167D82),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _metricCard(
                title: 'Collected',
                value: _money(paidAmount),
                caption: 'paid today',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF21805F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        _metricCard(
          title: "Today's pending",
          value: _money(pendingAmount),
          caption: 'remaining on visits scheduled today',
          icon: Icons.hourglass_bottom_rounded,
          color: const Color(0xFFB76516),
          wide: true,
        ),
      ],
    );
  }

  /// Displays one Home KPI value with its label and visual treatment.
  Widget _metricCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
    bool wide = false,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: color.withValues(alpha: 0.17)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (wide)
                Icon(
                  Icons.trending_down_rounded,
                  color: color.withValues(alpha: 0.65),
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the agenda header UI section using current Home overview and Insights data and state.
  Widget _buildAgendaHeader(int reminderCount) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.notifications_active_outlined,
            color: colors.tertiary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your agenda',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Today and tomorrow',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (widget.onOpenReminders != null)
          TextButton(
            onPressed: widget.onOpenReminders,
            child: const Text('All reminders'),
          ),
        if (widget.onOpenReminders == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$reminderCount',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onTertiaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds one day of the Home reminder agenda with a limited record list.
  Widget _buildAgendaSection({
    required String title,
    required DateTime date,
    required List<ReminderModel> reminders,
    required Map<String, CustomerModel> customerById,
    required VoidCallback? onViewAll,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accent = title == 'Today'
        ? const Color(0xFF167D82)
        : const Color(0xFF6657B8);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: accent.withValues(alpha: 0.19)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(date),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${reminders.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No reminders planned',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ...reminders.map(
              (reminder) => _agendaReminderRow(
                reminder,
                customerById[reminder.customerId],
                accent,
                isLast: reminder == reminders.last,
                onTap: onViewAll,
              ),
            ),
        ],
      ),
    );
  }

  /// Displays a reminder in the Home agenda with customer and time details.
  Widget _agendaReminderRow(
    ReminderModel reminder,
    CustomerModel? customer,
    Color accent, {
    required bool isLast,
    required VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final name = customer == null
        ? 'Customer unavailable'
        : _customerName(customer);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (customer != null && customer.mobile.isNotEmpty)
                    Text(
                      customer.mobile,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    reminder.code.isEmpty ? 'Reminder' : reminder.code,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                TimeOfDay.fromDateTime(reminder.scheduledAt).format(context),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filters business records and builds the Home KPI chart for the chosen period.
  Widget _buildInsights({
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
    required List<CustomerModel> customers,
    required DateTime today,
  }) {
    final range = _insightDateRange(today);
    final normalizedQuery = _insightSearchController.text.trim().toLowerCase();
    final matchingCustomerIds = normalizedQuery.isEmpty
        ? null
        : customers
              .where(
                (customer) =>
                    _customerName(
                      customer,
                    ).toLowerCase().contains(normalizedQuery) ||
                    customer.mobile.toLowerCase().contains(normalizedQuery),
              )
              .map((customer) => customer.id)
              .toSet();
    final filteredVisits = visits.where((visit) {
      return _inRange(visit.visitDate, range) &&
          (matchingCustomerIds == null ||
              matchingCustomerIds.contains(visit.customerId));
    }).toList();
    final filteredPayments = payments.where((payment) {
      return _inRange(payment.paymentDate, range) &&
          (matchingCustomerIds == null ||
              matchingCustomerIds.contains(payment.customerId));
    }).toList();

    final billed = filteredVisits.fold<double>(
      0,
      (total, visit) => total + visit.actualAmount,
    );
    final collected = filteredPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    final allPaymentsByVisit = <String, double>{};
    for (final payment in payments) {
      allPaymentsByVisit.update(
        payment.visitId,
        (total) => total + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    final pending = filteredVisits.fold<double>(0, (total, visit) {
      final remaining =
          (visit.actualAmount - (allPaymentsByVisit[visit.id] ?? 0))
              .clamp(0, double.infinity)
              .toDouble();
      return total + remaining;
    });
    final customerCount = filteredVisits
        .map((visit) => visit.customerId)
        .toSet()
        .length;
    final buckets = _createInsightBuckets(range);
    for (final visit in filteredVisits) {
      final index = _bucketIndex(buckets, visit.visitDate);
      if (index != -1) {
        buckets[index].visits++;
        buckets[index].billed += visit.actualAmount;
      }
    }
    for (final payment in filteredPayments) {
      final index = _bucketIndex(buckets, payment.paymentDate);
      if (index != -1) {
        buckets[index].payments++;
        buckets[index].collected += payment.amount;
      }
    }
    final rangeLabel = _formatRange(range);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        _buildWelcomeCard(today),
        const SizedBox(height: 18),
        _buildSectionSwitcher(),
        const SizedBox(height: 22),
        _sectionHeading(
          context,
          title: 'Business insights',
          subtitle: 'Track visits, payments, and outstanding balances',
          icon: Icons.query_stats_rounded,
        ),
        const SizedBox(height: 14),
        _buildInsightFilters(rangeLabel),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _insightKpi(
                title: 'Visits',
                value: '${filteredVisits.length}',
                caption: 'in selected period',
                icon: Icons.event_available_rounded,
                color: const Color(0xFF3977C3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _insightKpi(
                title: 'Payments',
                value: '${filteredPayments.length}',
                caption: 'entries received',
                icon: Icons.payments_rounded,
                color: const Color(0xFF8A58B5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _insightKpi(
                title: 'Billed',
                value: _money(billed),
                caption: 'from selected visits',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF167D82),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _insightKpi(
                title: 'Collected',
                value: _money(collected),
                caption: 'payments in period',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF21805F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _insightKpi(
                title: 'Pending',
                value: _money(pending),
                caption: 'on selected visits',
                icon: Icons.hourglass_bottom_rounded,
                color: const Color(0xFFB76516),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _insightKpi(
                title: 'Customers',
                value: '$customerCount',
                caption: 'with visits in period',
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF6657B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildInsightChart(
          buckets: buckets,
          rangeLabel: rangeLabel,
          customerSearchActive: matchingCustomerIds != null,
        ),
        const SizedBox(height: 16),
        _buildInsightNote(),
      ],
    );
  }

  /// Builds date-range, search, and chart-metric controls for Insights.
  Widget _buildInsightFilters(String rangeLabel) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT PERIOD',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _periodChoice(_InsightPeriod.today, 'Today'),
                _periodChoice(_InsightPeriod.month, 'This month'),
                _periodChoice(_InsightPeriod.year, 'This year'),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 17),
                  label: Text(
                    _insightPeriod == _InsightPeriod.custom
                        ? 'Custom'
                        : 'Custom dates',
                  ),
                  onPressed: _pickInsightDateRange,
                ),
              ],
            ),
          ),
          if (_insightPeriod == _InsightPeriod.custom) ...[
            const SizedBox(height: 5),
            Text(
              rangeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _insightSearchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Filter by customer name or mobile',
              prefixIcon: const Icon(Icons.person_search_rounded),
              suffixIcon: _insightSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear customer filter',
                      onPressed: () {
                        _insightSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              isDense: true,
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a selectable date-period option for Home Insights.
  Widget _periodChoice(_InsightPeriod period, String label) {
    final selected = _insightPeriod == period;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _insightPeriod = period),
        selectedColor: colors.primaryContainer,
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: 0.4)
              : colors.outlineVariant,
        ),
      ),
    );
  }

  /// Opens the insight date range picker and returns the user selection.
  Future<void> _pickInsightDateRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final currentRange = _customInsightRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10),
      initialDateRange: currentRange ?? DateTimeRange(start: today, end: today),
      helpText: 'Select insight date range',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customInsightRange = DateTimeRange(
        start: DateUtils.dateOnly(picked.start),
        end: DateUtils.dateOnly(picked.end),
      );
      _insightPeriod = _InsightPeriod.custom;
    });
  }

  /// Builds one insight KPI card with its title, value, and supporting detail.
  Widget _insightKpi({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the chart for the selected metric and date range.
  Widget _buildInsightChart({
    required List<_InsightBucket> buckets,
    required String rangeLabel,
    required bool customerSearchActive,
  }) {
    final colors = Theme.of(context).colorScheme;
    final firstColor = _chartMetric == _InsightChartMetric.amount
        ? const Color(0xFF167D82)
        : const Color(0xFF3977C3);
    final secondColor = _chartMetric == _InsightChartMetric.amount
        ? const Color(0xFF8A58B5)
        : const Color(0xFF21805F);
    final firstLabel = _chartMetric == _InsightChartMetric.amount
        ? 'Billed'
        : 'Visits';
    final secondLabel = _chartMetric == _InsightChartMetric.amount
        ? 'Collected'
        : 'Payments';
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customerSearchActive
                          ? 'Filtered customer · $rangeLabel'
                          : rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.auto_graph_rounded, color: Color(0xFF6657B8)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<_InsightChartMetric>(
            segments: const [
              ButtonSegment(
                value: _InsightChartMetric.amount,
                icon: Icon(Icons.attach_money_rounded),
                label: Text('Amounts'),
              ),
              ButtonSegment(
                value: _InsightChartMetric.count,
                icon: Icon(Icons.numbers_rounded),
                label: Text('Counts'),
              ),
            ],
            selected: {_chartMetric},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _chartMetric = selection.first);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 7,
            children: [
              _chartLegend(firstColor, firstLabel),
              _chartLegend(secondColor, secondLabel),
            ],
          ),
          const SizedBox(height: 12),
          if (buckets.every((bucket) => bucket.isEmpty))
            SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  'No data for this period and customer filter.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                painter: _InsightBarChartPainter(
                  buckets: buckets,
                  showAmounts: _chartMetric == _InsightChartMetric.amount,
                  firstColor: firstColor,
                  secondColor: secondColor,
                  labelColor: colors.onSurfaceVariant,
                  gridColor: colors.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Displays the color key for one chart series.
  Widget _chartLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

  /// Builds the insight note UI section using current Home overview and Insights data and state.
  Widget _buildInsightNote() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Pending is calculated for visits in the selected period using all payments linked to each visit. Collected shows payments received during that period.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the active today, month, year, or custom Insights date range.
  DateTimeRange _insightDateRange(DateTime today) {
    switch (_insightPeriod) {
      case _InsightPeriod.today:
        return DateTimeRange(start: today, end: today);
      case _InsightPeriod.month:
        return DateTimeRange(
          start: DateTime(today.year, today.month),
          end: DateTime(today.year, today.month + 1, 0),
        );
      case _InsightPeriod.year:
        return DateTimeRange(
          start: DateTime(today.year),
          end: DateTime(today.year, 12, 31),
        );
      case _InsightPeriod.custom:
        return _customInsightRange ?? DateTimeRange(start: today, end: today);
    }
  }

  /// Creates the date buckets used to aggregate chart values across the selected range.
  List<_InsightBucket> _createInsightBuckets(DateTimeRange range) {
    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);
    if (_insightPeriod == _InsightPeriod.today) {
      return [
        _InsightBucket('12a', start, start.add(const Duration(hours: 6))),
        _InsightBucket(
          '6a',
          start.add(const Duration(hours: 6)),
          start.add(const Duration(hours: 12)),
        ),
        _InsightBucket(
          '12p',
          start.add(const Duration(hours: 12)),
          start.add(const Duration(hours: 18)),
        ),
        _InsightBucket(
          '6p',
          start.add(const Duration(hours: 18)),
          start.add(const Duration(days: 1)),
        ),
      ];
    }
    if (_insightPeriod == _InsightPeriod.year) {
      return List.generate(12, (index) {
        final monthStart = DateTime(start.year, index + 1);
        return _InsightBucket(
          MaterialLocalizations.of(
            context,
          ).formatMonthYear(monthStart).split(' ').first,
          monthStart,
          DateTime(start.year, index + 2),
        );
      });
    }
    final daySpan = end.difference(start).inDays + 1;
    final bucketDays = _insightPeriod == _InsightPeriod.month
        ? 7
        : daySpan <= 14
        ? 1
        : daySpan <= 90
        ? 7
        : 30;
    final bucketCount = (daySpan / bucketDays).ceil().clamp(1, 12);
    return List.generate(bucketCount, (index) {
      final bucketStart = start.add(Duration(days: index * bucketDays));
      final bucketEnd = bucketStart.add(Duration(days: bucketDays));
      final effectiveEnd = bucketEnd.isAfter(end.add(const Duration(days: 1)))
          ? end.add(const Duration(days: 1))
          : bucketEnd;
      final label = bucketDays == 1
          ? '${bucketStart.day}/${bucketStart.month}'
          : _insightPeriod == _InsightPeriod.month
          ? '${bucketStart.day}-${effectiveEnd.subtract(const Duration(days: 1)).day}'
          : MaterialLocalizations.of(context).formatShortDate(bucketStart);
      return _InsightBucket(label, bucketStart, effectiveEnd);
    });
  }

  /// Finds the chart bucket containing the supplied date.
  int _bucketIndex(List<_InsightBucket> buckets, DateTime date) {
    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      if (!date.isBefore(bucket.start) && date.isBefore(bucket.end)) {
        return index;
      }
    }
    return -1;
  }

  /// Checks whether a date lies within the selected date range.
  bool _inRange(DateTime date, DateTimeRange range) {
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(DateUtils.dateOnly(range.start)) &&
        !day.isAfter(DateUtils.dateOnly(range.end));
  }

  /// Formats range for display.
  String _formatRange(DateTimeRange range) {
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatMediumDate(range.start);
    final end = localizations.formatMediumDate(range.end);
    return _sameDay(range.start, range.end) ? start : '$start – $end';
  }

  /// Builds the progress state shown while required screen data is loading.
  Widget _loadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  /// Builds a visible error state with the reported failure details.
  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Returns active reminders scheduled on the requested calendar date, sorted by time.
  List<ReminderModel> _remindersForDate(
    List<ReminderModel> reminders,
    DateTime date,
  ) {
    return reminders.where((reminder) {
      return reminder.status != 'stopped' &&
          _sameDay(reminder.scheduledAt, date);
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Compares two dates by year, month, and day, ignoring their times.
  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  /// Combines a customer first and last name into a display label.
  String _customerName(CustomerModel customer) =>
      '${customer.firstName} ${customer.lastName}'.trim();

  /// Formats a monetary amount to two decimal places.
  String _money(double amount) => amount.toStringAsFixed(2);
}

/// Defines the date ranges available for Home Insights.
enum _InsightPeriod { today, month, year, custom }

/// Selects whether the Insights chart displays amounts or record counts.
enum _InsightChartMetric { amount, count }

/// Accumulates visit and payment metrics for one chart interval.
class _InsightBucket {
  final String label;
  final DateTime start;
  final DateTime end;
  int visits = 0;
  int payments = 0;
  double billed = 0;
  double collected = 0;

  /// Creates an empty chart bucket for the supplied label and date interval.
  _InsightBucket(this.label, this.start, this.end);

  /// Whether this interval contains no visit or payment activity.
  bool get isEmpty =>
      visits == 0 && payments == 0 && billed == 0 && collected == 0;
}

/// Draws the grouped bar chart used by Home Insights.
class _InsightBarChartPainter extends CustomPainter {
  final List<_InsightBucket> buckets;
  final bool showAmounts;
  final Color firstColor;
  final Color secondColor;
  final Color labelColor;
  final Color gridColor;

  /// Configures chart buckets, value mode, and colors for the Insights chart.
  const _InsightBarChartPainter({
    required this.buckets,
    required this.showAmounts,
    required this.firstColor,
    required this.secondColor,
    required this.labelColor,
    required this.gridColor,
  });

  /// Draws insight bar chart painter on the supplied canvas.
  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const left = 38.0;
    const right = 5.0;
    const top = 8.0;
    const bottom = 29.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    double firstValue(_InsightBucket bucket) =>
        showAmounts ? bucket.billed : bucket.visits.toDouble();
    double secondValue(_InsightBucket bucket) =>
        showAmounts ? bucket.collected : bucket.payments.toDouble();

    final maxValue = buckets
        .map((bucket) => math.max(firstValue(bucket), secondValue(bucket)))
        .fold<double>(
          0,
          (maximum, value) => math.max(maximum, value).toDouble(),
        );
    final scaleMax = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var line = 0; line <= 4; line++) {
      final y = top + chartHeight * line / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final value = scaleMax * (4 - line) / 4;
      final label = showAmounts
          ? _compactAmount(value)
          : value.round().toString();
      _drawText(
        canvas,
        label,
        Offset(0, y - 6),
        color: labelColor,
        fontSize: 9,
        width: left - 5,
        alignment: TextAlign.right,
      );
    }

    final groupWidth = chartWidth / buckets.length;
    final barWidth = math.min(12.0, groupWidth * 0.27);
    final firstPaint = Paint()..color = firstColor;
    final secondPaint = Paint()..color = secondColor;
    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      final centerX = left + groupWidth * (index + 0.5);
      final firstHeight = chartHeight * firstValue(bucket) / scaleMax;
      final secondHeight = chartHeight * secondValue(bucket) / scaleMax;
      if (firstHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX - barWidth - 1,
              top + chartHeight - firstHeight,
              barWidth,
              firstHeight,
            ),
            const Radius.circular(4),
          ),
          firstPaint,
        );
      }
      if (secondHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX + 1,
              top + chartHeight - secondHeight,
              barWidth,
              secondHeight,
            ),
            const Radius.circular(4),
          ),
          secondPaint,
        );
      }

      final labelEvery = buckets.length > 8 ? 2 : 1;
      if (index % labelEvery == 0 || index == buckets.length - 1) {
        _drawText(
          canvas,
          bucket.label,
          Offset(centerX - groupWidth / 2, top + chartHeight + 7),
          color: labelColor,
          fontSize: 9,
          width: groupWidth,
          alignment: TextAlign.center,
        );
      }
    }
  }

  /// Formats large chart values with compact thousand or million suffixes.
  String _compactAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }

  /// Paints an ellipsized text label on the custom chart canvas.
  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double fontSize,
    required double width,
    required TextAlign alignment,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: alignment,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  /// Compares painter inputs to decide whether the custom graphic must be redrawn.
  @override
  bool shouldRepaint(covariant _InsightBarChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.showAmounts != showAmounts ||
        oldDelegate.firstColor != firstColor ||
        oldDelegate.secondColor != secondColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.gridColor != gridColor;
  }
}
