// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import '../../core/design/tokens/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_helper.dart';
import '../../services/offline_service.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../../providers/dashboard_provider.dart';
import 'package:biztonic_pos/utils/pin_utils.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/store.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> with SingleTickerProviderStateMixin {
  final _storeCodeController = TextEditingController();
  final _empIdController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isMagicLink = false;
  bool _isFetchingDetails = false;

  // Pinned Store state
  Map? _pinnedStore;
  List<Map> _pinnedEmployees = [];
  Map? _selectedEmployee;
  bool _showManualForm = false;
  bool _isPinnedLoading = true;

  // Magic link state
  String? _storeName;
  String? _storeImage;
  String? _employeeName;
  String? _employeeRole;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadPinnedStore();
  }

  @override
  void dispose() {
    _storeCodeController.dispose();
    _empIdController.dispose();
    _pinController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      
      // Handle extra data (from StoreSelectScreen)
      if (state.extra is Map) {
        final extra = state.extra as Map;
        if (extra.containsKey('store') && extra.containsKey('employee')) {
          final storeMap = extra['store'];
          final employeeMap = extra['employee'];
          
          setState(() {
            // Convert models/maps as needed
            if (storeMap is Store) {
              _pinnedStore = storeMap.toMap();
            } else {
              _pinnedStore = Map.from(storeMap);
            }
            _selectedEmployee = Map.from(employeeMap);
            _showManualForm = false;
            _isPinnedLoading = false;
          });
          return; // Skip magic link check if we have extra
        }
      }

      // Handle query params (Magic Link)
      final params = state.uri.queryParameters;
      if (params.containsKey('store') && _storeCodeController.text.isEmpty) {
        final storeCode = params['store']!;
        final empId = params['emp'];

        _storeCodeController.text = storeCode;
        if (empId != null) {
          _empIdController.text = empId;
          _isMagicLink = true;
          _fetchMagicLinkDetails(storeCode, empId);
        }
      }
    } catch (e) {
      // Ignore if not routable yet
    }
  }

  Future<void> _loadPinnedStore() async {
    try {
      final pinned = await OfflineService().getPinnedStore();
      if (pinned != null) {
        final storeId = pinned['id'] ?? '';
        final employees = await OfflineService().getCachedStoreEmployees(storeId);
        if (mounted) {
          setState(() {
            _pinnedStore = pinned;
            _pinnedEmployees = employees;
            _isPinnedLoading = false;
            _showManualForm = false; // Ensure we show the grid if pinned
          });
        }
      } else {
        if (mounted) setState(() => _isPinnedLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading pinned store: $e");
      if (mounted) setState(() => _isPinnedLoading = false);
    }
  }

  Future<void> _forgetStore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Forget Store?')),
        content: Text(AppLocalizations.t(context, 'This will clear the cached employees and store name from this screen.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.t(context, 'CANCEL'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(AppLocalizations.t(context, 'FORGET'), style: const TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OfflineService().unpinStore();
      if (mounted) {
        setState(() {
          _pinnedStore = null;
          _pinnedEmployees = [];
          _showManualForm = true;
        });
      }
    }
  }

  Future<void> _fetchMagicLinkDetails(String storeCode, String empId) async {
    setState(() => _isFetchingDetails = true);
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
      }

      final cleanCode = storeCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      String? storeId;

      QuerySnapshot storeQuery = await getFirestore().collection('stores')
          .where('shortCode', isEqualTo: cleanCode).limit(1).get();

      if (storeQuery.docs.isEmpty) {
        final doc = await getFirestore().collection('stores').doc(cleanCode).get();
        final data = doc.data();
        if (data != null) {
          storeId = cleanCode;
          if (mounted) setState(() { _storeName = data['name']; _storeImage = data['image']; });
        }
      } else {
        storeId = storeQuery.docs.first.id;
        final data = storeQuery.docs.first.data() as Map<String, dynamic>;
        if (mounted) setState(() { _storeName = data['name']; _storeImage = data['image']; });
      }

      if (storeId != null) {
        QuerySnapshot subQuery = await getFirestore().collection('stores')
            .doc(storeId).collection('employees')
            .where('employeeId', isEqualTo: empId).limit(1).get();

        if (subQuery.docs.isEmpty) {
          subQuery = await getFirestore().collection('employees')
              .where('storeId', isEqualTo: storeId)
              .where('employeeId', isEqualTo: empId)
              .limit(1).get();
          if (subQuery.docs.isEmpty) {
            final intId = int.tryParse(empId);
            if (intId != null) {
              subQuery = await getFirestore().collection('employees')
                  .where('storeId', isEqualTo: storeId)
                  .where('employeeId', isEqualTo: intId)
                  .limit(1).get();
            }
          }
        }

        if (subQuery.docs.isNotEmpty) {
          final data = subQuery.docs.first.data() as Map<String, dynamic>;
          if (mounted) setState(() { _employeeName = data['name']; _employeeRole = data['role']; });
        } else {
          final dummyEmail = "${storeId}_$empId@biztonic.pos".toLowerCase();
          QuerySnapshot userQuery = await getFirestore().collection('users')
              .where('email', isEqualTo: dummyEmail).limit(1).get();
          if (userQuery.docs.isEmpty) {
            final intId = int.tryParse(empId);
            if (intId != null) {
              final intEmail = "${storeId}_$intId@biztonic.pos".toLowerCase();
              userQuery = await getFirestore().collection('users')
                  .where('email', isEqualTo: intEmail).limit(1).get();
            }
          }
          if (userQuery.docs.isNotEmpty) {
            final data = userQuery.docs.first.data() as Map<String, dynamic>;
            if (mounted) setState(() { _employeeName = data['name']; _employeeRole = data['role']; });
          }
        }
      }
    } catch (e) {
      debugPrint("Magic Link Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);

    // Resolve inputs from either pinned employee or manual form
    String storeCode;
    String empId;
    final pin = _pinController.text.trim();

    if (_selectedEmployee != null && _pinnedStore != null) {
      storeCode = _pinnedStore!['shortCode'] ?? _pinnedStore!['id'] ?? '';
      empId = (_selectedEmployee!['employeeId'] ?? '').toString();
    } else {
      storeCode = _storeCodeController.text.trim();
      empId = _empIdController.text.trim();
    }

    if (storeCode.isEmpty || empId.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Please fill all fields'))));
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint("Auth non-critical failure: $e");
        }
      }

      final cleanStoreCode = storeCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      String? targetStoreId;

      // 1. LOCAL CACHE FIRST
      if (Hive.isBoxOpen('cache_stores')) {
        final box = Hive.box('cache_stores');
        final storeMap = box.values.firstWhere((s) {
          final map = s as Map;
          return map['shortCode'] == cleanStoreCode || map['id'] == cleanStoreCode;
        }, orElse: () => null);
        if (storeMap != null) targetStoreId = (storeMap as Map)['id'];
      }

      // Also check pinned store
      if (targetStoreId == null && _pinnedStore != null) {
        final psc = _pinnedStore!['shortCode'] ?? '';
        final pid = _pinnedStore!['id'] ?? '';
        if (psc == cleanStoreCode || pid == cleanStoreCode) {
          targetStoreId = pid;
        }
      }

      if (targetStoreId != null && Hive.isBoxOpen('cache_employees')) {
        final box = Hive.box('cache_employees');
        final empMap = box.values.firstWhere((e) {
          final map = e as Map;
          return map['storeId'] == targetStoreId && map['employeeId'].toString() == empId;
        }, orElse: () => null);

        if (empMap != null) {
          final map = empMap as Map;
          final uid = map['uid'];
          final storedPin = map['pinHash'] ?? map['pin'];
          if (PinUtils.verifyPin(pin, uid, storedPin)) {
            await _finalizeLogin(uid, Map.from(map));
            return;
          } else {
            throw "Invalid PIN.";
          }
        }
      }

      // 2. NETWORK FALLBACK
      if (targetStoreId == null) {
        final storeQuery = await getFirestore().collection('stores')
            .where('shortCode', isEqualTo: cleanStoreCode).limit(1).get();
        if (storeQuery.docs.isNotEmpty) {
          targetStoreId = storeQuery.docs.first.id;
        } else {
          final doc = await getFirestore().collection('stores').doc(cleanStoreCode).get();
          if (doc.exists) targetStoreId = cleanStoreCode;
        }
      }

      if (targetStoreId == null) throw "Store Not Found. Check Code.";

      QuerySnapshot subQuery = await getFirestore()
          .collection('stores').doc(targetStoreId).collection('employees')
          .where('employeeId', isEqualTo: empId).limit(1).get();

      if (subQuery.docs.isEmpty) {
        subQuery = await getFirestore().collection('employees')
            .where('storeId', isEqualTo: targetStoreId)
            .where('employeeId', isEqualTo: empId).limit(1).get();

        if (subQuery.docs.isEmpty) {
          final intId = int.tryParse(empId);
          if (intId != null) {
            subQuery = await getFirestore().collection('employees')
                .where('storeId', isEqualTo: targetStoreId)
                .where('employeeId', isEqualTo: intId).limit(1).get();
          }
        }
      }

      if (subQuery.docs.isNotEmpty) {
        final Map<String, dynamic> userData = subQuery.docs.first.data() as Map<String, dynamic>;
        final storedPin = userData['pinHash'] ?? userData['pin'];
        final uid = subQuery.docs.first.id;
        if (PinUtils.verifyPin(pin, uid, storedPin)) {
          await _finalizeLogin(uid, userData);
          return;
        }
        throw "Invalid PIN.";
      }

      // LEGACY: Root User
      final dummyEmail = "${targetStoreId}_$empId@biztonic.pos".toLowerCase();
      QuerySnapshot query = await getFirestore().collection('users')
          .where('email', isEqualTo: dummyEmail).limit(1).get();

      if (query.docs.isEmpty) {
        final intId = int.tryParse(empId);
        if (intId != null) {
          final intEmail = "${targetStoreId}_$intId@biztonic.pos".toLowerCase();
          query = await getFirestore().collection('users')
              .where('email', isEqualTo: intEmail).limit(1).get();
        }
      }

      if (query.docs.isNotEmpty) {
        final Map<String, dynamic> userData = query.docs.first.data() as Map<String, dynamic>;
        final storedPin = userData['pin'];
        final uid = query.docs.first.id;
        if (PinUtils.verifyPin(pin, uid, storedPin)) {
          await _finalizeLogin(uid, userData);
          return;
        }
        throw "Invalid PIN.";
      }

      throw "Employee Not Found (ID: $empId, Store: $targetStoreId)";

    } on FirebaseAuthException catch (e) {
      if (e.code == 'admin-restricted-operation') {
        _showEnableAnonymousAuthDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Auth Error: ${e.message}"), backgroundColor: AppColors.error));
      }
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.t(context, 'Connection lost. Please check your internet.')),
          backgroundColor: AppColors.warning, duration: const Duration(seconds: 10)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Database Error: ${e.message}"), backgroundColor: AppColors.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e"), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeLogin(String uid, Map userData) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.setLoading(true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {/* */}
    }

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
          await getFirestore().collection('stores').doc(storeId).update({
             'activeDeviceId': deviceId
          });
       }
    } catch (e) {
       debugPrint("Device tracking update failed: $e");
    }

    await provider.loadEmployeeProfileForVirtualLogin(uid, Map<String, dynamic>.from(userData));
    if (mounted) context.go('/dashboard');
  }

  void _showEnableAnonymousAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Configuration Required')),
        content: const Text(
          "To use PIN Login, enable 'Anonymous' sign-in in Firebase Console.\n\n"
          "1. Go to Firebase Console > Authentication\n"
          "2. Click 'Sign-in method'\n"
          "3. Enable 'Anonymous'"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.t(context, 'OK'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMagicLink) return _buildMagicLinkUI();

    // If we have a pinned store and user hasn't toggled to manual
    if (!_showManualForm && _pinnedStore != null && !_isPinnedLoading) {
      return _buildPinnedStoreUI();
    }

    return _buildStandardUI();
  }

  // â”€â”€â”€ PINNED STORE UI: Employee Grid â”€â”€â”€
  Widget _buildPinnedStoreUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final storeName = _pinnedStore?['name'] ?? 'Store';
    final storeImage = _pinnedStore?['image'];

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1B2A), const Color(0xFF1B2838)]
                : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // â”€â”€ Top bar â”€â”€
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.surfaceLight),
                        onPressed: () => context.go('/login'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondaryDark, size: 18),
                        label: Text(AppLocalizations.t(context, 'Forget Store'), style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                        onPressed: _forgetStore,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        icon: const Icon(Icons.swap_horiz, color: AppColors.textSecondaryDark, size: 18),
                        label: Text(AppLocalizations.t(context, 'Other Store'), style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                        onPressed: () => setState(() => _showManualForm = true),
                      ),
                    ],
                  ),
                ),

                // â”€â”€ Store Branding â”€â”€
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceLight,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimaryLight.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: storeImage != null && storeImage.isNotEmpty
                        ? CachedNetworkImage(imageUrl: storeImage, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Image.asset('assets/logo.jpg', fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 36, color: AppColors.primaryLight)))
                        : Image.asset('assets/logo.jpg', fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 36, color: AppColors.primaryLight)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  storeName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.surfaceLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(AppLocalizations.t(context, 'Select your profile to login'),
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: AppSpacing.lg),

                // â”€â”€ Employee Grid or PIN Entry â”€â”€
                Expanded(
                  child: _selectedEmployee == null
                      ? _buildEmployeeGrid(isDark)
                      : _buildPinEntry(isDark, size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeGrid(bool isDark) {
    if (_pinnedEmployees.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.surfaceLight.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.md),
            Text(
              "No employees found.\nPlease login as owner first.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.surfaceLight.withValues(alpha: 0.6), fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showManualForm = true),
              icon: const Icon(Icons.edit, size: 18),
              label: Text(AppLocalizations.t(context, 'Manual Login')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.15),
                foregroundColor: AppColors.surfaceLight,
                elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _pinnedEmployees.length,
        itemBuilder: (context, index) {
          final emp = _pinnedEmployees[index];
          final name = emp['name'] ?? 'Employee';
          final role = emp['role'] ?? '';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

          // Generate a consistent color from the name
          final colorIndex = name.codeUnitAt(0) % 6;
          final avatarColors = [
            AppColors.primary, AppColors.success, AppColors.warning, AppColors.primaryLight, AppColors.error, AppColors.success,
          ];
          final avatarColor = avatarColors[colorIndex];

          return Material(
            color: AppColors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: () {
                setState(() {
                  _selectedEmployee = emp;
                  _pinController.clear();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceLight.withValues(alpha: 0.08) : AppColors.surfaceLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: avatarColor.withValues(alpha: 0.2),
                      child: Text(
                        initial,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: avatarColor),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      name,
                      style: const TextStyle(color: AppColors.surfaceLight, fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        role,
                        style: TextStyle(color: AppColors.surfaceLight.withValues(alpha: 0.5), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinEntry(bool isDark, Size size) {
    final empName = _selectedEmployee?['name'] ?? 'Employee';
    final empRole = _selectedEmployee?['role'] ?? '';
    final initial = empName.isNotEmpty ? empName[0].toUpperCase() : '?';

    return Center(
      child: Container(
        width: math.min(size.width - 48, 380),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceLight,
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimaryLight.withValues(alpha: isDark ? 0.3 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Back arrow
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary(context)),
                onPressed: () => setState(() => _selectedEmployee = null),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Employee avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF667eea).withValues(alpha: 0.15),
              child: Text(
                initial,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF667eea)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              empName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? AppColors.surfaceLight : AppColors.textSecondary(context)),
            ),
            if (empRole.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(empRole, style: const TextStyle(fontSize: 12, color: Color(0xFF667eea), fontWeight: FontWeight.w500)),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            Text(AppLocalizations.t(context, 'Enter 4-digit PIN'), style: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), fontSize: 13)),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _pinController,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                letterSpacing: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: "â€¢ â€¢ â€¢ â€¢",
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 24, letterSpacing: 12),
                filled: true,
                fillColor: isDark ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textPrimaryLight.withValues(alpha: 0.03),
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
                ),
                counterText: "",
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (value.length == 4) {
                  _handleLogin();
                }
              },
            ),
            const SizedBox(height: AppSpacing.xxs),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: AppColors.surfaceLight,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.surfaceLight, strokeWidth: 2.5))
                    : Text(AppLocalizations.t(context, 'LOGIN'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Magic Link UI â”€â”€â”€
  Widget _buildMagicLinkUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1B2A), const Color(0xFF1B2838)]
                : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceLight,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: isDark ? 0.3 : 0.15), blurRadius: 30, offset: const Offset(0, 12)),
              ],
            ),
            child: _isFetchingDetails
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.md),
                      Text(AppLocalizations.t(context, 'Loading store details...'), style: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context))),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceLight,
                          border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.2), width: 2),
                        ),
                        child: ClipOval(
                          child: _storeImage != null && _storeImage!.isNotEmpty
                              ? CachedNetworkImage(imageUrl: _storeImage!, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Image.asset('assets/logo.jpg', fit: BoxFit.cover))
                              : Image.asset('assets/logo.jpg', fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 36, color: AppColors.primaryLight)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _storeName ?? _storeCodeController.text,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.surfaceLight : AppColors.textSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF667eea).withValues(alpha: 0.15),
                              child: Text(
                                _employeeName != null && _employeeName!.isNotEmpty ? _employeeName![0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF667eea)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _employeeName ?? "Employee",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.surfaceLight : AppColors.textSecondary(context)),
                            ),
                            if (_employeeRole != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Text(_employeeRole!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF667eea))),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(AppLocalizations.t(context, 'Enter your 4-digit PIN to login'),
                          style: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), fontSize: 13)),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _pinController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          letterSpacing: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: "â€¢ â€¢ â€¢ â€¢",
                          hintStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 24, letterSpacing: 12),
                          filled: true,
                          fillColor: isDark ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textSecondary(context),
                          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
                          ),
                          counterText: "",
                          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                        obscureText: true,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: AppColors.surfaceLight,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.surfaceLight, strokeWidth: 2))
                              : Text(AppLocalizations.t(context, 'LOGIN'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(AppLocalizations.t(context, 'Back to Admin Login'), style: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), fontSize: 12)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Standard UI (Full form) â”€â”€â”€
  Widget _buildStandardUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1B2A), const Color(0xFF1B2838)]
                : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // â”€â”€ Logo â”€â”€
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceLight,
                        boxShadow: [
                          BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/logo.jpg', fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 40, color: AppColors.primaryLight)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(AppLocalizations.t(context, 'Employee Login'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.surfaceLight)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(AppLocalizations.t(context, 'Enter your store credentials'), style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: AppSpacing.xl),

                    // â”€â”€ Login Card â”€â”€
                    Container(
                      width: math.min(size.width - 48, 420),
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.zero,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimaryLight.withValues(alpha: isDark ? 0.3 : 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _storeCodeController,
                            style: TextStyle(color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight),
                            decoration: InputDecoration(
                              labelText: "Store Code",
                              labelStyle: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                              prefixIcon: Icon(Icons.business, color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), size: 20),
                              filled: true,
                              fillColor: isDark ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textSecondary(context),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _empIdController,
                                  style: TextStyle(color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight),
                                  decoration: InputDecoration(
                                    labelText: "Employee ID",
                                    labelStyle: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                                    prefixIcon: Icon(Icons.badge, color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), size: 20),
                                    filled: true,
                                    fillColor: isDark ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textSecondary(context),
                                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
                                    ),
                                    counterText: "",
                                  ),
                                  maxLength: 4,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: _pinController,
                                  style: TextStyle(color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight),
                                  decoration: InputDecoration(
                                    labelText: "PIN",
                                    labelStyle: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                                    prefixIcon: Icon(Icons.lock, color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), size: 20),
                                    filled: true,
                                    fillColor: isDark ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textSecondary(context),
                                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
                                    ),
                                    counterText: "",
                                  ),
                                  obscureText: true,
                                  maxLength: 4,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    if (value.length == 4) {
                                      _handleLogin();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                foregroundColor: AppColors.surfaceLight,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.surfaceLight, strokeWidth: 2))
                                  : Text(AppLocalizations.t(context, 'LOGIN TO STORE'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: () {
                              if (_pinnedStore != null) {
                                setState(() => _showManualForm = false);
                              } else {
                                context.go('/login');
                              }
                            },
                            child: Text(
                              _pinnedStore != null ? "â† Back to Employee Select" : "Back to Admin Login",
                              style: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


