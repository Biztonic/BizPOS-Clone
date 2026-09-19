import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_functions/cloud_functions.dart';
import '../sync/sync_engine.dart';

import '../l10n/app_localizations.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../core/auth/auth_session_types.dart';
import '../services/offline_service.dart';
import '../utils/pin_utils.dart';
import '../announcement/service/announcement_service.dart';

class EmployeePinDialog extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final String storeCode;
  final String? storeId;
  final String? empId;

  const EmployeePinDialog({
    super.key,
    this.employee,
    required this.storeCode,
    this.storeId,
    this.empId,
  });

  @override
  State<EmployeePinDialog> createState() => _EmployeePinDialogState();
}

class _EmployeePinDialogState extends State<EmployeePinDialog> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  Map<String, dynamic>? _employee;
  bool _isLoading = false;
  bool _isFetchingDetails = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _employee = widget.employee;
    } else if (widget.empId != null) {
      _fetchEmployeeDetails();
    }

    // Keep focus on our offscreen TextField to intercept physical keyboard presses
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployeeDetails() async {
    setState(() {
      _isFetchingDetails = true;
      _errorMessage = null;
    });

    final storeCode = widget.storeCode;
    final empId = widget.empId!;

    try {
      // 1. Check local cache first
      if (Hive.isBoxOpen('cache_employees')) {
        final box = Hive.box('cache_employees');
        final empMap = box.values.firstWhere((e) {
          final map = e as Map;
          return map['employeeId']?.toString() == empId;
        }, orElse: () => null);
        if (empMap != null) {
          setState(() {
            _employee = Map<String, dynamic>.from(empMap as Map);
            _isFetchingDetails = false;
          });
          return;
        }
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeData = await authProvider.lookupEmployee(
        storeCodeOrId: widget.storeId ?? storeCode,
        employeeId: empId,
      );

      if (employeeData != null) {
        setState(() {
          _employee = employeeData;
          _isFetchingDetails = false;
        });
        return;
      }

      // Default placeholder if profile not fetched yet; server function will validate on submit
      setState(() {
        _employee = {
          'employeeId': empId,
          'name': 'Employee #$empId',
          'role': 'Staff',
          if (widget.storeId != null) 'storeId': widget.storeId,
        };
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isFetchingDetails = false;
      });
      _focusNode.requestFocus();
    }
  }

  void _handleNumberPress(String value) {
    AnnouncementService().playKeypadSound();
    if (_pinController.text.length < 4) {
      setState(() {
        _pinController.text += value;
        _errorMessage = null;
      });
      if (_pinController.text.length == 4) {
        _submitPin();
      }
    }
  }

  void _handleBackspace() {
    AnnouncementService().playKeypadSound();
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text =
            _pinController.text.substring(0, _pinController.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _handleClear() {
    AnnouncementService().playKeypadSound();
    setState(() {
      _pinController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submitPin() async {
    if (_employee == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final pin = _pinController.text.trim();
    final empId = widget.empId ?? (_employee!['employeeId'] ?? '').toString();
    final storeCode = widget.storeCode;
    final cleanStoreCode = storeCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    String? targetStoreId = widget.storeId ?? _employee!['storeId'];

    final invalidPinMsg = AppLocalizations.t(context, 'Invalid PIN');
    final unableVerifyMsg = AppLocalizations.t(context,
        'Unable to verify PIN. Please check connectivity or credentials.');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // 1. RESOLVE STORE ID FROM LOCAL CACHE IF NEEDED
      if (targetStoreId == null && Hive.isBoxOpen('cache_stores')) {
        final box = Hive.box('cache_stores');
        final storeMap = box.values.firstWhere((s) {
          final map = s as Map;
          return map['shortCode'] == cleanStoreCode ||
              map['id'] == cleanStoreCode;
        }, orElse: () => null);
        if (storeMap != null) targetStoreId = (storeMap as Map)['id'];
      }

      // Check lockout protection before processing attempt
      if (targetStoreId != null &&
          OfflineService().isEmployeePinLockedOut(targetStoreId, empId)) {
        final remaining = OfflineService()
            .getRemainingPinLockoutSeconds(targetStoreId, empId);
        throw 'PIN is temporarily locked out due to too many failed attempts. Please wait $remaining seconds.';
      }

      // 2. SERVER-AUTHORITATIVE VERIFICATION VIA CALLABLE CLOUD FUNCTION
      try {
        final callable =
            FirebaseFunctions.instance.httpsCallable('verifyEmployeePin');
        final response = await callable.call({
          if (targetStoreId != null) 'storeId': targetStoreId,
          'storeCode': cleanStoreCode,
          'employeeId': empId,
          'pin': pin,
        }).timeout(const Duration(seconds: 8));

        final resData = Map<String, dynamic>.from(response.data as Map);
        final token = resData['token'] as String?;
        final empProfile =
            Map<String, dynamic>.from(resData['employee'] as Map);
        final uid = empProfile['uid'] as String;

        // Reset pin attempts on success
        if (targetStoreId != null) {
          OfflineService().resetPinAttempts(targetStoreId, empId);
        }

        // Authenticate with the server-minted store-scoped custom token
        if (token != null && token.isNotEmpty) {
          await FirebaseAuth.instance.signInWithCustomToken(token);
        }

        authProvider.setEmployeeSession(ActiveAuthSession(
          type: SessionType.EMPLOYEE_POS_SESSION,
          uid: uid,
          email: empProfile['email']?.toString() ?? '$empId@bizpos.com',
          storeId: targetStoreId,
          role: empProfile['role']?.toString() ?? 'Staff',
          authenticatedAt: DateTime.now(),
        ));

        await _finalizeLogin(uid, empProfile);
        return;
      } on FirebaseFunctionsException catch (fe) {
        throw fe.message ?? invalidPinMsg;
      } catch (cloudErr) {
        debugPrint("Server PIN verification offline or error: $cloudErr");
        // Proceed to offline local cache fallback below
      }

      // 3. OFFLINE CACHE FALLBACK (for offline POS continuity)
      if (targetStoreId != null && Hive.isBoxOpen('cache_employees')) {
        final box = Hive.box('cache_employees');
        final empMap = box.values.firstWhere((e) {
          final map = e as Map;
          return map['storeId'] == targetStoreId &&
              map['employeeId'].toString() == empId;
        }, orElse: () => null);

        if (empMap != null) {
          final map = empMap as Map;
          final uid = map['uid'];
          final storedPin = map['pinHash'] ?? map['pin'];
          if (PinUtils.verifyPin(pin, uid, storedPin)) {
            OfflineService().resetPinAttempts(targetStoreId, empId);
            authProvider.setEmployeeSession(ActiveAuthSession(
              type: SessionType.EMPLOYEE_POS_SESSION,
              uid: uid,
              email: map['email']?.toString() ?? '$empId@bizpos.com',
              storeId: targetStoreId,
              role: map['role']?.toString() ?? 'Staff',
              authenticatedAt: DateTime.now(),
            ));
            await _finalizeLogin(uid, Map.from(map));
            return;
          } else {
            OfflineService().recordFailedPinAttempt(targetStoreId, empId);
            if (OfflineService().isEmployeePinLockedOut(targetStoreId, empId)) {
              throw 'PIN is locked out due to 5 consecutive failed attempts. Please wait 5 minutes.';
            }
            throw invalidPinMsg;
          }
        }
      }

      throw unableVerifyMsg;
    } catch (e) {
      AnnouncementService().playAlertSound();
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _pinController.clear();
          _isLoading = false;
        });
        // Re-request focus in case it was lost
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _finalizeLogin(String uid, Map userData) async {
    AnnouncementService().playSuccessSound();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.setLoading(true);

    try {
      String deviceId = "unknown";
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        deviceId = box.get('app_device_id', defaultValue: '');
        if (deviceId.isEmpty) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final random = math.Random().nextInt(1000000);
          deviceId = 'device_${now}_$random';
          box.put('app_device_id', deviceId);
        }
      }

      final storeId = userData['storeId'];
      if (storeId != null) {
        unawaited(SyncService().performLocalWrite(
          collection: 'stores',
          docId: storeId,
          data: {'activeDeviceId': deviceId},
          action: 'update',
          localCacheBox: 'cache_stores',
          refreshCounts: false,
        ));
      }
    } catch (e) {
      debugPrint("Device tracking update failed: $e");
    }

    await provider.loadEmployeeProfileForVirtualLogin(
        uid, Map<String, dynamic>.from(userData));
    if (mounted) {
      Navigator.pop(context); // Close dialog
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final empName =
        _employee?['name'] ?? widget.employee?['name'] ?? 'Employee';
    final empRole = _employee?['role'] ?? widget.employee?['role'] ?? 'Staff';
    final initial = empName.isNotEmpty ? empName[0].toUpperCase() : '?';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Offscreen Text Field to capture physical keyboard input
              Opacity(
                opacity: 0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (val) {
                      setState(() {});
                      if (val.length == 4) {
                        _submitPin();
                      }
                    },
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with back option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new,
                                size: 16,
                                color:
                                    isDark ? Colors.white70 : Colors.black87),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            AppLocalizations.t(context, 'Employee Login'),
                            style: AppTypography.titleMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                              width: 48), // Spacer for centering title
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (_isFetchingDetails)
                        const SizedBox(
                          height: 350,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(strokeWidth: 3),
                                SizedBox(height: AppSpacing.md),
                                Text("Loading profile details...",
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Avatar
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            initial,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Employee Info
                        Text(
                          empName,
                          style: AppTypography.titleLarge
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          empRole,
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Dots for PIN indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = _pinController.text.length > index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _errorMessage != null
                                    ? AppColors.error
                                    : isFilled
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white10
                                            : Colors.black.withOpacity(0.08)),
                                border: Border.all(
                                  color: _errorMessage != null
                                      ? AppColors.error
                                      : isFilled
                                          ? AppColors.primary
                                          : (isDark
                                              ? Colors.white30
                                              : Colors.black26),
                                  width: 1.5,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: AppSpacing.xs),

                        // Error Message
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          const SizedBox(height: 20),

                        // Loading or Keypad
                        if (_isLoading)
                          const SizedBox(
                            height: 250,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        else
                          _buildKeypad(isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton("1"),
            _buildKeypadButton("2"),
            _buildKeypadButton("3"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton("4"),
            _buildKeypadButton("5"),
            _buildKeypadButton("6"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton("7"),
            _buildKeypadButton("8"),
            _buildKeypadButton("9"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadIconButton(Icons.clear, _handleClear),
            _buildKeypadButton("0"),
            _buildKeypadIconButton(Icons.backspace_outlined, _handleBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 72,
      height: 52,
      child: OutlinedButton(
        onPressed: () => _handleNumberPress(label),
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.01),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadIconButton(IconData icon, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 72,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.01),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
