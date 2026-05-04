import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';

import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository_interface.dart';
import '../../application/inventory_orchestrator.dart';

/// Presentation layer state manager for the Inventory module.
///
/// Handles optimistic UI updates, filtering, and interacts
/// with the [InventoryOrchestrator] for data mutations.
class InventoryProvider extends ChangeNotifier {
  final InventoryRepositoryInterface _repository;
  final InventoryOrchestrator _orchestrator;
  final StoreProvider _storeProvider;
  final SyncService _syncService;

  InventoryProvider({
    required InventoryRepositoryInterface repository,
    required InventoryOrchestrator orchestrator,
    required StoreProvider storeProvider,
    required SyncService syncService,
  })  : _repository = repository,
        _orchestrator = orchestrator,
        _storeProvider = storeProvider,
        _syncService = syncService {
    // Listen to store changes to reload data
    _storeProvider.addListener(_onStoreChanged);
  }

  // ─── State ───────────────────────────────────────────────

  List<InventoryEntity> _items = [];
  bool _isLoading = false;
  String? _error;
  
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  InventoryStats? _stats;

  // ─── Getters ─────────────────────────────────────────────

  List<InventoryEntity> get allItems => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  List<String> get categories => _categories;
  InventoryStats? get stats => _stats;

  /// Returns items filtered by category and search query.
  List<InventoryEntity> get filteredItems {
    var filtered = _items;

    // Filter by Category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((item) => item.category == _selectedCategory).toList();
    }

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
            (item.sku?.toLowerCase().contains(query) ?? false) ||
            item.category.toLowerCase().contains(query);
      }).toList();
    }

    // Sort alphabetically
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  // ─── Lifecycle ───────────────────────────────────────────

  @override
  void dispose() {
    _storeProvider.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (_storeProvider.activeStore != null) {
      loadInventory();
    }
  }

  // ─── Data Loading ────────────────────────────────────────

  /// Loads all inventory items for the current store.
  Future<void> loadInventory() async {
    final storeId = _storeProvider.activeStore?.id;
    if (storeId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.getItems(storeId);
    
    if (result.isSuccess) {
      _items = result.data ?? [];
      await _loadCategories(storeId);
      await _loadStats(storeId);
    } else {
      _error = result.error;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCategories(String storeId) async {
    final result = await _repository.getCategories(storeId);
    if (result.isSuccess) {
      _categories = ['All', ...?result.data];
    }
  }

  Future<void> _loadStats(String storeId) async {
    final result = await _repository.getInventoryStats(storeId);
    if (result.isSuccess) {
      _stats = result.data;
    }
  }

  // ─── Mutations (Orchestrated) ────────────────────────────

  /// Create or update an inventory item.
  Future<bool> saveItem(InventoryEntity item) async {
    final storeId = _storeProvider.activeStore?.id;
    if (storeId == null) {
      _error = 'No active store selected.';
      notifyListeners();
      return false;
    }

    final isNew = item.id.isEmpty;
    final targetItem = isNew ? item.copyWith(id: const Uuid().v4()) : item;
    final deviceId = _syncService.deviceId ?? 'UNKNOWN';

    // 1. Optimistic UI Update
    final index = _items.indexWhere((e) => e.id == targetItem.id);
    if (index >= 0) {
      _items[index] = targetItem;
    } else {
      _items.add(targetItem);
    }
    notifyListeners();

    // 2. Orchestrate Persistence
    final params = UpsertItemParams(
      item: targetItem,
      activeStoreId: storeId,
      deviceId: deviceId,
      idempotencyKey: 'inv_upsert_${targetItem.id}_${DateTime.now().millisecondsSinceEpoch}',
    );

    final result = await _orchestrator.upsertItem(params);

    // 3. Handle Result
    if (!result.isSuccess) {
      _error = result.error;
      await loadInventory(); // Rollback on failure
      return false;
    }

    // Refresh aggregations
    await _loadCategories(storeId);
    await _loadStats(storeId);
    notifyListeners();
    return true;
  }

  /// Delete an inventory item.
  Future<bool> deleteItem(String itemId) async {
    final storeId = _storeProvider.activeStore?.id;
    if (storeId == null) return false;

    // 1. Optimistic UI Update
    final backup = List<InventoryEntity>.from(_items);
    _items.removeWhere((e) => e.id == itemId);
    notifyListeners();

    // 2. Orchestrate Deletion
    final result = await _orchestrator.deleteItem(
      itemId: itemId,
      storeId: storeId,
    );

    // 3. Handle Result
    if (!result.isSuccess) {
      _error = result.error;
      _items = backup; // Rollback
      notifyListeners();
      return false;
    }

    await _loadCategories(storeId);
    await _loadStats(storeId);
    notifyListeners();
    return true;
  }

  // ─── UI State Mutators ───────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    notifyListeners();
  }
}
