import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/food.dart';
import '../../models/food_history.dart';
import '../../db/database_helper.dart';
import '../detail/food_detail_screen.dart';
import '../../widgets/filter_drawer.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('食品管理'),
      ),
      drawer: FilterDrawer(
        onFoodTap: (food) => _openDetail(context, food),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildFoodList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFabMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索食品或商家...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              appState.setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    appState.setSearchQuery(val);
                    setState(() {}); // for clear button
                  },
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('筛选', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        const SizedBox(width: 4),
                        Icon(Icons.filter_list, size: 18, color: Colors.grey[700]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoodList() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final foods = appState.filteredFoods;
        if (foods.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  appState.searchQuery.isNotEmpty ? '未找到匹配的食品' : '暂无食品，点击右下角添加',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
            return _FoodListItem(
              food: food,
              onTap: () => _openDetail(context, food),
              onDelete: () => _confirmDelete(context, appState, food),
              onLongPress: () => _confirmHardDelete(context, appState, food),
            );
          },
        );
      },
    );
  }

  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.fastfood, color: Color(0xFF4CAF50)),
                title: const Text('增加食品'),
                subtitle: const Text('添加新的食品到管理列表'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddFoodDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.store, color: Color(0xFF2196F3)),
                title: const Text('增加商家'),
                subtitle: const Text('添加新的商家'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddMerchantDialog(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showAddFoodDialog(BuildContext context) {
    final controller = TextEditingController();
    final appState = context.read<AppState>();
    int? selectedCategoryId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final categories = appState.categories;
            return AlertDialog(
              title: const Text('新增食品'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '食品名称',
                      hintText: '请输入食品名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: '分类',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Text('${cat.icon ?? ''} ${cat.name}'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入食品名称')),
                      );
                      return;
                    }
                    appState.addFood(name, categoryId: selectedCategoryId);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMerchantDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('新增商家'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '商家名称',
              hintText: '请输入商家名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入商家名称')),
                  );
                  return;
                }
                try {
                  await context.read<AppState>().addMerchant(name);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加商家「$name」')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败：$e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _openDetail(BuildContext context, Food food) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food)),
    ).then((_) {
      // Refresh when returning from detail
      context.read<AppState>().refreshFoods();
    });
  }

  void _confirmDelete(BuildContext context, AppState appState, Food food) async {
    final historyCount = await appState.db.getHistoryCount(food.id!);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(
            historyCount > 0
                ? '确定删除「${food.name}」吗？\n该食品有 $historyCount 条历史记录，历史记录将保留。\n删除后可在导出中找回。'
                : '确定删除「${food.name}」吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                appState.deleteFood(food.id!);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除「${food.name}」')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// v2.6: Long-press hard delete — permanently remove food and all related records
  void _confirmHardDelete(BuildContext context, AppState appState, Food food) async {
    final historyCount = await appState.db.getHistoryCount(food.id!);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              const Text('彻底删除', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(
            historyCount > 0
                ? '确定彻底删除「${food.name}」吗？\n\n该食品有 $historyCount 条历史记录，\n删除后所有记录将一并永久清除，\n且无法恢复！'
                : '确定彻底删除「${food.name}」吗？\n\n删除后无法恢复！',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await appState.hardDeleteFood(food.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已彻底删除「${food.name}」')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('彻底删除'),
            ),
          ],
        );
      },
    );
  }
}

class _FoodListItem extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  const _FoodListItem({
    required this.food,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(food.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildImage(),
          ),
          title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: _buildNearestExpirySubtitle(),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  Widget _buildNearestExpirySubtitle() {
    return FutureBuilder<FoodHistory?>(
      future: DatabaseHelper().getNearestExpiryRecord(food.id!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text('未设置保质期', style: TextStyle(color: Colors.grey[400], fontSize: 13));
        }
        final record = snapshot.data;
        if (record == null) {
          return Text('未设置保质期', style: TextStyle(color: Colors.grey[400], fontSize: 13));
        }

        final merchantName = record.merchantName;
        final days = record.realDaysRemaining ?? record.daysRemaining; // BUG-3: real-time
        final remainingText = record.remainingText;
        final isExpired = days != null && days < 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (merchantName != null && merchantName.isNotEmpty)
              Text(
                '厂家：$merchantName',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            days != null
                ? Text(
                    '还剩 $remainingText',
                    style: TextStyle(
                      color: isExpired ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Text('未设置保质期', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        );
      },
    );
  }

  Widget _buildImage() {
    if (food.imagePath != null && food.imagePath!.isNotEmpty) {
      final file = File(food.imagePath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        ),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    final firstChar = food.name.isNotEmpty ? food.name.substring(0, 1) : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
      ),
    );
  }
}
