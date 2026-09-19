import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/core/auth/auth_session_types.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

void main() {
  group('Unit Tests: Core State Machines & Lifecycle Invariants', () {
    test('1. OrderStatus lifecycle and terminal immutability flags', () {
      // Mutable draft states
      expect(OrderStatus.newOrder.isTerminal, isFalse);
      expect(OrderStatus.preparing.isTerminal, isFalse);
      expect(OrderStatus.ready.isTerminal, isFalse);

      // Terminal immutable states
      expect(OrderStatus.completed.isTerminal, isTrue);
      expect(OrderStatus.refunded.isTerminal, isTrue);
      expect(OrderStatus.voided.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);

      // Parsing from String using domain values
      expect(OrderStatus.fromString('Completed'), OrderStatus.completed);
      expect(OrderStatus.fromString('Refunded'), OrderStatus.refunded);
      expect(OrderStatus.fromString('VOID'), OrderStatus.voided);
      expect(OrderStatus.fromString('Cancelled'), OrderStatus.cancelled);
      expect(OrderStatus.fromString('unknown_status'), OrderStatus.newOrder);
    });

    test('2. AuthStatus enum states and ActiveAuthSession assertions', () {
      expect(AuthStatus.values.length, 5);
      expect(AuthStatus.values, contains(AuthStatus.UNKNOWN));
      expect(AuthStatus.values, contains(AuthStatus.ONLINE_AUTHENTICATED));
      expect(AuthStatus.values, contains(AuthStatus.OFFLINE_AUTHENTICATED));
      expect(AuthStatus.values, contains(AuthStatus.SIGNED_OUT));
      expect(AuthStatus.values, contains(AuthStatus.LOCKED));

      final offlineSession = ActiveAuthSession(
        type: SessionType.LOCAL_OFFLINE_SESSION,
        uid: 'USR_OFFLINE',
        email: 'cashier@bizpos.com',
        storeId: 'STORE_01',
        role: 'Cashier',
        authenticatedAt: DateTime.now(),
      );
      expect(offlineSession.isOffline, isTrue);
      expect(offlineSession.isOnline, isFalse);
      expect(offlineSession.isEmployee, isFalse);

      final onlineSession = ActiveAuthSession(
        type: SessionType.FIREBASE_AUTH_SESSION,
        uid: 'USR_ONLINE',
        email: 'owner@bizpos.com',
        storeId: 'STORE_01',
        role: 'Owner',
        authenticatedAt: DateTime.now(),
      );
      expect(onlineSession.isOnline, isTrue);
      expect(onlineSession.isOffline, isFalse);
    });

    test('3. OutboxState lifecycle values and conversions', () {
      expect(OutboxState.pending.toValue(), 'PENDING');
      expect(OutboxState.inFlight.toValue(), 'IN_FLIGHT');
      expect(OutboxState.pushed.toValue(), 'PUSHED');
      expect(OutboxState.confirmed.toValue(), 'CONFIRMED');
      expect(OutboxState.deadLetter.toValue(), 'DEAD_LETTER');

      expect(OutboxState.fromValue('PENDING'), OutboxState.pending);
      expect(OutboxState.fromValue('IN_FLIGHT'), OutboxState.inFlight);
      expect(OutboxState.fromValue('CONFIRMED'), OutboxState.confirmed);
      expect(OutboxState.fromValue('DEAD_LETTER'), OutboxState.deadLetter);
      expect(OutboxState.fromValue('UNKNOWN_STRING'), OutboxState.pending);
    });

    test('4. OutboxOperation model transition and retry backoff state', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final op = OutboxOperation(
        operationId: 'OP_STATE_01',
        storeId: 'STORE_01',
        userId: 'USER_01',
        deviceId: 'DEV_01',
        collection: 'orders',
        entityId: 'ORD_01',
        operation: 'create',
        payload: {'id': 'ORD_01', 'total': 100.0},
        baseVersion: 1,
        newVersion: 1,
        createdAt: nowMs,
        state: OutboxState.pending,
      );

      expect(op.state, OutboxState.pending);

      // Transition to inFlight
      final inFlight = op.copyWith(
        state: OutboxState.inFlight,
        attemptCount: 1,
      );
      expect(inFlight.state, OutboxState.inFlight);
      expect(inFlight.attemptCount, 1);

      // Transition to confirmed
      final confirmed = inFlight.copyWith(
        state: OutboxState.confirmed,
      );
      expect(confirmed.state, OutboxState.confirmed);

      // Transition to deadLetter
      final deadLetter = op.copyWith(
        state: OutboxState.deadLetter,
        lastError: 'Fatal 403 Forbidden',
      );
      expect(deadLetter.state, OutboxState.deadLetter);
      expect(deadLetter.lastError, 'Fatal 403 Forbidden');
    });
  });
}
