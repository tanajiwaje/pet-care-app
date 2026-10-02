# PetCare Application Functionality

This document describes the user-facing features and the main data flows in the
PetCare Flutter application.

## Application startup and navigation

- Firebase is initialized at startup using the platform options in
  `lib/firebase_options.dart`.
- An animated PetCare loading screen is shown while startup completes. If
  initialization fails, the app presents an error state with a retry action.
- The bottom-level app shell provides Home, Reminders, Visits, and More.
  Sections initialize when first opened and remain mounted afterward so their
  screen state is retained during tab navigation.

## Home

The Home screen provides two sections:

### Overview

- Shows a time-aware welcome message.
- Displays today's visit and payment counts, visit amount, amount paid, and
  remaining amount based on visits and associated payments.
- Shows a compact reminder agenda split into today and tomorrow, with a route
  to the full Reminders screen.
- The overview heading identifies the section without repeating the date
  beneath it.

### Insights

- Summarizes visit, payment, and customer data in KPI and chart form.
- Supports time-range filters and customer name/mobile search for exploring
  the available insights.

Home totals use the full data needed by the current calculations; they are not
based on only the first page of a visible list. The Home agenda query is limited
to reminders for today and tomorrow.

## Reminders

- Offers calendar and list views.
- Marks dates with scheduled reminders and scopes the calendar query to the
  displayed month.
- The list supports date and customer-oriented filtering and cursor pagination
  in pages of ten records.
- Create and edit forms select a customer using a searchable picker that
  matches customer names and mobile numbers. Only customers allowed by the
  reminder flow are offered.
- Supports reminder scheduling and local notification actions, including
  notification timing and snooze/stop interactions.
- Reminder create, update, and delete operations are persisted in Firestore.

## Visits and payments

- Presents visits and payments and supports creating, editing, and deleting
  records.
- A visit links its customer, pet, and service type. Selecting a customer
  refreshes the available pets for that customer.
- Customer selection in the Visit and Payment forms is searchable by customer
  name or mobile number. Visit choices are restricted to customers with
  eligible pets; payment choices are restricted to customers with pending
  visits.
- Payments are associated with visits. Remaining balances are calculated from
  visit amounts and payments, with payments indexed by visit to avoid repeated
  full scans during the calculation.
- Business mutations are recorded in the local audit log.

## Master data and customer details

The More area provides master-data and customer-detail navigation.

- Customers can be managed with create, read, update, and delete operations.
- Pet types, breeds, and service types provide the reusable classification and
  pricing data used by pet and visit entry.
- Master-data record lists use bounded ten-record cursor pages.
- Customer Details presents the selected customer's pets, visits, payments,
  and related totals. Visit and payment reads are scoped to that customer.

## Logs and About

- Logs displays locally stored activity and error records for application
  operations. Audit history is retained on the device and old entries are
  pruned according to the configured one-month retention policy.
- About displays installed application metadata and the generated license
  information.

## Data and persistence

- Cloud Firestore is the source of truth for business records.
- Firestore-backed collections include `customers`, `pets`, `petTypes`,
  `breeds`, `serviceTypes`, `visits`, `payments`, and `reminders`.
- `_counters` supports transactional generation of human-readable record codes.
- Local audit records and scheduled notifications are device-side features;
  they are distinct from Firestore business data.
- Firestore records are converted to typed Dart models at repository/model
  boundaries. Repository code owns Firestore queries and writes; presentation
  code owns screen state and invokes repository APIs.

## Loading and performance behavior

- Large record lists use cursor-based Firestore pagination, normally ten items
  per page, rather than loading the entire list at once.
- Live streams remain in use where the UI requires synchronization or complete
  relationship context for totals and balances.
- Home and Insights currently use full matching visit, payment, and customer
  inputs for their aggregates. Do not replace those inputs with a single page
  unless the aggregate and relationship logic is moved to bounded server-side
  queries or maintained summary data.
- Feature tabs are initialized on first use to avoid starting every screen's
  data work during initial app launch.
