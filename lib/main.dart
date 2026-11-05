import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:pasteboard/pasteboard.dart';

const navy = Color(0xFF12345B);
const blue = Color(0xFF1D70B8);
final dates = DateFormat('dd/MM/yyyy');
final fullDates = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  runApp(App(store: store));
}

class App extends StatelessWidget {
  final AppStore store;
  const App({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Inspeksi & Monitoring',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: navy),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  }
}

class Unit {
  String id;
  String name;
  String code;
  Unit({required this.id, required this.name, this.code = ''});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code};
  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String,
      name: json['name'] as String,
      code: (json['code'] ?? '') as String,
    );
  }
}

class Staff {
  String id;
  String name;
  String position;
  Staff({required this.id, required this.name, this.position = ''});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position,
  };
  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      name: json['name'] as String,
      position: (json['position'] ?? '') as String,
    );
  }
}

class Finding {
  String text;
  String? picId;
  DateTime? target;
  Finding({this.text = '', this.picId, this.target});

  Map<String, dynamic> toJson() => {
    'text': text,
    'picId': picId,
    'target': target?.toIso8601String(),
  };
  factory Finding.fromJson(Map<String, dynamic> json) {
    return Finding(
      text: (json['text'] ?? '') as String,
      picId: json['picId'] as String?,
      target: json['target'] == null
          ? null
          : DateTime.tryParse(json['target'] as String),
    );
  }
}

class Inspection {
  String id;
  DateTime date;
  String unitId;
  List<Finding> findings;
  String notes;
  String? picSignerId;
  String? signature;
  String compositeImage;

  Inspection({
    required this.id,
    required this.date,
    required this.unitId,
    required this.findings,
    this.notes = '',
    this.picSignerId,
    this.signature,
    this.compositeImage = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'unitId': unitId,
    'findings': findings.map((item) => item.toJson()).toList(),
    'notes': notes,
    'picSignerId': picSignerId,
    'signature': signature,
    'compositeImage': compositeImage,
  };

  factory Inspection.fromJson(Map<String, dynamic> json) {
    final rawFindings = (json['findings'] as List<dynamic>? ?? []);
    return Inspection(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      unitId: json['unitId'] as String,
      findings: rawFindings
          .map((item) => Finding.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      notes: (json['notes'] ?? '') as String,
      picSignerId: json['picSignerId'] as String?,
      signature: json['signature'] as String?,
      compositeImage: (json['compositeImage'] ?? '') as String,
    );
  }
}

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  List<Unit> units = [];
  List<Staff> staff = [];
  List<Inspection> inspections = [];
  String companyName = 'PT. TAMESTI PALIKSSA SEJAHTERA';

  AppStore(this.prefs);

  Future<void> load() async {
    final unitData = prefs.getString('units');
    final staffData = prefs.getString('staff');
    final inspectionData = prefs.getString('inspections');

    if (unitData != null) {
      units = (jsonDecode(unitData) as List<dynamic>)
          .map((item) => Unit.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (staffData != null) {
      staff = (jsonDecode(staffData) as List<dynamic>)
          .map((item) => Staff.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (inspectionData != null) {
      inspections = (jsonDecode(inspectionData) as List<dynamic>)
          .map((item) => Inspection.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    companyName = prefs.getString('companyName') ?? companyName;
  }

  Unit? findUnit(String id) {
    for (final item in units) {
      if (item.id == id) return item;
    }
    return null;
  }

  Staff? findStaff(String? id) {
    if (id == null) return null;
    for (final item in staff) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> saveAll() async {
    await prefs.setString(
      'units',
      jsonEncode(units.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'staff',
      jsonEncode(staff.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'inspections',
      jsonEncode(inspections.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('companyName', companyName);
    notifyListeners();
  }

  Future<void> saveUnit(Unit value) async {
    units.removeWhere((item) => item.id == value.id);
    units.add(value);
    await saveAll();
  }

  Future<void> deleteUnit(String id) async {
    units.removeWhere((item) => item.id == id);
    await saveAll();
  }

  Future<void> saveStaff(Staff value) async {
    staff.removeWhere((item) => item.id == value.id);
    staff.add(value);
    await saveAll();
  }

  Future<void> deleteStaff(String id) async {
    staff.removeWhere((item) => item.id == id);
    await saveAll();
  }

  Future<void> saveInspection(Inspection value) async {
    inspections.removeWhere((item) => item.id == value.id);
    inspections.insert(0, value);
    await saveAll();
  }

  Future<void> deleteInspection(String id) async {
    inspections.removeWhere((item) => item.id == id);
    await saveAll();
  }

  Future<void> saveCompany(String value) async {
    if (value.trim().isNotEmpty) companyName = value.trim();
    await saveAll();
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = <_MenuItem>[
      _MenuItem('Inspeksi Bulanan', Icons.fact_check, true, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InspectionListPage()),
        );
      }),
      _MenuItem(
        'Monitoring Kesehatan Bulanan',
        Icons.health_and_safety,
        false,
        null,
      ),
      _MenuItem('Evidence SLA Bulanan', Icons.photo_library, false, null),
      _MenuItem('Evaluasi Bulanan', Icons.assessment, false, null),
      _MenuItem('Pengaturan Master', Icons.settings, true, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MasterPage()),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspeksi & Monitoring'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beranda',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Pilih menu untuk mulai bekerja.'),
                const SizedBox(height: 28),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 330,
                          mainAxisExtent: 150,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                        ),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final menu = menus[index];
                      return Card(
                        elevation: menu.enabled ? 2 : 0,
                        color: menu.enabled
                            ? Colors.white
                            : Colors.grey.shade200,
                        child: InkWell(
                          onTap: menu.enabled ? menu.action : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(
                                  menu.icon,
                                  size: 40,
                                  color: menu.enabled ? blue : Colors.grey,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    menu.title,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: menu.enabled ? navy : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback? action;
  _MenuItem(this.title, this.icon, this.enabled, this.action);
}

class MasterPage extends StatelessWidget {
  const MasterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Master'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          MasterTile('Master Unit', Icons.business, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UnitPage()),
            );
          }),
          MasterTile('Master Staff / PIC', Icons.people, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StaffPage()),
            );
          }),
          MasterTile('Pengaturan Umum', Icons.tune, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          }),
        ],
      ),
    );
  }
}

class MasterTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const MasterTile(this.title, this.icon, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: blue),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class UnitPage extends StatelessWidget {
  const UnitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Unit'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editUnit(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: store.units.isEmpty
          ? const EmptyState('Belum ada unit.')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: store.units.length,
              itemBuilder: (context, index) {
                final unit = store.units[index];
                return Card(
                  child: ListTile(
                    title: Text(unit.name),
                    subtitle: Text(
                      unit.code.isEmpty ? 'Tanpa kode' : 'Kode: ${unit.code}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () => editUnit(context, value: unit),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => deleteConfirm(
                            context,
                            'unit ini',
                            () => store.deleteUnit(unit.id),
                          ),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> editUnit(BuildContext context, {Unit? value}) async {
  final name = TextEditingController(text: value?.name ?? '');
  final code = TextEditingController(text: value?.code ?? '');
  final result = await showDialog<Unit>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(value == null ? 'Tambah Unit' : 'Edit Unit'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama unit'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Kode unit'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              dialogContext,
              Unit(
                id:
                    value?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                code: code.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  name.dispose();
  code.dispose();
  if (result != null && context.mounted) {
    await StoreScope.of(context).saveUnit(result);
  }
}

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Staff / PIC'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editStaff(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: store.staff.isEmpty
          ? const EmptyState('Belum ada staff / PIC.')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: store.staff.length,
              itemBuilder: (context, index) {
                final person = store.staff[index];
                return Card(
                  child: ListTile(
                    title: Text(person.name),
                    subtitle: Text(
                      person.position.isEmpty
                          ? 'Jabatan belum diisi'
                          : person.position,
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () => editStaff(context, value: person),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => deleteConfirm(
                            context,
                            'staff ini',
                            () => store.deleteStaff(person.id),
                          ),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> editStaff(BuildContext context, {Staff? value}) async {
  final name = TextEditingController(text: value?.name ?? '');
  final position = TextEditingController(text: value?.position ?? '');
  final result = await showDialog<Staff>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(value == null ? 'Tambah Staff / PIC' : 'Edit Staff / PIC'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama staff / PIC'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: position,
              decoration: const InputDecoration(labelText: 'Jabatan'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              dialogContext,
              Staff(
                id:
                    value?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                position: position.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  name.dispose();
  position.dispose();
  if (result != null && context.mounted) {
    await StoreScope.of(context).saveStaff(result);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController company;

  @override
  void initState() {
    super.initState();
    company = TextEditingController(text: StoreScope.of(context).companyName);
  }

  @override
  void dispose() {
    company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Umum'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama perusahaan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(controller: company),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await store.saveCompany(company.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengaturan tersimpan')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InspectionListPage extends StatefulWidget {
  const InspectionListPage({super.key});
  @override
  State<InspectionListPage> createState() => _InspectionListPageState();
}

class _InspectionListPageState extends State<InspectionListPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lower = query.toLowerCase();
    final list = store.inspections.where((item) {
      final unit = store.findUnit(item.unitId)?.name.toLowerCase() ?? '';
      return unit.contains(lower) || dates.format(item.date).contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspeksi Bulanan'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (store.units.isEmpty) {
            showInfo(
              context,
              'Tambah unit terlebih dahulu di Pengaturan Master.',
            );
            return;
          }
          final inspection = Inspection(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            date: DateTime.now(),
            unitId: store.units.first.id,
            findings: [Finding()],
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InspectionFormPage(data: inspection),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Cari tanggal atau unit',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState('Belum ada data inspeksi.')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            store.findUnit(item.unitId)?.name ?? 'Unit dihapus',
                          ),
                          subtitle: Text(
                            '${dates.format(item.date)} • ${item.findings.length} temuan',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'PDF',
                                onPressed: () => openPdf(context, item),
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InspectionFormPage(data: item),
                                  ),
                                ),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: () => deleteConfirm(
                                  context,
                                  'inspeksi ini',
                                  () => store.deleteInspection(item.id),
                                ),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class InspectionFormPage extends StatefulWidget {
  final Inspection data;
  const InspectionFormPage({super.key, required this.data});
  @override
  State<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends State<InspectionFormPage> {
  late Inspection data;
  late TextEditingController notes;
  String? selectedSignerId;

  @override
  void initState() {
    super.initState();
    data = widget.data;
    notes = TextEditingController(text: data.notes);
    selectedSignerId = data.picSignerId;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: data.date,
    );
    if (result != null) setState(() => data.date = result);
  }

  Future<void> chooseSignature() async {
    final result = await pickImage();
    if (result != null) {
      setState(() {
        data.signature = base64Encode(result);
        if (selectedSignerId != null) data.picSignerId = selectedSignerId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspeksi Bulanan - Halaman 1'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Data Inspeksi'),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: chooseDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hari / Tanggal',
                          ),
                          child: Text(dates.format(data.date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: data.unitId.isEmpty ? null : data.unitId,
                        decoration: const InputDecoration(
                          labelText: 'Inspeksi BUJP ke Unit',
                        ),
                        items: store.units
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit.id,
                                child: Text(
                                  unit.code.isEmpty
                                      ? unit.name
                                      : '${unit.name} (${unit.code})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => data.unitId = value ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionTitle('Temuan (maksimal 5)'),
                    OutlinedButton.icon(
                      onPressed: data.findings.length >= 5
                          ? null
                          : () => setState(() => data.findings.add(Finding())),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah baris'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...data.findings.asMap().entries.map(
                  (entry) => FindingEditor(
                    index: entry.key,
                    finding: entry.value,
                    staff: store.staff,
                    onChanged: () => setState(() {}),
                    onRemove: data.findings.length > 1
                        ? () =>
                              setState(() => data.findings.removeAt(entry.key))
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notes,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Temuan',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedSignerId,
                        decoration: const InputDecoration(
                          labelText: 'Nama TTD (PIC)',
                        ),
                        items: store.staff
                            .map(
                              (person) => DropdownMenuItem(
                                value: person.id,
                                child: Text(
                                  '${person.name} - ${person.position.isEmpty ? '-' : person.position}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedSignerId = value;
                          data.picSignerId = value;
                        }),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TTD digital',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: chooseSignature,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload TTD'),
                              ),
                              if (data.signature != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: Image.memory(
                                    base64Decode(data.signature!),
                                    width: 110,
                                    height: 60,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (data.unitId.isEmpty) {
                        showInfo(context, 'Pilih unit terlebih dahulu.');
                        return;
                      }
                      data.notes = notes.text;
                      data.picSignerId = selectedSignerId;
                      await store.saveInspection(data);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentationPage(data: data),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Simpan & Lanjut ke Dokumentasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FindingEditor extends StatelessWidget {
  final int index;
  final Finding finding;
  final List<Staff> staff;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const FindingEditor({
    super.key,
    required this.index,
    required this.finding,
    required this.staff,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '${index + 1}.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: finding.text,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Temuan'),
                onChanged: (value) {
                  finding.text = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: staff.any((person) => person.id == finding.picId)
                    ? finding.picId
                    : null,
                decoration: const InputDecoration(labelText: 'PIC'),
                items: staff
                    .map(
                      (person) => DropdownMenuItem(
                        value: person.id,
                        child: Text(
                          person.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  finding.picId = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final result = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: finding.target ?? DateTime.now(),
                  );
                  if (result != null) {
                    finding.target = result;
                    onChanged();
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Target Waktu Penyelesaian',
                  ),
                  child: Text(
                    finding.target == null
                        ? 'Pilih tanggal'
                        : dates.format(finding.target!),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentationPage extends StatefulWidget {
  final Inspection data;
  const DocumentationPage({super.key, required this.data});
  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  late Inspection data;
  List<String> images = [];

  bool _isDragging = false;

  Future<void> _addImageBytes(Uint8List bytes) async {
    if (images.length >= 9) return;
    setState(() {
      images.add(base64Encode(bytes));
    });
  }

  Future<void> _addFiles(List<XFile> files) async {
    final available = 9 - images.length;
    final selected = files.take(available);
    for (final file in selected) {
      final bytes = await file.readAsBytes();
      await _addImageBytes(bytes);
    }
  }

  Future<void> _pasteImage() async {
    final bytes = await Pasteboard.image;
    if (bytes != null) await _addImageBytes(bytes);
  }

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final unit = store.findUnit(data.unitId)?.name ?? '-';
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteImage,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _pasteImage,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Dokumentasi - Halaman 2'),
            backgroundColor: navy,
            foregroundColor: Colors.white,
          ),
          body: DropTarget(
            onDragEntered: (detail) => setState(() => _isDragging = true),
            onDragExited: (detail) => setState(() => _isDragging = false),
            onDragDone: (detail) {
              setState(() => _isDragging = false);
              _addFiles(detail.files);
            },
            child: Container(
              color: _isDragging
                  ? navy.withValues(alpha: 0.08)
                  : Colors.transparent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Dokumentasi Inspeksi'),
                        Text('Hari / Tanggal: ${dates.format(data.date)}'),
                        Text('Inspeksi BUJP ke Unit: $unit'),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gambar ${images.length}/9 (Drag-drop / Ctrl+V)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: images.length >= 9
                                      ? null
                                      : _pasteImage,
                                  icon: const Icon(Icons.content_paste),
                                  label: const Text('Paste'),
                                ),
                                FilledButton.icon(
                                  onPressed: images.length >= 9
                                      ? null
                                      : () async {
                                          final result = await FilePicker
                                              .platform
                                              .pickFiles(
                                                type: FileType.image,
                                                allowMultiple: true,
                                                withData: true,
                                              );
                                          if (result == null) return;
                                          final files = result.files
                                              .where((f) => f.bytes != null)
                                              .map(
                                                (f) => XFile.fromData(f.bytes!),
                                              )
                                              .toList();
                                          await _addFiles(files);
                                        },
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Upload Gambar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (images.isEmpty)
                          const EmptyState(
                            'Drop gambar di sini atau paste (Ctrl+V)',
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 260,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.25,
                                ),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.memory(
                                      base64Decode(images[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => setState(
                                          () => images.removeAt(index),
                                        ),
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  data.compositeImage =
                                      await combineImagesToGrid(images);
                                  if (context.mounted) openPdf(context, data);
                                },
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Preview PDF'),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  data.compositeImage =
                                      await combineImagesToGrid(images);
                                  await store.saveInspection(data);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Inspeksi tersimpan'),
                                      ),
                                    );
                                    Navigator.popUntil(
                                      context,
                                      (route) => route.isFirst,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('Simpan Inspeksi'),
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
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    ),
  );
}

Future<Uint8List?> pickImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  return result?.files.single.bytes;
}

Future<void> deleteConfirm(
  BuildContext context,
  String label,
  Future<void> Function() action,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Konfirmasi'),
      content: Text('Hapus $label?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (result == true) await action();
}

void showInfo(BuildContext context, String text) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}

Future<String> combineImagesToGrid(List<String> base64Images) async {
  if (base64Images.isEmpty) return '';

  final decodedImages = base64Images
      .map((b64) {
        try {
          final bytes = base64Decode(b64);
          return img.decodeImage(bytes);
        } catch (_) {
          return null;
        }
      })
      .whereType<img.Image>()
      .toList();

  if (decodedImages.isEmpty) return '';

  final totalImages = decodedImages.length > 9 ? 9 : decodedImages.length;

  // Fit image inside box. Preserve aspect ratio; never stretch image.
  img.Image fitInside(img.Image source, int boxWidth, int boxHeight) {
    final sourceAspect = source.width / source.height;
    var targetWidth = boxWidth;
    var targetHeight = (boxWidth / sourceAspect).round();

    if (targetHeight > boxHeight) {
      targetHeight = boxHeight;
      targetWidth = (boxHeight * sourceAspect).round();
    }

    targetWidth = targetWidth.clamp(1, boxWidth);
    targetHeight = targetHeight.clamp(1, boxHeight);

    if (targetWidth == source.width && targetHeight == source.height) {
      return source;
    }

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  // One photo: keep full photo ratio and center it on canvas.
  if (totalImages == 1) {
    const canvasWidth = 1220;
    const horizontalMargin = 10;
    final resized = fitInside(
      decodedImages[0],
      canvasWidth - horizontalMargin * 2,
      1400,
    );
    final canvas = img.Image(
      width: canvasWidth,
      height: resized.height + horizontalMargin * 2,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      canvas,
      resized,
      dstX: (canvasWidth - resized.width) ~/ 2,
      dstY: horizontalMargin,
    );
    return base64Encode(img.encodePng(canvas));
  }

  // Use equal cells. Odd final photo stays same size as other photos.
  final bool isThreeCol = totalImages >= 7;
  final int cols = isThreeCol ? 3 : 2;
  final int gridGap = isThreeCol ? 8 : 10;
  final int cellWidth = isThreeCol ? 400 : 500;
  final int cellHeight = isThreeCol ? 300 : 350;
  final int rows = (totalImages + cols - 1) ~/ cols;
  final int canvasWidth = cellWidth * cols + gridGap * (cols + 1);
  final int canvasHeight = cellHeight * rows + gridGap * (rows + 1);

  final canvas = img.Image(width: canvasWidth, height: canvasHeight);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  for (int i = 0; i < totalImages; i++) {
    final int row = i ~/ cols;
    final int column = i % cols;
    final int y = gridGap + row * (cellHeight + gridGap);
    final resized = fitInside(decodedImages[i], cellWidth, cellHeight);

    final bool isLoneLast = totalImages % cols == 1 && i == totalImages - 1;
    final int x = isLoneLast
        ? (canvasWidth - resized.width) ~/ 2
        : gridGap +
              column * (cellWidth + gridGap) +
              (cellWidth - resized.width) ~/ 2;
    final int centeredY = y + (cellHeight - resized.height) ~/ 2;

    img.compositeImage(canvas, resized, dstX: x, dstY: centeredY);
  }

  return base64Encode(img.encodePng(canvas));
}

Future<void> openPdf(BuildContext context, Inspection inspection) async {
  final bytes = await buildPdf(inspection, StoreScope.of(context));
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PdfPage(bytes: bytes)),
  );
}

pw.Widget _pdfInfoRow(String number, String label, String value) {
  return pw.Row(
    children: [
      pw.SizedBox(
        width: 15,
        child: pw.Text(number, style: const pw.TextStyle(fontSize: 10)),
      ),
      pw.SizedBox(
        width: 140,
        child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ),
      pw.SizedBox(
        width: 15,
        child: pw.Text(':', style: const pw.TextStyle(fontSize: 10)),
      ),
      pw.Expanded(
        child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ),
    ],
  );
}

Future<Uint8List> buildPdf(Inspection data, AppStore store) async {
  final document = pw.Document();
  final unit = store.findUnit(data.unitId)?.name ?? '-';
  final normal = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final signerStaff = store.findStaff(data.picSignerId);
  final signerName = signerStaff?.name ?? '';
  final signerPosition = signerStaff?.position ?? '';
  const note =
      '1. Kolom Temuan :\n'
      '   Temuan yang didapatkan oleh Manajemen BUJP\n'
      '2. Kolom PIC :\n'
      '   Penanggung jawab yang mendapatkan disposisi dari Manajemen BUJP\n'
      '3. Kolom Target Waktu Penyelesaian :\n'
      '   Tanggal temuan selesai ditindaklanjuti\n'
      '4. Catatan temuan :\n'
      '   Di isi dengan keterangan temuan';

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 35, 42, 30),
      theme: pw.ThemeData.withFont(base: normal, bold: bold),
      build: (context) {
        final rows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEFEFEF),
            ),
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: ['NO', 'Temuan', 'PIC', 'Target Waktu\nPenyelesaian']
                .map(
                  (title) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: pw.Text(
                        title,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: bold, fontSize: 9),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ];

        for (var index = 0; index < data.findings.length; index++) {
          final finding = data.findings[index];
          final picStaff = store.findStaff(finding.picId);
          final picText = picStaff == null
              ? ''
              : (picStaff.position.isNotEmpty
                    ? picStaff.position
                    : picStaff.name);
          rows.add(
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      '${index + 1}.',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    finding.text,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      picText,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      finding.target == null
                          ? ''
                          : dates.format(finding.target!),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'INSPEKSI KEAMANAN\nBADAN USAHA JASA PENGAMANAN',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 15),
              ),
            ),
            pw.SizedBox(height: 18),
            _pdfInfoRow('1.', 'Hari/Tanggal', fullDates.format(data.date)),
            _pdfInfoRow('2.', 'Inspeksi BUJP ke Unit', unit),
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              child: pw.Table(
                border: pw.TableBorder.all(width: 1.0),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: rows,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Catatan Temuan :',
              style: pw.TextStyle(font: bold, fontSize: 10),
            ),
            pw.Container(
              width: double.infinity,
              height: 112,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.0)),
              child: pw.Text(
                data.notes,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      note,
                      style: const pw.TextStyle(fontSize: 7.2, lineSpacing: 2),
                    ),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      children: [
                        pw.Text('Mengetahui,'),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          store.companyName,
                          style: pw.TextStyle(font: bold, fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 50),
                        if (data.signature != null)
                          pw.Image(
                            pw.MemoryImage(base64Decode(data.signature!)),
                            height: 80,
                            fit: pw.BoxFit.contain,
                          ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          signerName.isEmpty ? '________________' : signerName,
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 35, 42, 35),
      theme: pw.ThemeData.withFont(base: normal, bold: bold),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'DOKUMENTASI INSPEKSI KEAMANAN\nBADAN USAHA JASA PENGAMANAN',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 15),
              ),
            ),
            pw.SizedBox(height: 14),
            _pdfInfoRow('1.', 'Hari/Tanggal', fullDates.format(data.date)),
            pw.SizedBox(height: 4),
            _pdfInfoRow('2.', 'Inspeksi BUJP ke Unit', unit),
            pw.SizedBox(height: 14),
            if (data.compositeImage.isEmpty)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text('Tidak ada gambar dokumentasi.'),
                ),
              )
            else
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Image(
                  pw.MemoryImage(base64Decode(data.compositeImage)),
                  width: PdfPageFormat.a4.width - 42 * 2 - 8,
                  fit: pw.BoxFit.contain,
                ),
              ),
          ],
        );
      },
    ),
  );
  return document.save();
}

class PdfPage extends StatelessWidget {
  final Uint8List bytes;
  const PdfPage({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview PDF'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
