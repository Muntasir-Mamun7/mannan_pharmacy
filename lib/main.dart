import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MedicineProvider(),
      child: MaterialApp(
        title: 'Mannan Pharmacy',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: MedicineListPage(),
      ),
    );
  }
}

class Medicine {
  String name;
  bool isStockOut;
  DateTime stockOutDate;

  Medicine({required this.name, this.isStockOut = false, DateTime? stockOutDate})
      : stockOutDate = stockOutDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'isStockOut': isStockOut,
        'stockOutDate': stockOutDate.toIso8601String(),
      };

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'],
      isStockOut: json['isStockOut'],
      stockOutDate: DateTime.parse(json['stockOutDate']),
    );
  }
}

class MedicineProvider with ChangeNotifier {
  List<Medicine> _medicines = [];
  List<Medicine> get medicines => _medicines;

  MedicineProvider() {
    loadMedicines();
  }

  void addMedicine(Medicine medicine) {
    _medicines.add(medicine);
    saveMedicines();
    notifyListeners();
  }

  void removeMedicine(Medicine medicine) {
    _medicines.remove(medicine);
    saveMedicines();
    notifyListeners();
  }

  void toggleStockOut(Medicine medicine) {
    medicine.isStockOut = !medicine.isStockOut;
    medicine.stockOutDate = DateTime.now();
    saveMedicines();
    notifyListeners();
  }

  void saveMedicines() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> jsonList =
        _medicines.map((medicine) => jsonEncode(medicine.toJson())).toList();
    prefs.setStringList('medicines', jsonList);
  }

  void loadMedicines() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? jsonList = prefs.getStringList('medicines');
    if (jsonList != null) {
      _medicines = jsonList
          .map((jsonString) => Medicine.fromJson(jsonDecode(jsonString)))
          .toList();
      notifyListeners();
    }
  }
}

class MedicineListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mannan Pharmacy'),
      ),
      body: Column(
        children: [
          InventorySummary(),
          Expanded(
            child: Consumer<MedicineProvider>(
              builder: (context, medicineProvider, child) {
                return ListView.builder(
                  itemCount: medicineProvider.medicines.length,
                  itemBuilder: (context, index) {
                    Medicine medicine = medicineProvider.medicines[index];
                    return ListTile(
                      title: Text(medicine.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => MedicineDialog(
                                  medicine: medicine,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              medicineProvider.removeMedicine(medicine);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        medicineProvider.toggleStockOut(medicine);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => MedicineDialog(),
          );
        },
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Medicine List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.error_outline),
            label: 'Stock Out',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockOutPage()),
            );
          }
        },
      ),
    );
  }
}

class InventorySummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MedicineProvider>(
      builder: (context, medicineProvider, child) {
        int totalMedicines = medicineProvider.medicines.length;
        int stockOutMedicines =
            medicineProvider.medicines.where((med) => med.isStockOut).length;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text('Total Medicines: $totalMedicines'),
              Text('Stock Out: $stockOutMedicines'),
            ],
          ),
        );
      },
    );
  }
}

class StockOutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Out Medicines'),
      ),
      body: Consumer<MedicineProvider>(
        builder: (context, medicineProvider, child) {
          List<Medicine> stockOutMedicines =
              medicineProvider.medicines.where((med) => med.isStockOut).toList();
          return ListView.builder(
            itemCount: stockOutMedicines.length,
            itemBuilder: (context, index) {
              Medicine medicine = stockOutMedicines[index];
              return ListTile(
                title: Text(medicine.name),
                subtitle: Text('Stock Out Date: ${medicine.stockOutDate}'),
                trailing: IconButton(
                  icon: Icon(Icons.restore),
                  onPressed: () {
                    medicineProvider.toggleStockOut(medicine);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MedicineDialog extends StatefulWidget {
  final Medicine? medicine;

  MedicineDialog({this.medicine});

  @override
  _MedicineDialogState createState() => _MedicineDialogState();
}

class _MedicineDialogState extends State<MedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.medicine?.name ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.medicine == null ? 'Add Medicine' : 'Edit Medicine'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Medicine Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a name';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (widget.medicine == null) {
                Provider.of<MedicineProvider>(context, listen: false)
                    .addMedicine(Medicine(name: _nameController.text));
              } else {
                widget.medicine!.name = _nameController.text;
                Provider.of<MedicineProvider>(context, listen: false)
                    .saveMedicines();
              }
              Navigator.of(context).pop();
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}