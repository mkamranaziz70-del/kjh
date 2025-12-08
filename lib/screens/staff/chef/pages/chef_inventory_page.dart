// ✅ COMPLETE PROFESSIONAL InventoryPage - FULLY INTEGRATED WITH KITCHEN ORDERS
// 🔥 Shows usage history, recent deductions, low stock alerts, order summaries
// lib/pages/inventory_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_brace_in_string_interps

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryPage extends StatefulWidget {
  final String? shopId;
  const InventoryPage({super.key, this.shopId});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allInventoryItems = [];
  Map<String, List<Map<String, dynamic>>> _categoryInventory = {};
  bool _isLoading = false;
  String? _selectedCategory;
  List<String> _categories = [];
  String _activeTab = 'all';
  late TabController _tabController;
  int _unreadNotifications = 0;

  static const List<String> _units = [
    'units',
    'pieces',
    'kg',
    'grams',
    'litre',
    'ml',
    'packets',
    'boxes',
    'bags',
    'jars',
    'cans',
    'bottles',
    'dozen',
    'bundles',
    'trays',
    'slabs',
    'sachets',
    'cartons',
    'pounds',
    'oz',
    'gallons',
    'quarts',
    'pints',
    'slices',
    'sticks',
    'bars',
    'tubes',
    'rolls',
    'sheets',
    'packs',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    debugPrint('🔍 InventoryPage init - shopId: "${widget.shopId}"');
    _loadCategories();
    _loadInventory();
    _loadUnreadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ✅ NEW: Load unread notification count
  Future<void> _loadUnreadNotifications() async {
    if (widget.shopId == null) return;

    FirebaseFirestore.instance
        .collection('inventory_notifications')
        .where('shopId', isEqualTo: widget.shopId!)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _unreadNotifications = snapshot.docs.length;
            });
          }
        });
  }

  // ✅ NEW: Show notifications dialog
  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => NotificationsDialog(
        shopId: widget.shopId!,
        onNotificationsRead: () => setState(() => _unreadNotifications = 0),
      ),
    );
  }

  Future<void> _loadCategories() async {
    try {
      Query query = FirebaseFirestore.instance.collection('categories');
      if (widget.shopId != null) {
        query = query.where('shopId', isEqualTo: widget.shopId);
      }

      final snapshot = await query.get();
      debugPrint('📂 Found ${snapshot.docs.length} categories');

      if (mounted) {
        setState(() {
          _categories = snapshot.docs
              .map((doc) => doc['name']?.toString() ?? 'Uncategorized')
              .toList();
          if (_categories.isEmpty) {
            _categories = [
              'Burger',
              'Fries',
              'Drinks',
              'Desserts',
              'Veg',
              'Cleaning',
              'fast food',
            ];
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Categories error: $e');
    }
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔍 Loading inventory for shop: ${widget.shopId}');

      if (widget.shopId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('inventory')
          .where('shopId', isEqualTo: widget.shopId!)
          .get();

      final List<Map<String, dynamic>> items = [];
      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final category = data['category']?.toString() ?? 'Uncategorized';
        final name = data['name']?.toString() ?? 'Unknown';
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        final unit = data['unit']?.toString() ?? 'kg';

        debugPrint('✅ LOADED: "${name}" [${category}] ${quantity} ${unit}');

        items.add({
          'id': doc.id,
          'name': name,
          'category': category,
          'quantity': quantity,
          'unit': unit,
          'requiredFor': List<String>.from(data['requiredFor'] ?? []),
          'lastUpdated':
              data['updatedAt']?.toDate() ?? data['createdAt']?.toDate(),
        });
      }

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var item in items) {
        grouped.putIfAbsent(item['category'], () => []).add(item);
      }

      debugPrint('🎉 SUCCESS: Loaded ${items.length} items');

      if (mounted) {
        setState(() {
          _allInventoryItems = items;
          _categoryInventory = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Inventory error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading inventory: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    final query = _searchController.text.toLowerCase();
    if (_activeTab == 'all') {
      return _allInventoryItems
          .where(
            (item) =>
                item['name'].toString().toLowerCase().contains(query) ||
                item['category'].toString().toLowerCase().contains(query),
          )
          .toList();
    }
    final categoryItems = _categoryInventory[_activeTab] ?? [];
    return categoryItems
        .where((item) => item['name'].toString().toLowerCase().contains(query))
        .toList();
  }

  Future<void> _addStockItem() async {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category first')),
      );
      return;
    }
    if (widget.shopId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shop ID required')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        category: _selectedCategory!,
        shopId: widget.shopId!,
        units: _units,
        onItemAdded: _loadInventory,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => EditItemDialog(
        item: item,
        shopId: widget.shopId!,
        units: _units,
        onItemUpdated: _loadInventory,
      ),
    );
  }

  Future<void> _reduceStock(Map<String, dynamic> item) async {
    final qty = item['quantity']?.toDouble() ?? 0.0;
    if (qty <= 0) return;

    showDialog(
      context: context,
      builder: (context) => ReduceStockDialog(
        item: item,
        shopId: widget.shopId!,
        onReduced: _loadInventory,
      ),
    );
  }

  void _showUsageHistory(String inventoryId, String itemName) {
    showDialog(
      context: context,
      builder: (context) => UsageHistoryDialog(
        inventoryId: inventoryId,
        itemName: itemName,
        shopId: widget.shopId!,
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '📦 Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF13452E),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Stock'),
            Tab(icon: Icon(Icons.history), text: 'Usage'),
            Tab(icon: Icon(Icons.trending_down), text: 'Low Stock'),
          ],
        ),
        actions: [
          // ✅ NEW: Notification Bell with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _showNotifications,
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search items...',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.green),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildTabChip('all', 'All Categories'),
                          ..._categories.map((cat) => _buildTabChip(cat, cat)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                hint: const Text(
                                  'Select Category',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                isExpanded: true,
                                items: _categories
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedCategory = value),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _addStockItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Stock'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No inventory items found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add stock using the button above',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) =>
                            _buildInventoryCard(filteredItems[index]),
                      ),
              ),
            ],
          ),
          UsageHistoryTab(shopId: widget.shopId!),
          LowStockTab(shopId: widget.shopId!),
        ],
      ),
    );
  }

  Widget _buildTabChip(String value, String label) {
    final isSelected = _activeTab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _activeTab = value),
        selectedColor: Colors.green[100],
        checkmarkColor: Colors.green[700],
        backgroundColor: Colors.grey[200],
        elevation: isSelected ? 4 : 0,
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final qty = item['quantity']?.toDouble() ?? 0.0;
    final lowStock = qty < 5;
    final usedIn = (item['requiredFor'] as List?)?.join(', ') ?? 'None';
    final lastUpdated = _formatTimestamp(item['lastUpdated']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: lowStock ? Colors.red[100] : Colors.green[100],
          child: Icon(
            lowStock ? Icons.warning_amber : Icons.inventory_2,
            color: lowStock ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          item['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['category'],
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${qty.toStringAsFixed(2)} ${item['unit']}',
                  style: TextStyle(
                    color: lowStock ? Colors.red[700] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (lowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'LOW STOCK',
                      style: TextStyle(color: Colors.red[800], fontSize: 11),
                    ),
                  ),
              ],
            ),
            Text(
              'Last updated: $lastUpdated',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Used in: $usedIn',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showEditDialog(item),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[50]!,
                          foregroundColor: Colors.blue[700]!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showUsageHistory(item['id'], item['name']),
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('Usage History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[50]!,
                          foregroundColor: Colors.purple[700]!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: qty > 0 ? () => _reduceStock(item) : null,
                        icon: const Icon(Icons.remove, size: 16),
                        label: const Text('Use Stock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[50]!,
                          foregroundColor: Colors.orange[700]!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ NEW: Notifications Dialog
class NotificationsDialog extends StatelessWidget {
  final String shopId;
  final VoidCallback onNotificationsRead;

  const NotificationsDialog({
    super.key,
    required this.shopId,
    required this.onNotificationsRead,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.notifications, color: Colors.blue),
          const SizedBox(width: 12),
          const Text('Notifications'),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await _markAllAsRead();
              onNotificationsRead();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('inventory_notifications')
              .where('shopId', isEqualTo: shopId)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return NotificationCard(
                  notificationId: doc.id,
                  data: data,
                  onDismiss: onNotificationsRead,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final notifications = await FirebaseFirestore.instance
        .collection('inventory_notifications')
        .where('shopId', isEqualTo: shopId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }
}

// ✅ NEW: Notification Card
class NotificationCard extends StatelessWidget {
  final String notificationId;
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notificationId,
    required this.data,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = data['isRead'] ?? false;
    final message = data['message'] ?? 'Inventory updated';
    final type = data['type'] ?? 'info';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    Color bgColor = Colors.blue[50]!;
    Color iconColor = Colors.blue;
    IconData icon = Icons.info;

    if (type == 'low_stock') {
      bgColor = Colors.red[50]!;
      iconColor = Colors.red;
      icon = Icons.warning_amber;
    } else if (type == 'stock_reduced') {
      bgColor = Colors.orange[50]!;
      iconColor = Colors.orange;
      icon = Icons.trending_down;
    } else if (type == 'stock_added') {
      bgColor = Colors.green[50]!;
      iconColor = Colors.green;
      icon = Icons.add_circle;
    }

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await FirebaseFirestore.instance
            .collection('inventory_notifications')
            .doc(notificationId)
            .delete();
        onDismiss();
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.grey[100] : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.grey[300]! : iconColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class UsageHistoryTab extends StatelessWidget {
  final String shopId;
  const UsageHistoryTab({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory_usage')
          .where('shopId', isEqualTo: shopId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No usage history',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usage appears here when orders are completed',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return UsageHistoryCard(data: data);
          },
        );
      },
    );
  }
}

class UsageHistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const UsageHistoryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final itemName = data['itemName'] ?? 'Unknown';
    final usedQty = (data['usedQuantity'] as num?)?.toDouble() ?? 0.0;
    final prevQty = (data['previousQuantity'] as num?)?.toDouble() ?? 0.0;
    final newQty = (data['newQuantity'] as num?)?.toDouble() ?? 0.0;
    final unit = data['unit'] ?? 'kg';
    final orderId = data['orderId'] ?? 'N/A';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: Colors.purple[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Order #$orderId',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${prevQty.toStringAsFixed(2)} $unit',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Before',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '-${usedQty.toStringAsFixed(2)} $unit',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Used',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${newQty.toStringAsFixed(2)} $unit',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'After',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d ago';
  }
}

class LowStockTab extends StatelessWidget {
  final String shopId;
  const LowStockTab({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory')
          .where('shopId', isEqualTo: shopId)
          .where('quantity', isLessThan: 5.0)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'All stock levels good!',
                  style: TextStyle(fontSize: 18, color: Colors.green[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'No items below 5 units/kg',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return LowStockCard(itemData: data, itemId: doc.id);
          },
        );
      },
    );
  }
}

class LowStockCard extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final String itemId;
  const LowStockCard({super.key, required this.itemData, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final qty = (itemData['quantity'] as num?)?.toDouble() ?? 0.0;
    final name = itemData['name'] ?? 'Unknown';
    final unit = itemData['unit'] ?? 'kg';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red[700], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${qty.toStringAsFixed(2)} $unit',
                  style: TextStyle(color: Colors.red[700], fontSize: 16),
                ),
                Text(
                  '⚠️ RESTOCK REQUIRED',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UsageHistoryDialog extends StatelessWidget {
  final String inventoryId;
  final String itemName;
  final String shopId;

  const UsageHistoryDialog({
    super.key,
    required this.inventoryId,
    required this.itemName,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.history, color: Colors.purple),
          const SizedBox(width: 12),
          Text('$itemName Usage History'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: UsageHistoryTab(shopId: shopId),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class AddItemDialog extends StatefulWidget {
  final String category;
  final String shopId;
  final List<String> units;
  final VoidCallback onItemAdded;

  const AddItemDialog({
    super.key,
    required this.category,
    required this.shopId,
    required this.units,
    required this.onItemAdded,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  String _unit = 'kg';

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    if (_formKey.currentState!.validate()) {
      try {
        final qty = double.tryParse(_quantityController.text) ?? 0.0;

        await FirebaseFirestore.instance.collection('inventory').add({
          'shopId': widget.shopId,
          'category': widget.category,
          'name': _nameController.text.trim(),
          'quantity': qty,
          'unit': _unit,
          'requiredFor': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ✅ Create notification
        await FirebaseFirestore.instance.collection('inventory_notifications').add({
          'shopId': widget.shopId,
          'type': 'stock_added',
          'message':
              '${_nameController.text.trim()} added: ${qty.toStringAsFixed(2)} $_unit',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Stock added successfully!')),
          );
          widget.onItemAdded();
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error adding stock: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Add Stock Item - ${widget.category}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: const Icon(Icons.fastfood, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Enter item name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: const Icon(
                          Icons.numbers,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: _unit,
                      ),
                      validator: (value) => double.tryParse(value ?? '') == null
                          ? 'Enter valid quantity'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        DropdownButton<String>(
                          value: _unit,
                          underline: const SizedBox(),
                          items: widget.units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _unit = value!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Item'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class EditItemDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final String shopId;
  final List<String> units;
  final VoidCallback onItemUpdated;

  const EditItemDialog({
    super.key,
    required this.item,
    required this.shopId,
    required this.units,
    required this.onItemUpdated,
  });

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name']);
    _quantityController = TextEditingController(
      text: widget.item['quantity'].toString(),
    );
    _unit = widget.item['unit'] ?? 'kg';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _updateItem() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newQty = double.tryParse(_quantityController.text) ?? 0.0;
        final oldQty = (widget.item['quantity'] as num?)?.toDouble() ?? 0.0;

        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(widget.item['id'])
            .update({
              'shopId': widget.shopId,
              'name': _nameController.text.trim(),
              'quantity': newQty,
              'unit': _unit,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // ✅ Create notification
        await FirebaseFirestore.instance.collection('inventory_notifications').add({
          'shopId': widget.shopId,
          'type': 'info',
          'message':
              '${_nameController.text.trim()} updated: ${oldQty.toStringAsFixed(2)} → ${newQty.toStringAsFixed(2)} $_unit',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Item updated successfully!')),
          );
          widget.onItemUpdated();
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error updating item: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blue, size: 28),
          SizedBox(width: 16),
          Text('Edit Item', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Enter item name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: _unit,
                      ),
                      validator: (value) => double.tryParse(value ?? '') == null
                          ? 'Enter valid quantity'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        DropdownButton<String>(
                          value: _unit,
                          underline: const SizedBox(),
                          items: widget.units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _unit = value!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _updateItem,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ FIXED: Reduce Stock Dialog with PROPER UNIT CONVERSION
class ReduceStockDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final String shopId;
  final VoidCallback onReduced;

  const ReduceStockDialog({
    super.key,
    required this.item,
    required this.shopId,
    required this.onReduced,
  });

  @override
  State<ReduceStockDialog> createState() => _ReduceStockDialogState();
}

class _ReduceStockDialogState extends State<ReduceStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.item['unit'] ?? 'kg';
    _quantityController.text = '1.0';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // ✅ FIXED: Convert to base unit for universal comparison
  double _convertToBaseUnit(double value, String unit) {
    switch (unit.toLowerCase()) {
      // Weight: base = grams
      case 'kg':
        return value * 1000;
      case 'grams':
        return value;
      case 'pounds':
        return value * 453.592;
      case 'oz':
        return value * 28.3495;

      // Volume: base = ml
      case 'litre':
        return value * 1000;
      case 'ml':
        return value;
      case 'gallons':
        return value * 3785.41;
      case 'quarts':
        return value * 946.353;
      case 'pints':
        return value * 473.176;

      // Count: base = pieces
      case 'dozen':
        return value * 12;
      case 'pieces':
      case 'units':
      case 'packets':
      case 'boxes':
      case 'bags':
      case 'jars':
      case 'cans':
      case 'bottles':
      case 'bundles':
      case 'trays':
      case 'slabs':
      case 'sachets':
      case 'cartons':
      case 'slices':
      case 'sticks':
      case 'bars':
      case 'tubes':
      case 'rolls':
      case 'sheets':
      case 'packs':
        return value;

      default:
        return value;
    }
  }

  // ✅ FIXED: Convert from base unit back to target unit
  double _convertFromBaseUnit(double baseValue, String targetUnit) {
    switch (targetUnit.toLowerCase()) {
      // Weight: base = grams
      case 'kg':
        return baseValue / 1000;
      case 'grams':
        return baseValue;
      case 'pounds':
        return baseValue / 453.592;
      case 'oz':
        return baseValue / 28.3495;

      // Volume: base = ml
      case 'litre':
        return baseValue / 1000;
      case 'ml':
        return baseValue;
      case 'gallons':
        return baseValue / 3785.41;
      case 'quarts':
        return baseValue / 946.353;
      case 'pints':
        return baseValue / 473.176;

      // Count: base = pieces
      case 'dozen':
        return baseValue / 12;
      case 'pieces':
      case 'units':
      case 'packets':
      case 'boxes':
      case 'bags':
      case 'jars':
      case 'cans':
      case 'bottles':
      case 'bundles':
      case 'trays':
      case 'slabs':
      case 'sachets':
      case 'cartons':
      case 'slices':
      case 'sticks':
      case 'bars':
      case 'tubes':
      case 'rolls':
      case 'sheets':
      case 'packs':
        return baseValue;

      default:
        return baseValue;
    }
  }

  // ✅ FIXED: Check if units are compatible
  bool _areUnitsCompatible(String unit1, String unit2) {
    const weightUnits = ['kg', 'grams', 'pounds', 'oz'];
    const volumeUnits = ['litre', 'ml', 'gallons', 'quarts', 'pints'];
    const countUnits = [
      'pieces',
      'units',
      'dozen',
      'packets',
      'boxes',
      'bags',
      'jars',
      'cans',
      'bottles',
      'bundles',
      'trays',
      'slabs',
      'sachets',
      'cartons',
      'slices',
      'sticks',
      'bars',
      'tubes',
      'rolls',
      'sheets',
      'packs',
    ];

    final u1 = unit1.toLowerCase();
    final u2 = unit2.toLowerCase();

    if (weightUnits.contains(u1) && weightUnits.contains(u2)) return true;
    if (volumeUnits.contains(u1) && volumeUnits.contains(u2)) return true;
    if (countUnits.contains(u1) && countUnits.contains(u2)) return true;

    return false;
  }

  Future<void> _reduceStock() async {
    if (_formKey.currentState!.validate()) {
      try {
        final storedUnit = widget.item['unit'] as String;

        // ✅ Check if units are compatible
        if (!_areUnitsCompatible(storedUnit, _selectedUnit)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Cannot convert between $storedUnit and $_selectedUnit',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final double currentQty = (widget.item['quantity'] as num).toDouble();
        final double inputQty = double.parse(_quantityController.text);

        debugPrint(
          '🔄 CONVERSION: Input ${inputQty} $_selectedUnit from stock ${currentQty} $storedUnit',
        );

        // ✅ Convert current stock to base unit
        final double currentInBase = _convertToBaseUnit(currentQty, storedUnit);
        debugPrint('📊 Current in base: $currentInBase');

        // ✅ Convert input quantity to base unit
        final double reduceInBase = _convertToBaseUnit(inputQty, _selectedUnit);
        debugPrint('📊 Reduce in base: $reduceInBase');

        // ✅ Subtract in base units
        final double newInBase = (currentInBase - reduceInBase).clamp(
          0.0,
          double.infinity,
        );
        debugPrint('📊 New in base: $newInBase');

        // ✅ Convert result back to stored unit
        final double newQty = _convertFromBaseUnit(newInBase, storedUnit);
        debugPrint('✅ FINAL: ${newQty.toStringAsFixed(4)} $storedUnit');

        // ✅ Update Firestore
        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(widget.item['id'])
            .update({
              'quantity': newQty,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // ✅ Log usage history
        await FirebaseFirestore.instance.collection('inventory_usage').add({
          'shopId': widget.shopId,
          'inventoryId': widget.item['id'],
          'itemName': widget.item['name'],
          'usedQuantity': inputQty,
          'usedUnit': _selectedUnit,
          'previousQuantity': currentQty,
          'newQuantity': newQty,
          'unit': storedUnit,
          'orderId': 'MANUAL',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // ✅ Create notification
        await FirebaseFirestore.instance.collection('inventory_notifications').add({
          'shopId': widget.shopId,
          'type': newQty < 5 ? 'low_stock' : 'stock_reduced',
          'message':
              '${widget.item['name']}: -${inputQty.toStringAsFixed(2)} $_selectedUnit (${newQty.toStringAsFixed(2)} $storedUnit remaining)',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Reduced ${inputQty.toStringAsFixed(2)} $_selectedUnit\n'
                'Remaining: ${newQty.toStringAsFixed(2)} $storedUnit',
              ),
            ),
          );

          widget.onReduced();
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('❌ REDUCE STOCK ERROR: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxQty = (widget.item['quantity'] as num?)?.toDouble() ?? 0.0;
    final storedUnit = widget.item['unit'] as String;

    // Get compatible units
    List<String> compatibleUnits = [];
    if (['kg', 'grams', 'pounds', 'oz'].contains(storedUnit.toLowerCase())) {
      compatibleUnits = ['kg', 'grams', 'pounds', 'oz'];
    } else if ([
      'litre',
      'ml',
      'gallons',
      'quarts',
      'pints',
    ].contains(storedUnit.toLowerCase())) {
      compatibleUnits = ['litre', 'ml', 'gallons', 'quarts', 'pints'];
    } else {
      compatibleUnits = [
        'pieces',
        'units',
        'dozen',
        'packets',
        'boxes',
        'bags',
        'jars',
        'cans',
        'bottles',
        'bundles',
        'trays',
        'slabs',
        'sachets',
        'cartons',
        'slices',
        'sticks',
        'bars',
        'tubes',
        'rolls',
        'sheets',
        'packs',
      ];
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.remove, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text('${widget.item['name']} - Reduce Stock')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Text(
                    'Available: ${maxQty.toStringAsFixed(2)} $storedUnit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantity to reduce',
                prefixIcon: const Icon(
                  Icons.remove_circle,
                  color: Colors.orange,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                final qty = double.tryParse(value ?? '');
                if (qty == null || qty <= 0) return 'Enter valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: InputDecoration(
                labelText: 'Unit',
                prefixIcon: const Icon(Icons.straighten, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: compatibleUnits
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedUnit = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _reduceStock,
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Reduce Stock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
