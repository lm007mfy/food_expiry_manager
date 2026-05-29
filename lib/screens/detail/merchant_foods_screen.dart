import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/food.dart';
import '../../db/database_helper.dart';
import 'food_detail_screen.dart';

class MerchantFoodsScreen extends StatelessWidget {
  final String merchantName;

  const MerchantFoodsScreen({super.key, required this.merchantName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(merchantName),
      ),
      body: FutureBuilder<List<Food>>(
        future: _loadMerchantFoods(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final foods = snapshot.data!;
          if (foods.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('该商家暂无食品', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: foods.length,
            itemBuilder: (context, index) {
              final food = foods[index];
              final days = food.daysRemaining;
              final isExpired = days != null && days < 0;
              final remainingText = food.remainingText;
              final hasExpiry = food.expiryDate != null;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildImage(food),
                  ),
                  title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: hasExpiry
                      ? Text(
                          '距到期还有 $remainingText',
                          style: TextStyle(
                            color: isExpired ? const Color(0xFFF44336) : Colors.grey[600],
                            fontSize: 13,
                          ),
                        )
                      : Text('未设置保质期', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoodDetailScreen(
                          food: food,
                          merchantFilter: merchantName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Food>> _loadMerchantFoods() async {
    final db = DatabaseHelper();
    // v2.4: Query via food_history table to find all foods associated with this merchant
    return await db.getFoodsByMerchantName(merchantName);
  }

  Widget _buildImage(Food food) {
    if (food.imagePath != null && food.imagePath!.isNotEmpty) {
      final file = File(food.imagePath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.grey, size: 28),
        ),
      );
    }
    return const Icon(Icons.fastfood, color: Colors.grey, size: 28);
  }
}
