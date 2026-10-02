// Implements visit and payment queries, pagination, and transactional mutations.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_model.dart';
import '../models/visit_model.dart';
import '../services/audit_log_service.dart';
import 'firestore_code_sequence.dart';
import 'firestore_page.dart';

/// Implements Firestore data access for visit records.
class FirestoreVisitRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _visits;
  late final CollectionReference<Map<String, dynamic>> _payments;
  late final FirestoreCodeSequence _visitCodes;
  late final FirestoreCodeSequence _paymentCodes;

  /// Creates visit and payment accessors using the supplied or default Firestore instance.
  FirestoreVisitRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _visits = _firestore.collection('visits');
    _payments = _firestore.collection('payments');
    _visitCodes = FirestoreCodeSequence(collection: _visits, prefix: 'VIS');
    _paymentCodes = FirestoreCodeSequence(collection: _payments, prefix: 'PAY');
  }

  /// Subscribes to Firestore changes for visits and maps snapshots to typed records.
  Stream<List<VisitModel>> watchVisits() {
    return _visits.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        return VisitModel.fromMap(doc.id, doc.data());
      }).toList()..sort((a, b) => b.visitDate.compareTo(a.visitDate)),
    );
  }

  /// Subscribes to Firestore changes for payments and maps snapshots to typed records.
  Stream<List<PaymentModel>> watchPayments() {
    return _payments.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        return PaymentModel.fromMap(doc.id, doc.data());
      }).toList()..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)),
    );
  }

  /// Watches one customer's visits without reading unrelated customer records.
  Stream<List<VisitModel>> watchVisitsForCustomer(String customerId) {
    final customerRef = _firestore.collection('customers').doc(customerId);
    return _visits
        .where('customerId', isEqualTo: customerRef)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => VisitModel.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => b.visitDate.compareTo(a.visitDate)),
        );
  }

  /// Watches one customer's payments without reading unrelated records.
  Stream<List<PaymentModel>> watchPaymentsForCustomer(String customerId) {
    final customerRef = _firestore.collection('customers').doc(customerId);
    return _payments
        .where('customerId', isEqualTo: customerRef)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)),
        );
  }

  /// Loads at most ten visits by visit date, newest first.
  Future<FirestorePage<VisitModel>> fetchVisitPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<VisitModel>(
      query: _visits.orderBy('visitDate', descending: true),
      map: (doc) => VisitModel.fromMap(doc.id, doc.data()),
    ).load(cursor: cursor);
  }

  /// Loads at most ten payments by payment date, newest first.
  Future<FirestorePage<PaymentModel>> fetchPaymentPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<PaymentModel>(
      query: _payments.orderBy('paymentDate', descending: true),
      map: (doc) => PaymentModel.fromMap(doc.id, doc.data()),
    ).load(cursor: cursor);
  }

  /// Creates a visit and its initial payment atomically, allocating both display codes in the transaction.
  Future<void> addVisitWithPayment({
    required String customerId,
    required String petId,
    required String serviceTypeId,
    required double defaultAmount,
    required double actualAmount,
    required String visitNotes,
    required DateTime visitDate,
    required double paymentAmount,
    required String paymentNotes,
    required DateTime paymentDate,
    required String paymentMode,
    required String referenceNo,
  }) async {
    final visitHighest = await _visitCodes
        .highestExistingNumberIfCounterMissing();
    final paymentHighest = await _paymentCodes
        .highestExistingNumberIfCounterMissing();
    final visitRef = _visitCodes.createDocumentRef();
    final paymentRef = _paymentCodes.createDocumentRef();
    final now = Timestamp.now();
    final customerRef = _firestore.collection('customers').doc(customerId);

    await AuditLogService.instance.track(
      entity: 'Visit and payment',
      action: 'create',
      operation: () => _firestore.runTransaction((transaction) async {
        final visitCounter = await transaction.get(_visitCodes.counterRef);
        final paymentCounter = await transaction.get(_paymentCodes.counterRef);

        _visitCodes.writeInTransaction(
          transaction,
          documentRef: visitRef,
          counterSnapshot: visitCounter,
          highestExistingNumber: visitHighest,
          data: {
            'customerId': customerRef,
            'petId': _firestore.collection('pets').doc(petId),
            'serviceTypeId': _firestore
                .collection('serviceTypes')
                .doc(serviceTypeId),
            'defaultAmount': defaultAmount,
            'actualAmount': actualAmount,
            'notes': visitNotes,
            'visitDate': Timestamp.fromDate(visitDate),
            'createdAt': now,
            'updatedAt': now,
          },
        );

        _paymentCodes.writeInTransaction(
          transaction,
          documentRef: paymentRef,
          counterSnapshot: paymentCounter,
          highestExistingNumber: paymentHighest,
          data: {
            'amount': paymentAmount,
            'customerId': customerRef,
            'visitId': visitRef,
            'notes': paymentNotes,
            'paymentDate': Timestamp.fromDate(paymentDate),
            'paymentMode': paymentMode,
            'referenceNo': referenceNo,
            'createdAt': now,
            'updatedAt': now,
          },
        );
      }),
    );
  }

  /// Creates a payment record for the selected customer and visit.
  Future<void> addPayment({
    required String customerId,
    required String visitId,
    required double amount,
    required String notes,
    required DateTime paymentDate,
    required String paymentMode,
    required String referenceNo,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Payment',
      action: 'create',
      operation: () => _paymentCodes.add({
        'amount': amount,
        'customerId': _firestore.collection('customers').doc(customerId),
        'visitId': _visits.doc(visitId),
        'notes': notes,
        'paymentDate': Timestamp.fromDate(paymentDate),
        'paymentMode': paymentMode,
        'referenceNo': referenceNo,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }),
    );
  }

  /// Updates the selected visit record with the supplied values.
  Future<void> updateVisit({
    required String id,
    required String petId,
    required String serviceTypeId,
    required double defaultAmount,
    required double actualAmount,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Visit',
      action: 'update',
      recordId: id,
      operation: () => _visits.doc(id).update({
        'petId': _firestore.collection('pets').doc(petId),
        'serviceTypeId': _firestore
            .collection('serviceTypes')
            .doc(serviceTypeId),
        'defaultAmount': defaultAmount,
        'actualAmount': actualAmount,
        'updatedAt': Timestamp.now(),
      }),
    );
  }

  /// Updates the selected payment record with the supplied values.
  Future<void> updatePayment({
    required String id,
    required double amount,
    required String paymentMode,
    required DateTime paymentDate,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Payment',
      action: 'update',
      recordId: id,
      operation: () => _payments.doc(id).update({
        'amount': amount,
        'paymentMode': paymentMode,
        'paymentDate': Timestamp.fromDate(paymentDate),
        'updatedAt': Timestamp.now(),
      }),
    );
  }

  /// Deletes the selected payment record and records the operation result.
  Future<void> deletePayment(String id) async {
    await AuditLogService.instance.track(
      entity: 'Payment',
      action: 'delete',
      recordId: id,
      operation: () => _payments.doc(id).delete(),
    );
  }

  /// Deletes the selected visit record and records the operation result.
  Future<void> deleteVisit(String id) async {
    await AuditLogService.instance.track(
      entity: 'Visit and related payments',
      action: 'delete',
      recordId: id,
      operation: () async {
        final visitRef = _visits.doc(id);
        final relatedPayments = await _payments
            .where('visitId', isEqualTo: visitRef)
            .get();

        for (var start = 0; start < relatedPayments.docs.length; start += 500) {
          final batch = _firestore.batch();
          final end = (start + 500 < relatedPayments.docs.length)
              ? start + 500
              : relatedPayments.docs.length;
          for (final payment in relatedPayments.docs.sublist(start, end)) {
            batch.delete(payment.reference);
          }
          await batch.commit();
        }

        await visitRef.delete();
      },
    );
  }
}
