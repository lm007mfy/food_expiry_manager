import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/food.dart';
import '../models/merchant.dart';
import '../screens/detail/merchant_foods_screen.dart';

class FilterDrawer extends StatelessWidget {
  final void Function(Food food)? onFoodTap;

  const FilterDrawer({super.key, this.onFoodTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final categories = appState.categories;
        final merchants = appState.merchants;
        final foods = appState.foods;

        // Group foods by category
        final Map<int, List<Food>> foodsByCat = {};
        final List<Food> uncategorized = [];
        for (final food in foods) {
          if (food.categoryId != null) {
            foodsByCat.putIfAbsent(food.categoryId!, () => []).add(food);
          } else {
            uncategorized.add(food);
          }
        }

        // DEFECT-1: Use merchant food counts from history table (via AppState)
        final merchantFoodCount = appState.merchantFoodCounts;

        return Drawer(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF4CAF50)),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text('筛选', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),

                // Category section
                _buildSectionHeader('📂 食品分类'),
                if (uncategorized.isNotEmpty)
                  _buildCategoryExpansion('未分类', '📦', uncategorized, context),
                ...categories.where((c) => c.id != null && foodsByCat.containsKey(c.id)).map(
                  (cat) => _buildCategoryExpansion(
                    cat.name,
                    cat.icon ?? '📦',
                    foodsByCat[cat.id]!,
                    context,
                  ),
                ),
                if (uncategorized.isEmpty && foodsByCat.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('暂无食品', style: TextStyle(color: Colors.grey)),
                  ),

                const Divider(),

                // Merchant section - show ALL merchants
                _buildSectionHeader('🏪 商家分类'),
                if (merchants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('暂无商家', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...merchants.where((m) => m.name.isNotEmpty).map(
                    (merchant) => _buildMerchantTile(context, merchant, merchantFoodCount, appState),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMerchantTile(
    BuildContext context,
    Merchant merchant,
    Map<String, int> merchantFoodCount,
    AppState appState,
  ) {
    final count = merchantFoodCount[merchant.name] ?? 0;
    final hasNoFoods = count == 0;

    return ListTile(
      leading: Icon(
        Icons.store,
        size: 22,
        color: hasNoFoods ? Colors.grey[400] : null,
      ),
      title: Text(
        '${merchant.name} ($count)',
        style: TextStyle(
          color: hasNoFoods ? Colors.grey[500] : null,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: hasNoFoods ? Colors.grey[300] : Colors.grey,
      ),
      onLongPress: hasNoFoods ? () => _confirmDeleteMerchant(context, merchant, appState) : null,
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantFoodsScreen(merchantName: merchant.name),
          ),
        );
      },
    );
  }

  void _confirmDeleteMerchant(BuildContext context, Merchant merchant, AppState appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange[700]),
                const SizedBox(height: 12),
                Text(
                  '确认删除商家「${merchant.name}」吗？',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '该商家没有关联的食品',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('取消', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          Navigator.pop(context); // Close drawer too
                          await appState.deleteMerchant(merchant.id!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已删除商家「${merchant.name}」')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('删除', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCategoryExpansion(String name, String icon, List<Food> foods, BuildContext context) {
    return ExpansionTile(
      leading: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text('$name (${foods.length})'),
      children: foods.map((food) => _buildFoodTile(food, context)).toList(),
    );
  }

  Widget _buildFoodTile(Food food, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      title: Text(food.name),
      subtitle: Text(food.remainingText, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (onFoodTap != null) {
          onFoodTap!(food);
        }
      },
    );
  }
}
