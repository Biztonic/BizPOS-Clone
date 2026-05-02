import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/sync/limits/limits_enforcer.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:flutter/foundation.dart';

class CheckSubscriptionParams {
  final Store store;

  CheckSubscriptionParams({required this.store});
}

class CheckSubscriptionUseCase extends UseCase<CheckSubscriptionParams, bool> {
  final LimitsEnforcer limitsEnforcer;

  CheckSubscriptionUseCase(this.limitsEnforcer);

  @override
  Future<bool> execute(CheckSubscriptionParams params) async {
    try {
      await limitsEnforcer.checkOrderLimit(params.store.id);
      return true;
    } catch (e) {
      debugPrint('Subscription Limit Reached: $e');
      // Handled via PlanLimitReachedEvent in LimitsEnforcer
      return false;
    }
  }
}
