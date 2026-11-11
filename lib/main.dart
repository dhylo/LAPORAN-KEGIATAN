import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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

const _pdfSigSlotW = 225.0;
const _pdfSigSlotH = 102.0;
const _pdfSigImageW = 150.0;
const _pdfSigImageH = 75.0;
const _sigMinScale = 0.5;
const _sigMaxScale = 1.15;
// Fixed name position inside signature slot. Signature moves above it.
const _sigNameTop = 90.0;
// TTD boleh turun menimpa nama sejauh 18 pt (dasar TTD 90 → 108).
const _sigOverlapPt = 18.0;
// Slot mulai 33 pt di bawah baris "Mengetahui,". TTD boleh naik sampai sana.
const _sigUpPt = 33.0;
const _sigFooterH = 140.0;
const _sigLayoutVersion = 8;

const _pdfPageW = 595.28;
const _pdfPageH = 841.89; // A4 width/height in pt
const _pdfPagePadLeft = 42.0;
const _pdfPagePadTop = 35.0;
const _pdfPagePadRight = 42.0;
const _pdfContentW = _pdfPageW - _pdfPagePadLeft - _pdfPagePadRight;

double _pdfRowHeight(int findingCount) {
  return findingCount <= 3
      ? 108.0
      : (324.0 / findingCount).clamp(48.0, 108.0);
}

double _signatureFooterTop(int findingCount) {
  // Fixed heights of page-1 content above the footer block.
  return _pdfPagePadTop +
      36.0 +
      18.0 +
      24.0 +
      14.0 +
      25.0 +
      findingCount * _pdfRowHeight(findingCount) +
      12.0 +
      12.0 +
      112.0 +
      24.0;
}

/// Signature slot position in PDF points. Same layout used by editor marker.
double _signatureSlotTop(int findingCount) {
  return _signatureFooterTop(findingCount) + 33.0;
}

double _signatureSlotLeft() {
  final rightColLeft = _pdfPagePadLeft + _pdfContentW * 5 / 9;
  final rightColW = _pdfContentW * 4 / 9;
  return rightColLeft + (rightColW - _pdfSigSlotW) / 2;
}

const _signatureRasterDpi = 110.0;

List<double> _signatureImageSize(String? encoded, double scale) {
  const fallbackRatio = _pdfSigImageW / _pdfSigImageH;
  var ratio = fallbackRatio;
  if (encoded != null && encoded.isNotEmpty) {
    try {
      final decoded = img.decodeImage(base64Decode(encoded));
      if (decoded != null && decoded.height > 0) {
        ratio = decoded.width / decoded.height;
      }
    } catch (_) {
      ratio = fallbackRatio;
    }
  }
  return _signatureImageSizeFromAspect(ratio, scale);
}

List<double> _signatureImageSizeFromAspect(double ratio, double scale) {
  const fallbackRatio = _pdfSigImageW / _pdfSigImageH;
  final safeRatio = ratio > 0 ? ratio : fallbackRatio;
  final baseW = safeRatio >= fallbackRatio ? _pdfSigImageW : _pdfSigImageH * safeRatio;
  final baseH = baseW / safeRatio;
  return [baseW * scale, baseH * scale];
}

double _defaultSignatureY(String? encoded, double scale) {
  final sigH = _signatureImageSize(encoded, scale)[1];
  final minTop = -_sigUpPt;
  final maxTop = _sigNameTop + _sigOverlapPt - sigH;
  final moveH = maxTop - minTop;
  if (moveH <= 0) return 0.0;
  return ((_sigNameTop - sigH - minTop) / moveH).clamp(0.0, 1.0).toDouble();
}

final dates = DateFormat('dd/MM/yyyy');
final fullDates = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  runApp(App(store: store));
}

class _MacScrollBehavior extends MaterialScrollBehavior {
  const _MacScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
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
        scrollBehavior: const _MacScrollBehavior(),
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Segoe UI',
          colorScheme: ColorScheme.fromSeed(seedColor: navy),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          splashFactory: NoSplash.splashFactory,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            },
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
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
  double? sigX;
  double? sigY;
  double? sigW;
  bool sigAbsolute;
  bool signatureCropped;
  bool sigPosV2;
  int sigLayoutVersion;

  Inspection({
    required this.id,
    required this.date,
    required this.unitId,
    required this.findings,
    this.notes = '',
    this.picSignerId,
    this.signature,
    this.compositeImage = '',
    this.sigX,
    this.sigY,
    this.sigW,
    this.sigAbsolute = false,
    this.signatureCropped = false,
    this.sigPosV2 = false,
    this.sigLayoutVersion = 0,
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
    'sigX': sigX,
    'sigY': sigY,
    'sigW': sigW,
    'sigAbsolute': sigAbsolute,
    'signatureCropped': signatureCropped,
    'sigPosV2': sigPosV2,
    'sigLayoutVersion': sigLayoutVersion,
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
      sigX: json['sigX'] as double?,
      sigY: json['sigY'] as double?,
      sigW: json['sigW'] as double?,
      sigAbsolute: json['sigAbsolute'] as bool? ?? false,
      signatureCropped: json['signatureCropped'] as bool? ?? false,
      sigPosV2: json['sigPosV2'] as bool? ?? false,
      sigLayoutVersion: json['sigLayoutVersion'] as int? ?? 0,
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
        title: const Text('Inspeksi, Monitoring & Laporang'),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanda Tangan Digital',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Upload & atur posisi tanda tangan dilakukan di halaman Preview PDF.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
  final bytes = result?.files.single.bytes;
  if (bytes == null) return null;

  // Auto-crop white margins
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      // If not near-white (assuming 240+ is white-ish)
      if (pixel.r < 245 || pixel.g < 245 || pixel.b < 245) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX == -1) return bytes; // All white?

  // Add 2% padding
  final padW = (image.width * 0.02).toInt();
  final padH = (image.height * 0.02).toInt();

  final cropX = (minX - padW).clamp(0, image.width - 1);
  final cropY = (minY - padH).clamp(0, image.height - 1);
  final cropW = (maxX - minX + 1 + padW * 2).clamp(1, image.width - cropX);
  final cropH = (maxY - minY + 1 + padH * 2).clamp(1, image.height - cropY);

  final cropped = img.copyCrop(
    image,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );
  return Uint8List.fromList(img.encodePng(cropped));
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
  final store = StoreScope.of(context);
  final bytes = await buildPdf(inspection, store);
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PdfPage(bytes: bytes, data: inspection, store: store),
    ),
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

pw.Widget _noteItem(String title, String desc) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 6)),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12),
          child: pw.Text(desc, style: const pw.TextStyle(fontSize: 6)),
        ),
      ],
    ),
  );
}

Future<Uint8List> buildPdf(
  Inspection data,
  AppStore store, {
  bool includeSignature = true,
}) async {
  final document = pw.Document();
  final unit = store.findUnit(data.unitId)?.name ?? '-';
  final normal = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final signerStaff = store.findStaff(data.picSignerId);
  final signerName = signerStaff?.name ?? '';

  final n = data.findings.length;
  final rowH = _pdfRowHeight(n);
  final sigScale = (data.sigW ?? 1.0).clamp(_sigMinScale, _sigMaxScale).toDouble();
  final sigSize = _signatureImageSize(data.signature, sigScale);
  final sigImageW = sigSize[0];
  final sigImageH = sigSize[1];
  final sigX = (data.sigLayoutVersion >= _sigLayoutVersion ? (data.sigX ?? 0.5) : 0.5)
      .clamp(0.0, 1.0)
      .toDouble();
  final defaultY = _defaultSignatureY(data.signature, sigScale);
  final sigY = (data.sigLayoutVersion >= _sigLayoutVersion ? (data.sigY ?? defaultY) : defaultY)
      .clamp(0.0, 1.0)
      .toDouble();
  final sigSlotLeft = _signatureSlotLeft();
  final sigSlotTop = _signatureSlotTop(n);
  final sigMinTop = -_sigUpPt;
  final sigMaxTop = _sigNameTop + _sigOverlapPt - sigImageH;
  final sigMoveH = sigMaxTop - sigMinTop;
  final sigLeft = sigSlotLeft + sigX * (_pdfSigSlotW - sigImageW);
  final sigTop = sigSlotTop + sigMinTop + sigY * sigMoveH;

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
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
                  (title) => pw.SizedBox(
                    height: 25,
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
                pw.SizedBox(
                  height: rowH,
                  child: pw.Center(
                    child: pw.Text(
                      '${index + 1}.',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                pw.SizedBox(
                  height: rowH,
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        finding.text,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(
                  height: rowH,
                  child: pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Text(
                        picText,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(
                  height: rowH,
                  child: pw.Center(
                    child: pw.Text(
                      finding.target == null ? '' : dates.format(finding.target!),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final pageContent = pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(42, 35, 42, 30),
          child: pw.Column(
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
            pw.Table(
              border: pw.TableBorder.all(width: 1.0),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: rows,
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
            pw.SizedBox(
              height: _sigFooterH,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Keterangan :', style: pw.TextStyle(font: bold, fontSize: 6)),
                      pw.SizedBox(height: 4),
                      _noteItem('1. Kolom Temuan :', 'Temuan yang didapatkan oleh Manajemen BUJP'),
                      _noteItem('2. Kolom PIC :', 'Penanggung jawab yang mendapatkan disposisi dari Manajemen BUJP'),
                      _noteItem('3. Kolom Target Waktu Penyelesaian :', 'Tanggal temuan selesai ditindaklanjuti'),
                      _noteItem('4. Catatan temuan :', 'Di isi dengan keterangan temuan'),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    children: [
                      pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        store.companyName,
                        style: pw.TextStyle(font: bold, fontSize: 9),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.SizedBox(
                        width: _pdfSigSlotW,
                        height: _pdfSigSlotH,
                      ),
                      pw.SizedBox(height: 2),
                    ],
                  ),
                ),
                ],
              ),
            ),
            ],
          ),
        );
        return pw.Stack(
          children: [
            pw.Positioned.fill(child: pageContent),
            if (includeSignature && data.signature != null)
              pw.Positioned(
                left: sigLeft,
                top: sigTop,
                child: pw.SizedBox(
                  width: sigImageW,
                  height: sigImageH,
                  child: pw.Image(
                    pw.MemoryImage(base64Decode(data.signature!)),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            if (includeSignature &&
                (signerName.isNotEmpty || data.signature != null))
              pw.Positioned(
                left: sigSlotLeft,
                top: sigSlotTop + _sigNameTop,
                child: pw.SizedBox(
                  width: _pdfSigSlotW,
                  child: pw.Text(
                    signerName.isEmpty ? '________________' : signerName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
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

class PdfPage extends StatefulWidget {
  final Uint8List bytes;
  final Inspection data;
  final AppStore store;
  const PdfPage({super.key, required this.bytes, required this.data, required this.store});

  @override
  State<PdfPage> createState() => _PdfPageState();
}

class _SignatureSlotPainter extends CustomPainter {
  final double slotW;
  final double slotH;

  const _SignatureSlotPainter({required this.slotW, required this.slotH});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, slotW, slotH),
      Paint()..color = blue.withValues(alpha: 0.05),
    );
    final paint = Paint()
      ..color = blue.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    const dash = 8.0;
    const gap = 5.0;

    void drawHorizontal(double y) {
      for (var x = 0.0; x < slotW; x += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0.0, slotW), y), paint);
      }
    }

    void drawVertical(double x) {
      for (var y = 0.0; y < slotH; y += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + dash).clamp(0.0, slotH)), paint);
      }
    }

    drawHorizontal(0);
    drawHorizontal(slotH);
    drawVertical(0);
    drawVertical(slotW);
  }

  @override
  bool shouldRepaint(covariant _SignatureSlotPainter oldDelegate) =>
      oldDelegate.slotW != slotW || oldDelegate.slotH != slotH;
}

class _PdfPageState extends State<PdfPage> {
  int _rev = 0;
  bool _editingSig = false;
  ImageProvider? _page1Image;
  double _sigX = 0;
  double _sigY = 0;
  double _sigW = 1.0;
  late Uint8List _currentBytes;
  late final TransformationController _txCtrl = TransformationController();
  double _lastFittedScale = 0;
  Uint8List? _sigBytes;
  double _sigAspect = 2.0;

  // Reference area size for signature positioning (matches PDF Stack: 150x80)

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.bytes;
    final (sigW, sigX, sigY) = _loadSavedSigPosition();
    _sigW = sigW;
    _sigX = sigX;
    _sigY = sigY;
    _cacheSignature();
  }

  void _initMatrix(double viewW, double viewH) {
    final ratio = _pdfPageW / _pdfPageH;
    final boxW = viewW < viewH * ratio ? viewW : viewH * ratio;
    final fittedScale = boxW / _pdfPageW;
    if (fittedScale == _lastFittedScale) return;
    _lastFittedScale = fittedScale;
    final translateX = (viewW - _pdfPageW * fittedScale) / 2;
    final translateY = (viewH - _pdfPageH * fittedScale) / 2;
    _txCtrl.value = Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(fittedScale, fittedScale, fittedScale, 1);
  }

  Future<void> _pickAndSetSignature() async {
    final result = await pickImage();
    if (result != null) {
      widget.data.signature = base64Encode(result);
      _sigW = 1.0;
      _sigX = 0.5;
      _sigY = _defaultSignatureY(widget.data.signature, _sigW);
      _cacheSignature();
      widget.data.sigX = _sigX;
      widget.data.sigY = _sigY;
      widget.data.sigW = _sigW;
      widget.data.sigPosV2 = true;
      widget.data.sigLayoutVersion = _sigLayoutVersion;
      await widget.store.saveInspection(widget.data);
      // Build PDF tanpa TTD sebagai latar editor.
      final newBytes = await buildPdf(widget.data, widget.store, includeSignature: false);
      if (!mounted) return;
      setState(() {
        _currentBytes = newBytes;
        _rev++;
      });
      await _enterEditMode();
    }
  }

  (double, double, double) _loadSavedSigPosition() {
    final sigW = (widget.data.sigW ?? 1.0).clamp(_sigMinScale, _sigMaxScale).toDouble();
    final useSavedPosition = widget.data.sigAbsolute &&
        widget.data.sigPosV2 &&
        widget.data.sigLayoutVersion >= _sigLayoutVersion;
    final sigX = useSavedPosition ? (widget.data.sigX ?? 0.5) : 0.5;
    final sigY = useSavedPosition ? (widget.data.sigY ?? _defaultSignatureY(widget.data.signature, sigW)) : _defaultSignatureY(widget.data.signature, sigW);
    return (sigW, sigX, sigY);
  }

  Future<void> _enterEditMode() async {
    if (widget.data.signature == null) {
      await _pickAndSetSignature();
      return;
    }
    final (sigW, sigX, sigY) = _loadSavedSigPosition();
    _sigW = sigW;
    _sigX = sigX;
    _sigY = sigY;
    _lastFittedScale = 0;
    _txCtrl.value = Matrix4.identity();
    _page1Image = null;
    _cacheSignature();
    setState(() => _editingSig = true);
    // Build PDF tanpa TTD sebagai latar editor.
    final cleanBytes = await buildPdf(widget.data, widget.store, includeSignature: false);
    setState(() => _currentBytes = cleanBytes);
    await _rasterizePage1();
  }

  void _cacheSignature() {
    if (widget.data.signature == null) {
      _sigBytes = null;
      _sigAspect = 2.0;
      return;
    }
    try {
      final bytes = base64Decode(widget.data.signature!);
      final decoded = img.decodeImage(bytes);
      if (decoded != null && decoded.height > 0) {
        _sigBytes = Uint8List.fromList(bytes);
        _sigAspect = decoded.width / decoded.height;
      } else {
        _sigBytes = null;
        _sigAspect = 2.0;
      }
    } catch (_) {
      _sigBytes = null;
      _sigAspect = 2.0;
    }
  }

  Future<void> _rasterizePage1() async {
    try {
      await for (final page in Printing.raster(
        _currentBytes,
        pages: [0],
        dpi: _signatureRasterDpi,
      )) {
        final png = await page.toPng();
        if (mounted) {
          setState(() {
            _page1Image = MemoryImage(png);
          });
        }
        break;
      }
    } catch (_) {
      if (mounted) {
        showInfo(context, 'Raster PDF tidak didukung di platform ini.');
        final cleanBytes = await buildPdf(widget.data, widget.store);
        setState(() {
          _currentBytes = cleanBytes;
          _editingSig = false;
        });
      }
    }
  }

  Future<void> _resetSig() async {
    _sigW = 1.0;
    _sigX = 0.5;
    _sigY = _defaultSignatureY(widget.data.signature, _sigW);
    _cacheSignature();
    setState(() {});
  }

  Future<void> _saveSig() async {
    widget.data.sigX = _sigX;
    widget.data.sigY = _sigY;
    widget.data.sigW = _sigW;
    widget.data.sigAbsolute = true;
    widget.data.sigPosV2 = true;
    widget.data.sigLayoutVersion = _sigLayoutVersion;
    await widget.store.saveInspection(widget.data);
    final newBytes = await buildPdf(widget.data, widget.store);
    if (!mounted) return;
    setState(() {
      _currentBytes = newBytes;
      _editingSig = false;
      _page1Image = null;
      _sigBytes = null;
      _rev++;
    });
  }

  Future<void> _exitEditMode() async {
    final cleanBytes = await buildPdf(widget.data, widget.store);
    if (!mounted) return;
    setState(() {
      _currentBytes = cleanBytes;
      _editingSig = false;
      _page1Image = null;
      _sigBytes = null;
      _rev++;
    });
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingSig ? 'Atur Posisi TTD' : 'Preview PDF'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [
          if (!_editingSig)
            IconButton(
              tooltip: widget.data.signature == null ? 'Upload TTD' : 'Atur TTD',
              onPressed: _enterEditMode,
              icon: Icon(
                widget.data.signature == null
                    ? Icons.draw
                    : Icons.edit,
              ),
            ),
          if (_editingSig) ...[
            TextButton.icon(
              onPressed: _pickAndSetSignature,
              icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
              label: const Text('Ganti File', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _resetSig,
              child: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _exitEditMode,
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: _saveSig,
              child: const Text('Simpan'),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _editingSig && _page1Image != null
          ? _buildPageSigEditor()
          : _editingSig && _page1Image == null
              ? const Center(child: CircularProgressIndicator())
              : PdfPreview(
                  key: ValueKey(_rev),
                  build: (_) async => _currentBytes,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  actions: [
                    IconButton(
                      tooltip: 'Upload TTD / Stempel',
                      icon: const Icon(Icons.upload_file),
                      onPressed: _pickAndSetSignature,
                    ),
                  ],
                ),
    );
  }

  Widget _buildPageSigEditor() {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewW = constraints.maxWidth;
              final viewH = constraints.maxHeight;
              final ratio = _pdfPageW / _pdfPageH;
              final boxW = viewW < viewH * ratio ? viewW : viewH * ratio;
              final fittedScale = boxW / _pdfPageW;
              if ((_lastFittedScale - fittedScale).abs() > 0.0001) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _initMatrix(viewW, viewH);
                });
              }
              final slotW = _pdfSigSlotW;
              final slotH = _pdfSigSlotH;
              final slotLeft = _signatureSlotLeft();
              final slotTop = _signatureSlotTop(widget.data.findings.length);
              final sigSize = _signatureImageSizeFromAspect(_sigAspect, _sigW);
              final sigPointW = sigSize[0];
              final sigPointH = sigSize[1];
              final sigW = sigPointW;
              final sigH = sigPointH;
              final sigMinTop = -_sigUpPt;
              final sigMaxTop = _sigNameTop + _sigOverlapPt - sigPointH;
              final sigMoveH = sigMaxTop - sigMinTop;
              final sigTop = slotTop + sigMinTop + _sigY * sigMoveH;
              final signerName = widget.store.findStaff(widget.data.picSignerId)?.name ?? '';

              return InteractiveViewer(
                constrained: false,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.1,
                maxScale: 8.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                transformationController: _txCtrl,
                child: SizedBox(
                  width: _pdfPageW,
                  height: _pdfPageH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image(
                          image: _page1Image!,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned(
                        left: slotLeft,
                        top: slotTop,
                        child: CustomPaint(
                          size: Size(slotW.toDouble(), slotH.toDouble()),
                          painter: _SignatureSlotPainter(slotW: slotW, slotH: slotH),
                        ),
                      ),
                      Positioned(
                        left: slotLeft + _sigX * (slotW - sigW),
                        top: sigTop,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            setState(() {
                              final dxInPoints = details.delta.dx;
                              final dyInPoints = details.delta.dy;
                              _sigX += dxInPoints / (slotW - sigW).clamp(1.0, double.infinity);
                              _sigY += dyInPoints / sigMoveH.clamp(1.0, double.infinity);
                              _sigX = _sigX.clamp(0.0, 1.0);
                              _sigY = _sigY.clamp(0.0, 1.0);
                            });
                          },
                          child: SizedBox(
                            width: sigW,
                            height: sigH,
                            child: _sigBytes != null
                                ? Image.memory(
                                    _sigBytes!,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: slotLeft,
                        top: slotTop + _sigNameTop,
                        width: slotW,
                        child: IgnorePointer(
                          child: Text(
                            signerName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: navy,
          child: Row(
            children: [
              const Text('Ukuran TTD:', style: TextStyle(color: Colors.white, fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _sigW,
                  min: _sigMinScale,
                  max: _sigMaxScale,
                  divisions: 12,
                  label: _sigW.toStringAsFixed(1),
                  activeColor: Colors.white,
                  onChanged: (v) => setState(() => _sigW = v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
