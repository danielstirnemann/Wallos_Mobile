import 'package:flutter/material.dart';
import '../models/subscription.dart';

class SubscriptionFormDialog extends StatefulWidget {
  final Subscription? subscription;
  final Function(Map<String, dynamic>) onSave;

  const SubscriptionFormDialog({
    super.key,
    this.subscription,
    required this.onSave,
  });

  @override
  State<SubscriptionFormDialog> createState() => _SubscriptionFormDialogState();
}

class _SubscriptionFormDialogState extends State<SubscriptionFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _nextPaymentController;

  late int _selectedCurrency;
  late int _selectedCategory;
  late int _selectedPaymentMethod;
  late int _selectedCycle;
  late int _selectedFrequency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = 12;
    _selectedCategory = 2;
    _selectedPaymentMethod = 1;
    _selectedCycle = 3;
    _selectedFrequency = 1;
    
    _nameController = TextEditingController(text: widget.subscription?.name ?? '');
    _priceController = TextEditingController(text: widget.subscription?.price.toString() ?? '');
    _nextPaymentController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _nextPaymentController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _nextPaymentController.text = picked.toString().split(' ')[0];
    }
  }

  void _save() {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Name und Preis ausfüllen')),
      );
      return;
    }

    widget.onSave({
      'id': widget.subscription?.id,
      'name': _nameController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'currency_id': _selectedCurrency,
      'category_id': _selectedCategory,
      'payment_method_id': _selectedPaymentMethod,
      'cycle': _selectedCycle,
      'frequency': _selectedFrequency,
      'next_payment': _nextPaymentController.text.isEmpty
          ? DateTime.now().toString().split(' ')[0]
          : _nextPaymentController.text,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.subscription == null ? 'Abo hinzufügen' : 'Abo bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nextPaymentController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Nächste Zahlung',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectDate,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedCycle,
              decoration: const InputDecoration(
                labelText: 'Zyklus',
                border: OutlineInputBorder(),
              ),
              items: [1, 3, 6, 12].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCycle = value ?? 3);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
