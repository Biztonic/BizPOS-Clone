import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math';

import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/models/inventory_item.dart' as legacy;
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/models/order_model.dart';
import '../../data/mappers/inventory_mapper.dart';
import 'dart:io';

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

  StreamSubscription? _orderCreatedSub;
  StreamSubscription? _syncCompletedSub;

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
    
    // Listen to OrderCreatedEvent to decrement stock instantly after checkout
    _orderCreatedSub = EventBus.instance.on<OrderCreatedEvent>((event) {
      _handleOrderCreatedEvent(event);
    });

    // Listen to SyncCompletedEvent to reload inventory from cache/DB
    _syncCompletedSub = EventBus.instance.on<SyncCompletedEvent>((event) {
      if (event.storeId == _storeProvider.activeStore?.id) {
        loadInventory();
      }
    });
    
    // Initial load if store is already selected
    if (_storeProvider.activeStore != null) {
      loadInventory();
    }
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

  // ─── Legacy Bridge Getters ────────────────────────────────

  /// Backward compatibility for legacy modules expecting [InventoryItem].
  List<legacy.InventoryItem> get storeInventory => _items.map<legacy.InventoryItem>(InventoryMapper.toLegacy).toList();

  /// Gets the quantity of a specific item.
  int getItemStock(String itemId) {
    try {
      return _items.firstWhere((e) => e.id == itemId).quantity;
    } catch (_) {
      return 0;
    }
  }

  /// Gets the cost of a specific item.
  double getItemCost(String itemId) {
    try {
      return _items.firstWhere((e) => e.id == itemId).cost;
    } catch (_) {
      return 0.0;
    }
  }

  /// Returns items filtered by category and search query.
  List<InventoryEntity> get filteredItems {
    var filtered = List<InventoryEntity>.from(_items);

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
    _orderCreatedSub?.cancel();
    _syncCompletedSub?.cancel();
    super.dispose();
  }

  /// Decrement stock in-memory for each item in the order.
  /// This gives instant UI feedback without waiting for a full reload.
  void _handleOrderCreatedEvent(OrderCreatedEvent event) {
    try {
      // Extract order items from the event
      final order = event.order;
      List<dynamic> orderItems;
      if (order is OrderModel) {
        orderItems = order.items;
      } else {
        // OrderEntity path
        orderItems = (order as dynamic).items as List<dynamic>;
      }

      bool didUpdate = false;
      for (final orderItem in orderItems) {
        String itemId;
        int qty;
        if (orderItem is OrderItem) {
          itemId = orderItem.item.id;
          qty = orderItem.quantity;
        } else {
          // OrderItemEntity from checkout orchestrator
          itemId = (orderItem as dynamic).itemId as String;
          qty = (orderItem as dynamic).quantity as int;
        }

        final idx = _items.indexWhere((e) => e.id == itemId);
        if (idx != -1 && _items[idx].trackStock) {
          final currentQty = _items[idx].quantity;
          final newQty = max(0, currentQty - qty);
          _items[idx] = _items[idx].copyWith(quantity: newQty);
          didUpdate = true;
        }
      }

      if (didUpdate) {
        // Recalculate stats after stock update
        _recalcStats();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('InventoryProvider: Error handling OrderCreatedEvent: $e');
    }
  }

  /// Recalculate inventory stats from in-memory items.
  void _recalcStats() {
    if (_items.isEmpty) return;
    final totalItems = _items.length;
    final lowStock = _items.where((e) => e.trackStock && e.quantity <= e.lowStockThreshold && e.quantity > 0).length;
    final outOfStock = _items.where((e) => e.trackStock && e.quantity <= 0).length;
    final totalCostValue = _items.fold<double>(0, (sum, e) => sum + (e.cost * e.quantity));
    final totalRetailValue = _items.fold<double>(0, (sum, e) => sum + (e.price * e.quantity));
    final categoriesCount = _items.map((e) => e.category).toSet().length;
    _stats = InventoryStats(
      totalItems: totalItems,
      lowStockItems: lowStock,
      outOfStockItems: outOfStock,
      totalCostValue: totalCostValue,
      totalRetailValue: totalRetailValue,
      categoriesCount: categoriesCount,
    );
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
      final rawItems = result.data ?? [];
      final healedItems = <InventoryEntity>[];
      
      for (final item in rawItems) {
        if (item.storeId == null || item.storeId!.isEmpty) {
          final healed = item.copyWith(storeId: storeId);
          healedItems.add(healed);
          // Async self-healing save in background
          _repository.insertItem(healed);
        } else {
          healedItems.add(item);
        }
      }

      _items = healedItems;
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
    final itemStoreId = (item.storeId != null && item.storeId!.isNotEmpty) ? item.storeId : storeId;
    final targetItem = (isNew ? item.copyWith(id: const Uuid().v4()) : item).copyWith(storeId: itemStoreId);
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

  // ─── Legacy Bridge Methods ────────────────────────────────

  /// Backward compatibility for legacy fetch requests.
  Future<void> fetchInventory(String uid, {bool refresh = false}) => loadInventory();

  /// Clears the current inventory state.
  void clearInventory() {
    _items = [];
    notifyListeners();
  }

  /// Bridge for legacy add operations.
  Future<void> addInventoryItem(legacy.InventoryItem item, String storeId, {File? imageFile}) => 
    saveItem(InventoryMapper.fromLegacy(item));

  /// Bridge for legacy update operations.
  Future<void> updateInventoryItem(legacy.InventoryItem item, {File? imageFile}) => 
    saveItem(InventoryMapper.fromLegacy(item));

  /// Bridge for legacy delete operations.
  Future<void> deleteInventoryItem(String id) => deleteItem(id);
}
