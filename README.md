# PetCare

PetCare is a Flutter application for managing pet-care customers, pets, visit
appointments, payments, reminders, and master data. Firebase Cloud Firestore is
the source of truth for business records; audit history is kept locally on the
device.

## Project structure

```text
lib/
  core/           Shared theme and reusable UI
  features/       Feature-first screens and their presentation state
  models/         Firestore-to-Dart data models
  repositories/   Firestore queries, mutations, and pagination
  services/       Cross-feature services and device integrations
  main.dart       App startup, Firebase initialization, and root navigation
test/             Widget and service tests
```

### Core

- `AppTheme` defines the shared Material theme.
- `confirmDeleteRecord` provides the common destructive-action confirmation.
- `firebase_access_test.dart` is a diagnostic utility for checking Firebase
  access; it is not the production data-access layer.

### Features and presentation classes

- `PetCareApp` owns Firebase startup, the animated loading/error screens, and
  the root app theme. `_PetFacePainter` and `_FloatingPet` draw and animate the
  startup cat and dog.
- `AppShellPage` lazily creates Home, Reminders, Visits, and More in an
  `IndexedStack`, retaining each tab's state after its first visit;
  `_HomeView` connects Home shortcuts to the other tabs.
- `PetHomePage` calculates the Home overview and Insights from live repository
  streams. `_InsightBucket` and `_InsightBarChartPainter` prepare and render
  chart buckets.
- `RemindersPage` presents the reminder calendar/list and coordinates reminder
  CRUD with local notification actions. Calendar reads are scoped to the
  visible month; list mode loads ten reminders at a time. `_ReminderDraft`,
  `_AlarmChoice`, and `_ReminderCalendarHeaderDelegate` support the reminder
  form, notification timing, and collapsible calendar.
- `VisitsPage` presents visits and payments, customer search, and their create,
  update, and delete flows. `_DialogControllerOwner` manages form-controller
  disposal for dialogs.
- `MorePage` provides navigation to master data, logs, and About.
  `MasterDataListPage` handles customer, pet-type, breed, and service-type
  management; `MasterDataKind`, `_MasterDataItem`, `_MasterDataCard`,
  `_MasterDataWelcomeCard`, and `_MoreActionCard` describe its menu.
- `CustomerDetailsPage` shows one customer's pets, visits, payments, and
  related totals.
- `AppLogsPage` filters local activity and error records. `_LogEntryCard` and
  `_LogMessageState` render entries and loading/error/empty states.
- `AppAboutPage`, `_AboutInfoCard`, and `_AboutInfoRow` present installed app
  metadata and Flutter's generated license list.

### Models

- `CustomerModel` represents contact and address information.
- `PetModel` represents a customer's pet and its type/breed references.
- `PetTypeModel` and `BreedModel` represent pet classification master data.
- `ServiceTypeModel` represents a service and its default price.
- `VisitModel` represents an appointment/service visit and billed amounts.
- `PaymentModel` represents a payment linked to a customer and visit.
- `ReminderModel` represents a scheduled customer reminder and notification
  state.

Model `fromMap` factories normalize Firestore references and timestamps at the
data boundary.

### Repositories and services

- `CustomerRepository`, `PetRepository`, `BreedRepository`,
  `PetTypeRepository`, and `ServiceTypeRepository` define the contracts used
  for master-data access.
- `FirestoreCustomerRepository`, `FirestorePetRepository`,
  `FirestoreBreedRepository`, `PetTypeFirestoreRepository`, and
  `FirestoreServiceTypeRepository` implement those contracts with Firestore.
- `FirestoreVisitRepository` owns visit and payment queries and atomic
  visit/payment creation.
- `FirestoreReminderRepository` owns reminder persistence.
- `FirestoreCodeSequence` allocates human-readable record codes transactionally.
- `FirestorePageQuery` performs cursor-based, bounded Firestore reads;
  `FirestorePage` carries one page and its continuation cursor.
  `FirestorePageController` accumulates pages for scrollable screens, while
  `FirestorePageControllerState` exposes the common UI loading contract.
- `AuditLogEntry` is the local audit record model.
  `AuditLogService` serializes local activity, errors, retention, and mutations.
- `ReminderNotificationService` configures the device timezone, permissions,
  scheduled local alerts, snooze/stop notification flow, and notification taps.

## Data-flow and design conventions

1. Feature presentation code owns UI state and invokes repository APIs.
2. Repositories own Firestore collection references, query construction,
   mapping, and write transactions.
3. Models normalize untyped Firestore maps into typed application values.
4. Firestore snapshots are used where a screen needs live synchronization.
   Scrollable record lists should use `FirestorePageQuery` and
   `FirestorePageController` with the default ten-record page size.
5. Business mutations are recorded through `AuditLogService.track`, which
   records the operation result and rethrows write failures.
6. Dart source files include a file-purpose summary and documentation comments
   on types and declared functions; update these descriptions whenever a
   component's responsibility or behavior changes.

This follows a feature-first organization with repository boundaries, model
factories, streams for live data, and cursor pagination for record lists. It
does not currently use a dependency-injection container or a separate domain
use-case layer; screens construct their repositories directly. If the app
grows, repository construction should move behind a small composition root
before adding further state-management infrastructure.

## Loading, pagination, and performance

`FirestorePageQuery` applies a deterministic repository query with
`startAfterDocument` and `limit`. The cursor comes from the last document in
the fetched page, even when presentation filters hide some records. The
controller prevents overlapping requests, surfaces errors for a retry UI, and
can refresh from the first page.

Home and Insights keep full matching visit, payment, and customer inputs so
totals and charts do not change when the user scrolls. Home's agenda loads
reminders only for today and tomorrow; the reminder calendar loads the visible
month for accurate booked-date markers. This is intentionally different from
visible record lists: aggregate data and list pagination must not silently
share a partial page. The Master Data screens and reminder list currently use
ten-record cursor pages. For large production datasets, move Home/Insights
aggregation to Firestore aggregation queries or maintained summary documents.

Existing live-stream consumers that need complete relationship context
(including Home/Insights aggregates and current Visits calculations) still
read their full queried collections. Customer Details scopes visit and payment
streams to the selected customer.
Do not replace complete aggregate inputs with a single page unless the totals,
search, relationship lookups, and payment-balance calculations are moved to
bounded server queries or aggregate data as well. Home/Insights and Visits
aggregation remain the next performance migration area.

Visits keeps its Firestore streams stable across rebuilds and indexes payments
by visit before calculating balances, avoiding repeated full payment scans for
each visible visit. App tabs initialize on first selection rather than opening
all screen streams together during startup.

Use `ListView.builder`/`ListView.separated` for large visual lists; avoid
spreading every record into a `ListView.children` collection. Keep Firestore
errors visible in the UI, dispose controllers/subscriptions with their owning
State, and add tests for pagination boundaries and derived totals when changing
data loading.

## Local development

### Prerequisites

- Flutter SDK with a Dart SDK compatible with the `environment` constraint in
  `pubspec.yaml`.
- A configured Firebase project with Cloud Firestore enabled.
- A supported Flutter target, such as Android, iOS, Windows, macOS, Linux, or
  web. Platform availability also depends on the Firebase plugins used by the
  app.

Firebase is initialized from `lib/firebase_options.dart`. Configure that file
for your own Firebase project before running the app; do not commit service
account credentials or private signing keys. The app reads and writes the
Firestore collections `customers`, `pets`, `petTypes`, `breeds`,
`serviceTypes`, `visits`, `payments`, `reminders`, and `_counters`. Configure
Firestore security rules for the intended users and access policy before
production use.

### Install, run, and validate

```powershell
flutter pub get
flutter run
```

Useful quality and build commands:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Use `flutter devices` to list available run targets. For another platform,
replace the APK command with the appropriate Flutter build target, for example
`flutter build windows` or `flutter build ios` (iOS builds require macOS).

## Application functionality

See [functionality_details.md](./functionality_details.md) for the screen-by-
screen feature guide, supported workflows, and data behavior.
