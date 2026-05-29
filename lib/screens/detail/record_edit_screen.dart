import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../models/food.dart';
import '../../models/food_history.dart';

class RecordEditScreen extends StatefulWidget {
  final Food food;
  final FoodHistory? record; // non-null = editing existing record; null = creating new record

  const RecordEditScreen({super.key, required this.food, this.record});

  @override
  State<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends State<RecordEditScreen> {
  DateTime? _productionDate;
  final TextEditingController _shelfLifeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedMerchantName;
  bool _isSaving = false;

  bool get isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final r = widget.record!;
      _productionDate = r.productionDate != null ? DateTime.tryParse(r.productionDate!) : null;
      if (r.shelfLifeDays != null && r.shelfLifeDays! > 0) {
        _shelfLifeController.text = '${r.shelfLifeDays}';
      }
      _quantityController.text = '${r.quantity}';
      _selectedMerchantName = r.merchantName;
    }
  }

  @override
  void dispose() {
    _shelfLifeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑记录' : '新增记录'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Production date
            _buildDateField(),
            const SizedBox(height: 20),

            // Shelf life days
            _buildShelfLifeField(),
            const SizedBox(height: 20),

            // Merchant selector
            _buildMerchantSelector(),
            const SizedBox(height: 20),

            // Quantity
            _buildQuantityField(),
            const SizedBox(height: 28),

            // Auto-calculated expiry display
            _buildExpiryDisplay(),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('保  存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '生产日期',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          _productionDate != null ? DateFormat('yyyy年MM月dd日').format(_productionDate!) : '请选择日期',
          style: TextStyle(
            color: _productionDate != null ? Colors.black87 : Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildShelfLifeField() {
    return TextField(
      controller: _shelfLifeController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '保质期（天）',
        hintText: '请输入保质期天数',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.timelapse),
        suffixText: '天',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildMerchantSelector() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final merchants = appState.merchants;
        return DropdownButtonFormField<String>(
          value: _selectedMerchantName,
          decoration: InputDecoration(
            labelText: '商家名称（可选）',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.store),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('无', style: TextStyle(color: Colors.grey)),
            ),
            ...merchants.map((m) => DropdownMenuItem(
              value: m.name,
              child: Text(m.name),
            )),
          ],
          onChanged: (val) => setState(() => _selectedMerchantName = val),
        );
      },
    );
  }

  Widget _buildQuantityField() {
    return TextField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '食品数量',
        hintText: '请输入数量',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.inventory),
      ),
    );
  }

  Widget _buildExpiryDisplay() {
    String? expiryDateStr;
    String remainingText = '—';
    Color color = Colors.grey;

    final shelfLifeDays = int.tryParse(_shelfLifeController.text);

    if (_productionDate != null && shelfLifeDays != null && shelfLifeDays > 0) {
      final expiry = _productionDate!.add(Duration(days: shelfLifeDays));
      expiryDateStr = DateFormat('yyyy年MM月dd日').format(expiry);

      final now = DateTime.now();
      final diff = expiry.difference(now);
      if (diff.isNegative) {
        remainingText = '已过期 ${diff.inDays.abs()}天';
        color = const Color(0xFFF44336);
      } else {
        final days = diff.inDays;
        final years = days ~/ 365;
        final months = (days % 365) ~/ 30;
        final remainingDays = days - years * 365 - months * 30;
        if (years > 0) {
          remainingText = '距离到期还有 ${years}年${months}个月${remainingDays}天';
        } else if (months > 0) {
          remainingText = '距离到期还有 ${months}个月${remainingDays}天';
        } else {
          remainingText = '距离到期还有 $days天';
        }
        color = days <= 30 ? const Color(0xFFF44336) : const Color(0xFF4CAF50);
      }
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Text(
            '到期日：${expiryDateStr ?? '—'}（自动计算）',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.blue[800]),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            remainingText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _productionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh'),
    );
    if (date != null) {
      setState(() => _productionDate = date);
    }
  }

  Future<void> _save() async {
    final shelfLifeDays = int.tryParse(_shelfLifeController.text);
    if (shelfLifeDays == null || shelfLifeDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的保质期天数')),
      );
      return;
    }

    final quantityText = _quantityController.text.trim();
    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效数量')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();
      final now = DateTime.now().toIso8601String();

      String? expiryDate;
      if (_productionDate != null && shelfLifeDays > 0) {
        expiryDate = _productionDate!.add(Duration(days: shelfLifeDays)).toIso8601String();
      }

      int? daysRemaining;
      if (expiryDate != null) {
        final expiry = DateTime.tryParse(expiryDate);
        if (expiry != null) {
          daysRemaining = expiry.difference(DateTime.now()).inDays;
        }
      }

      if (isEditing) {
        // Update the existing record
        final updatedRecord = widget.record!.copyWith(
          productionDate: _productionDate?.toIso8601String(),
          quantity: quantity,
          expiryDate: expiryDate,
          daysRemaining: daysRemaining,
          merchantName: _selectedMerchantName,
          shelfLifeDays: shelfLifeDays,
        );
        await appState.updateRecord(updatedRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功，记录已更新')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create a new record
        final history = FoodHistory(
          foodId: widget.food.id!,
          foodName: widget.food.name,
          productionDate: _productionDate?.toIso8601String(),
          quantity: quantity,
          expiryDate: expiryDate,
          daysRemaining: daysRemaining,
          recordedAt: now,
          merchantName: _selectedMerchantName,
          shelfLifeDays: shelfLifeDays,
        );
        await appState.saveRecord(widget.food, history);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功，已创建新记录')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
