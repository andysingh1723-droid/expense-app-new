import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enough_mail/enough_mail.dart' as mail;
import 'package:another_telephony/telephony.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

const rs = '\u20B9';
const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const mint = Color(0xFF3DDBB4);
const salmon = Color(0xFFFF8A7A);
final ValueNotifier<int> authN = ValueNotifier(0);
final ValueNotifier<ThemeMode> themeN = ValueNotifier(ThemeMode.dark);

class Accent {
  final String n;
  final Color dk, lt;
  const Accent(this.n, this.dk, this.lt);
}

const accents = [
  Accent('Mint', Color(0xFF3DDBB4), Color(0xFF0B9E7F)),
  Accent('Blue', Color(0xFF5AA9FF), Color(0xFF1F6FEB)),
  Accent('Purple', Color(0xFFB388FF), Color(0xFF7C4DDB)),
  Accent('Orange', Color(0xFFFFA94D), Color(0xFFE8710A)),
  Accent('Gold', Color(0xFFFFD54F), Color(0xFFB8860B)),
  Accent('Rose', Color(0xFFFF6B81), Color(0xFFD6204A)),
  Accent('Pink', Color(0xFFFF8AD8), Color(0xFFC2257F)),
  Accent('Cyan', Color(0xFF4DD0E1), Color(0xFF00838F)),
  Accent('Lime', Color(0xFFC6F55B), Color(0xFF5E8A00)),
  Accent('Indigo', Color(0xFF8C9EFF), Color(0xFF3949AB)),
  Accent('B&W', Color(0xFFFFFFFF), Color(0xFF111111)),
];
int accentIdx = 0;
double accentHue = 210;
bool amoled = true;
final ValueNotifier<int> styleN = ValueNotifier(0);

Color accDark() => accentIdx >= accents.length ? HSLColor.fromAHSL(1, accentHue, 0.75, 0.66).toColor() : accents[accentIdx].dk;
Color accLight() => accentIdx >= accents.length ? HSLColor.fromAHSL(1, accentHue, 0.80, 0.36).toColor() : accents[accentIdx].lt;
String accentName() => accentIdx >= accents.length ? 'Custom' : accents[accentIdx].n;

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final ac = dark ? accDark() : accLight();
  final base = ColorScheme.fromSeed(seedColor: ac, brightness: b);
  final bg = amoled ? Colors.black : const Color(0xFF0B0F14);
  final scheme = dark
      ? base.copyWith(
          primary: ac,
          onPrimary: ac.computeLuminance() > 0.35 ? const Color(0xFF0A0F0D) : Colors.white,
          primaryContainer: Color.lerp(bg, ac, 0.18)!,
          onPrimaryContainer: ac,
          surface: bg,
          onSurface: const Color(0xFFF2F5F8),
          onSurfaceVariant: amoled ? const Color(0xFF8E8E93) : const Color(0xFF8B97A6),
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: bg,
          surfaceContainerLow: amoled ? const Color(0xFF0A0A0A) : const Color(0xFF10151C),
          surfaceContainer: amoled ? const Color(0xFF111111) : const Color(0xFF141A22),
          surfaceContainerHigh: amoled ? const Color(0xFF171717) : const Color(0xFF181F29),
          surfaceContainerHighest: amoled ? const Color(0xFF1E1E1E) : const Color(0xFF1E2733),
          outline: amoled ? const Color(0xFF2C2C2E) : const Color(0xFF2E3946),
          outlineVariant: amoled ? const Color(0xFF1C1C1E) : const Color(0xFF1F2833),
          error: salmon)
      : base.copyWith(
          primary: ac,
          onPrimary: Colors.white,
          primaryContainer: Color.lerp(Colors.white, ac, 0.16)!,
          onPrimaryContainer: Color.lerp(ac, Colors.black, 0.35)!,
          surfaceTint: Colors.transparent,
          surface: const Color(0xFFF6F8FA),
          surfaceContainer: Colors.white,
          surfaceContainerHigh: const Color(0xFFF1F4F7),
          surfaceContainerHighest: const Color(0xFFE8EDF2),
          outlineVariant: const Color(0xFFE1E7ED));
  return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800)),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.surfaceContainerHighest,
          contentTextStyle: TextStyle(color: scheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final p = await SharedPreferences.getInstance();
    accentIdx = (p.getInt('accent') ?? 0).clamp(0, accents.length);
    accentHue = p.getDouble('hue') ?? 210;
    amoled = p.getBool('amoled') ?? true;
    final th = p.getString('theme') ?? 'dark';
    themeN.value = th == 'light' ? ThemeMode.light : th == 'system' ? ThemeMode.system : ThemeMode.dark;
  } catch (_) {}
  runApp(ValueListenableBuilder<int>(
      valueListenable: styleN,
      builder: (_, __, ___) => ValueListenableBuilder<ThemeMode>(
          valueListenable: themeN,
          builder: (_, m, __) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              themeMode: m,
              home: const AuthGate()))));
}

const expCats = ['Food', 'Grocery', 'Travel', 'Shopping', 'Bills', 'EMI', 'Medical', 'Other'];
const incCats = ['Salary', 'Cashback', 'Refund', 'Other income'];
List<String> catsFor(String k) => k == 'income' ? incCats : k == 'expense' ? expCats : const ['Transfer'];
String sm(double v) => '${v < 0 ? '-' : ''}${money(v.abs())}';

final _catRes = <MapEntry<String, RegExp>>[
  MapEntry('Food', RegExp(r'swiggy|zomato|restaurant|cafe|hotel|dominos|pizza|food|bakery|tea|juice')),
  MapEntry('Grocery', RegExp(r'grocer|kirana|mart|store|general|vegetable|milk|dairy|bigbasket|blinkit|zepto')),
  MapEntry('Travel', RegExp(r'uber|ola|irctc|fuel|petrol|diesel|metro|bus|railway|travel|redbus|rapido')),
  MapEntry('Shopping', RegExp(r'amazon|flipkart|myntra|meesho|ajio|shop|fashion|mall')),
  MapEntry('Bills', RegExp(r'jio|airtel|vodafone|electric|bill|recharge|broadband|gas|water|dth|insurance')),
  MapEntry('EMI', RegExp(r'finance|loan|emi|slice|bajaj|credit|kreditbee|navi')),
  MapEntry('Medical', RegExp(r'pharma|hospital|medical|clinic|doctor|medic|lab|health')),
];

String guessCat(String p, bool debit) {
  final l = p.toLowerCase();
  if (!debit) {
    return l.contains('salary') ? 'Salary' : l.contains('refund') ? 'Refund' : l.contains('cashback') ? 'Cashback' : 'Other income';
  }
  for (final e in _catRes) {
    if (e.value.hasMatch(l)) return e.key;
  }
  return 'Other';
}

class Tx {
  final String id, acc, bank, method, party, ref;
  final DateTime d;
  final double amt;
  final bool debit, manual;
  String kind, cat, src;
  double? bal;
  Tx(this.id, this.d, this.amt, this.debit, this.acc, this.bank, this.method, this.party, this.ref,
      {this.manual = false, this.kind = 'expense', this.cat = 'Other', this.bal, this.src = 'sms'});
  Map<String, dynamic> toJson() => {
        'id': id, 'd': d.millisecondsSinceEpoch, 'a': amt, 'db': debit,
        'ac': acc, 'b': bank, 'm': method, 'p': party, 'r': ref, 'k': kind, 'c': cat
      };
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(j['id'], DateTime.fromMillisecondsSinceEpoch(j['d']),
      (j['a'] as num).toDouble(), j['db'], j['ac'], j['b'], j['m'], j['p'], j['r'],
      manual: true, kind: j['k'] ?? (j['db'] == true ? 'expense' : 'income'), cat: j['c'] ?? 'Other');
}

final _skip = RegExp(
    r'otp|declined|failed|unsuccessful|insufficient|will be debited|scheduled|autopay|mandate|pre-?approved|loan offer|payment due|bill due|request',
    caseSensitive: false);
const _banks = {
  'kotak': 'Kotak Bank', 'hdfc': 'HDFC Bank', 'sbi': 'SBI', 'icici': 'ICICI Bank', 'axis': 'Axis Bank',
  'pnb': 'PNB', 'baroda': 'Bank of Baroda', 'canara': 'Canara Bank', 'yes bank': 'Yes Bank',
  'idfc': 'IDFC First', 'union bank': 'Union Bank', 'indusind': 'IndusInd', 'paytm': 'Paytm Bank',
  'federal': 'Federal Bank', 'fedbnk': 'Federal Bank', 'indian bank': 'Indian Bank', 'indbnk': 'Indian Bank',
  'bank of india': 'Bank of India', 'boiind': 'Bank of India', 'central bank': 'Central Bank', 'idbi': 'IDBI Bank',
  'rbl': 'RBL Bank', 'aubank': 'AU Small Finance', 'au small': 'AU Small Finance', 'canbnk': 'Canara Bank',
  'unionb': 'Union Bank', 'ippb': 'India Post Payments Bank', 'india post': 'India Post Payments Bank',
  'airtel payments': 'Airtel Payments Bank'
};

final _amtRe = RegExp(r'(?:rs\.?|inr|\u20B9)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
final _dmRe = RegExp(r'\b(?:debited|spent|paid|sent|withdrawn|purchase|transferred|debit)\b');
final _cmRe = RegExp(r'\b(?:credited|received|deposited|refund|salary)\b');
final _acc1Re = RegExp(r'(?:a/c|acct|account|card)\s*(?:no\.?|number|ending|ending with)?\s*[:\-]?\s*[xX*]*\s*(\d{4})\b',
    caseSensitive: false);
final _acc2Re = RegExp(r'[xX*]{2,}(\d{4})');
final _refRe = RegExp(r'(?:upi\s*ref(?:erence)?|ref(?:erence)?\s*(?:no|number)?|utr|rrn)\s*[:.\-]?\s*(\d{6,})',
    caseSensitive: false);
final _pmDebRe = RegExp(
    r'(?:\bto\b|\bat\b|vpa)\s+([A-Za-z0-9@._\- ]{3,35}?)(?=\s+(?:on|ref|upi|via|dated|avl|bal|utr|if)\b|[.,;(]|$)',
    caseSensitive: false);
final _pmCreRe = RegExp(
    r'(?:\bfrom\b|\bby\b|vpa)\s+([A-Za-z0-9@._\- ]{3,35}?)(?=\s+(?:on|ref|upi|via|dated|avl|bal|utr|if)\b|[.,;(]|$)',
    caseSensitive: false);
final _balRe = RegExp(
    r'(?:avl\.?\s*bal(?:ance)?|available\s*bal(?:ance)?|bal(?:ance)?)\s*(?:is|:)?\s*(?:rs\.?|inr|\u20B9)\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false);
final _badNameRe = RegExp(r'^(?:rs\.?|inr|\u20B9)\s*\d|^(?:your bank|beneficiary)', caseSensitive: false);

Tx? parse(String b, int ms, String sender) {
  if (b.isEmpty || _skip.hasMatch(b)) return null;
  final low = b.toLowerCase();
  final a = _amtRe.firstMatch(b);
  if (a == null) return null;
  final amt = double.tryParse(a.group(1)!.replaceAll(',', ''));
  if (amt == null || amt <= 0) return null;
  final dm = _dmRe.firstMatch(low);
  final cm = _cmRe.firstMatch(low);
  if (dm == null && cm == null) return null;
  final debit = dm != null && (cm == null || dm.start < cm.start);
  final am = _acc1Re.firstMatch(b) ?? _acc2Re.firstMatch(b);
  final acc = am != null ? 'XX${am.group(1)}' : 'Unknown';
  var bank = 'Unknown';
  final hay = '$low ${sender.toLowerCase()}';
  for (final e in _banks.entries) {
    if (hay.contains(e.key)) {
      bank = e.value;
      break;
    }
  }
  final method = low.contains('upi')
      ? 'UPI'
      : low.contains('imps')
          ? 'IMPS'
          : low.contains('neft')
              ? 'NEFT'
              : low.contains('rtgs')
                  ? 'RTGS'
                  : low.contains('atm')
                      ? 'ATM'
                      : low.contains('card')
                          ? 'Card'
                          : 'Other';
  final ref = _refRe.firstMatch(b)?.group(1) ?? '';
  final pm = (debit ? _pmDebRe : _pmCreRe).firstMatch(b);
  final party = (pm?.group(1) ?? '-').trim();
  final id = ref.isNotEmpty ? 'r${ref}_${debit ? 'd' : 'c'}' : '${ms}_${amt}_${debit}_$acc';
  final bm = _balRe.firstMatch(b);
  final p = party.isEmpty ? '-' : party;
  final kind = debit ? (method == 'ATM' ? 'transfer' : 'expense') : 'income';
  return Tx(id, DateTime.fromMillisecondsSinceEpoch(ms), amt, debit, acc, bank, method, p, ref,
      kind: kind,
      cat: kind == 'transfer' ? 'Transfer' : guessCat(p, debit),
      bal: bm == null ? null : double.tryParse(bm.group(1)!.replaceAll(',', '')));
}

// Background isolate me chalega (UI freeze nahi hoga)
List<Tx> parseAll(List<List<Object>> raw) {
  final out = <Tx>[];
  for (final r in raw) {
    final x = parse(r[0] as String, r[1] as int, r[2] as String);
    if (x != null) out.add(x);
  }
  return out;
}

String two(int n) => n.toString().padLeft(2, '0');
String tm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String dt(DateTime d) => '${d.day} ${mon[d.month - 1]} ${d.year}';
String money(double v) {
  final s = v.floor().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  final frac = v - v.floor();
  if (frac > 0.004) b.write('.${(frac * 100).round().toString().padLeft(2, '0')}');
  return '$rs$b';
}

double spent(List<Tx> l) => l.where((t) => t.debit && t.kind != 'transfer').fold<double>(0, (s, t) => s + t.amt);
double got(List<Tx> l) => l.where((t) => !t.debit && t.kind != 'transfer').fold<double>(0, (s, t) => s + t.amt);

const accTypes = ['Bank', 'UPI', 'Wallet', 'Credit card', 'Other'];
const accIcons = <String, IconData>{
  'bank': Icons.account_balance,
  'savings': Icons.savings,
  'upi': Icons.qr_code_2,
  'wallet': Icons.account_balance_wallet,
  'card': Icons.credit_card,
  'phone': Icons.smartphone,
  'cash': Icons.payments,
  'other': Icons.category,
};
String defIcon(String type) =>
    type == 'UPI' ? 'upi' : type == 'Wallet' ? 'wallet' : type == 'Credit card' ? 'card' : type == 'Other' ? 'other' : 'bank';

class _Day {
  final String label;
  final double out, inn;
  const _Day(this.label, this.out, this.inn);
}

IconData catIcon(String c) {
  switch (c) {
    case 'Food':
      return Icons.restaurant;
    case 'Grocery':
      return Icons.local_grocery_store;
    case 'Travel':
      return Icons.directions_bus;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Bills':
      return Icons.receipt_long;
    case 'EMI':
      return Icons.account_balance;
    case 'Medical':
      return Icons.medical_services;
    case 'Salary':
      return Icons.payments;
    case 'Cashback':
      return Icons.redeem;
    case 'Refund':
      return Icons.undo;
    case 'Other income':
      return Icons.savings;
    case 'Transfer':
      return Icons.swap_horiz;
    default:
      return Icons.category;
  }
}

Color catColor(String c) {
  switch (c) {
    case 'Food':
      return Colors.orange;
    case 'Grocery':
      return Colors.green;
    case 'Travel':
      return Colors.blue;
    case 'Shopping':
      return Colors.pink;
    case 'Bills':
      return Colors.amber;
    case 'EMI':
      return Colors.deepPurple;
    case 'Medical':
      return Colors.red;
    case 'Salary':
    case 'Other income':
      return Colors.teal;
    case 'Cashback':
      return Colors.cyan;
    case 'Refund':
      return Colors.lightGreen;
    default:
      return Colors.blueGrey;
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  List<Tx> sms = [], manual = [];
  final seen = <String>{};
  Map<String, String> names = {}, alias = {};
  double budget = 10000;
  String status = 'Loading...', q = '', type = 'all', src = 'all', range = 'all', mode = 'tx';
  int rd = 30;
  String rp = '30', racc = 'all', sortBy = 'new';
  DateTimeRange? rcr;
  double? minA, maxA;
  int tab = 0;
  Set<String> hidden = {};
  Map<String, Map<String, String>> meta = {};
  Map<String, double> cb = {};
  String catF = 'all';
  DateTimeRange? cr;
  int? pieSel;
  bool listening = false;
  SharedPreferences? sp;
  final qc = TextEditingController();

  bool refreshing = false;
  int pausedAt = 0, lockDelay = 0;
  bool ebBusy = false;
  Map<String, String> accLbl = {};
  bool smsBlocked = false, needSms = false, skipSms = false, _loading = false;
  int lastLoadMs = 0;
  Set<String> accHide = {};
  List<Map<String, dynamic>> macc = [];
  Map<String, String> notes = {};
  double cashOpen = 0;
  bool showExtra = false;
  int cycleDay = 1, alertPct = 80;
  Set<String> hsec = {};
  Map<String, String> crules = {};
  Timer? _deb;
  List<Tx>? _allC;
  int _allK = 0;
  List<Tx>? _dupFor;
  int _dupOkLen = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    boot();
  }

  @override
  void dispose() {
    _deb?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> boot() async {
    sp = await SharedPreferences.getInstance();
    budget = sp!.getDouble('budget') ?? 10000;
    names = Map<String, String>.from(jsonDecode(sp!.getString('names') ?? '{}'));
    alias = Map<String, String>.from(jsonDecode(sp!.getString('alias') ?? '{}'));
    accLbl = Map<String, String>.from(jsonDecode(sp!.getString('acclbl') ?? '{}'));
    accHide = (sp!.getStringList('achide') ?? <String>[]).toSet();
    hidden = (sp!.getStringList('hidden') ?? <String>[]).toSet();
    meta = (jsonDecode(sp!.getString('meta') ?? '{}') as Map)
        .map<String, Map<String, String>>((k, v) => MapEntry(k.toString(), Map<String, String>.from(v as Map)));
    cb = (jsonDecode(sp!.getString('cb') ?? '{}') as Map).map<String, double>((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    rec = ld('rec');
    macc = ld('macc');
    lockDelay = sp!.getInt('lockdelay') ?? 0;
    final th = sp!.getString('theme') ?? 'dark';
    themeN.value = th == 'light' ? ThemeMode.light : th == 'system' ? ThemeMode.system : ThemeMode.dark;
    notes = Map<String, String>.from(jsonDecode(sp!.getString('notes') ?? '{}'));
    cashOpen = sp!.getDouble('cashopen') ?? 0;
    loans = ld('loans');
    goals = ld('goals');
    dupOk = (sp!.getStringList('dupok') ?? <String>[]).toSet();
    pin = sp!.getString('pin');
    hideBal = sp!.getBool('hide') ?? false;
    cycleDay = (sp!.getInt('cycday') ?? 1).clamp(1, 28);
    alertPct = (sp!.getInt('alertpct') ?? 80).clamp(50, 95);
    hsec = (sp!.getStringList('hsec') ?? <String>[]).toSet();
    crules = Map<String, String>.from(jsonDecode(sp!.getString('crules') ?? '{}'));
    WidgetsBinding.instance.addPostFrameCallback((_) => showLock());
    final sv = sp!.getInt('start');
    if (sv == null) {
      final n = DateTime.now();
      startD = DateTime(n.year, n.month, n.day);
      sp!.setInt('start', startD.millisecondsSinceEpoch);
    } else {
      startD = DateTime.fromMillisecondsSinceEpoch(sv);
    }
    manual = (jsonDecode(sp!.getString('manual') ?? '[]') as List)
        .map((e) => Tx.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    await load();
    syncEmail();
    autoBackups();
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    lastLoadMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _load(force);
    } finally {
      _loading = false;
    }
  }

  Future<void> _load(bool force) async {
    final t = Telephony.instance;
    final denied = sp?.getBool('smsDenied') ?? false;
    // Pehle deny ho chuka hai to Android ka popup baar baar nahi dikhayenge
    if (denied && !force) {
      if (mounted) {
        setState(() {
          smsBlocked = true;
          needSms = !skipSms;
          status = '';
        });
      }
      return;
    }
    if (await t.requestSmsPermissions != true) {
      sp?.setBool('smsDenied', true);
      if (mounted) {
        setState(() {
          smsBlocked = true;
          needSms = !skipSms;
          status = '';
        });
      }
      return;
    }
    if (denied) sp?.setBool('smsDenied', false);
    final inbox = await t.getInboxSms(
        columns: [SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ADDRESS],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)]);
    final raw = <List<Object>>[
      for (final m in inbox) [m.body ?? '', m.date ?? 0, m.address ?? '']
    ];
    // heavy parsing background me
    final parsed = await compute(parseAll, raw);
    final list = <Tx>[];
    final ids = <String>{};
    for (final x in parsed) {
      if (ids.add(x.id)) {
        applyMeta(x);
        list.add(x);
      }
    }
    seen
      ..clear()
      ..addAll(ids);
    if (!mounted) return;
    setState(() {
      sms = list;
      status = '';
      smsBlocked = false;
      needSms = false;
    });
    if (!listening) {
      listening = true;
      t.listenIncomingSms(onNewMessage: onSms, listenInBackground: false);
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await load();
      await syncEmail();
      if (mounted) snack('Refresh ho gaya');
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void onSms(SmsMessage m) {
    final x = parse(m.body ?? '', m.date ?? DateTime.now().millisecondsSinceEpoch, m.address ?? '');
    if (x != null && seen.add(x.id) && mounted) {
      applyMeta(x);
      mails.removeWhere((e) => e.id == x.id || near(e, x));
      setState(() => sms.insert(0, x));
    }
  }

  void saveManual() => sp?.setString('manual', jsonEncode(manual.map((e) => e.toJson()).toList()));
  void saveNames() {
    sp?.setString('names', jsonEncode(names));
    sp?.setString('alias', jsonEncode(alias));
  }

  void applyMeta(Tx t) {
    final m = meta[t.id];
    if (m != null) {
      t.kind = m['k'] ?? t.kind;
      t.cat = m['c'] ?? t.cat;
      return;
    }
    if (crules.isNotEmpty && t.kind != 'transfer') {
      final p = t.party.toLowerCase();
      for (final e in crules.entries) {
        if (p.contains(e.key) && catsFor(t.kind).contains(e.value)) {
          t.cat = e.value;
          break;
        }
      }
    }
  }

  // ---------- Phase 10: mahine ki start date, sections, rules ----------
  DateTime cycStart(DateTime n) => n.day >= cycleDay ? DateTime(n.year, n.month, cycleDay) : DateTime(n.year, n.month - 1, cycleDay);
  DateTime cycEnd(DateTime n) {
    final s = cycStart(n);
    return DateTime(s.year, s.month + 1, s.day);
  }

  bool inCyc(DateTime d) {
    final n = DateTime.now();
    return !d.isBefore(cycStart(n)) && d.isBefore(cycEnd(n));
  }

  int cycDim() => cycEnd(DateTime.now()).difference(cycStart(DateTime.now())).inDays;
  int cycElapsed() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(cycStart(n)).inDays + 1;
  }

  String cycLabel() {
    final n = DateTime.now();
    if (cycleDay == 1) return '${mon[n.month - 1]} ${n.year}';
    final s = cycStart(n), e = cycEnd(n).subtract(const Duration(days: 1));
    return '${s.day} ${mon[s.month - 1]} - ${e.day} ${mon[e.month - 1]}';
  }

  bool secOn(String k) => !hsec.contains(k);
  static const _secNames = {
    'alerts': 'Budget alerts',
    'acc': 'Accounts card',
    'budget': 'Budget card',
    'bills': 'Bills aur EMI',
    'recent': 'Recent Transactions'
  };

  Map<String, double> balances() {
    final out = <String, double>{};
    final when = <String, DateTime>{};
    for (final t in [...sms, ...mails]) {
      if (t.bal != null && t.acc != 'Unknown' && !hidden.contains(t.id)) {
        final k = t.bank == 'Unknown' ? t.acc : '${t.bank} ${t.acc}';
        final p = when[k];
        if (p == null || t.d.isAfter(p)) {
          when[k] = t.d;
          out[k] = t.bal!;
        }
      }
    }
    var cash = cashOpen;
    for (final t in all) {
      if (t.manual && t.acc == 'Cash') cash += t.debit ? -t.amt : t.amt;
      if (!t.manual && t.method == 'ATM' && t.debit && t.kind == 'transfer') cash += t.amt;
    }
    out['Cash'] = cash;
    return out;
  }

  String keyOf(Tx t) => t.bank == 'Unknown' ? t.acc : '${t.bank} ${t.acc}';
  String mapKey(Tx t) => t.acc == 'Cash' ? 'Cash' : keyOf(t);
  IconData iconFor(Map<String, dynamic> r) => accIcons['${r['icon']}'] ?? Icons.account_balance;

  String accSub(Map<String, dynamic> r) {
    final no = '${r['acc']}'.startsWith('XX') ? 'A/c ${r['acc']}' : '${r['acc']}';
    if (r['m'] == true) return '${r['type']} \u2022 $no';
    if (r['bal'] == null) return 'Balance SMS nahi mila';
    return 'Updated ${dt(r['when'] as DateTime)}';
  }

  List<Map<String, dynamic>> accountRows() {
    final m = <String, Map<String, dynamic>>{};
    Map<String, dynamic> row(Tx t) {
      final k = keyOf(t);
      return m.putIfAbsent(
          k,
          () => {
                'k': k, 'acc': t.acc, 'bank': t.bank, 'bal': null, 'when': null, 'in': 0.0, 'out': 0.0,
                'cr': 0.0, 'dr': 0.0, 'n': 0, 'last': null, 'type': 'Bank', 'icon': 'bank', 'note': ''
              });
    }

    for (final a in macc) {
      final k = '${a['bank']} ${a['acc']}';
      final op = (a['bal'] as num).toDouble();
      m[k] = {
        'k': k, 'acc': a['acc'], 'bank': a['bank'], 'open': op, 'bal': op,
        'when': DateTime.fromMillisecondsSinceEpoch(a['when'] as int),
        'in': 0.0, 'out': 0.0, 'cr': 0.0, 'dr': 0.0, 'n': 0, 'last': null, 'm': true, 'sms': false,
        'type': a['type'] ?? 'Bank', 'icon': a['icon'] ?? defIcon('${a['type'] ?? 'Bank'}'), 'note': a['note'] ?? ''
      };
    }
    for (final t in [...sms, ...mails]) {
      if (t.bal != null && t.acc != 'Unknown' && !hidden.contains(t.id)) {
        final r = row(t);
        if (r['m'] == true) {
          final w = r['smsWhen'] as DateTime?;
          if (w == null || t.d.isAfter(w)) {
            r['smsWhen'] = t.d;
            r['smsBal'] = t.bal;
          }
        } else {
          final w = r['when'] as DateTime?;
          if (w == null || t.d.isAfter(w)) {
            r['when'] = t.d;
            r['bal'] = t.bal;
            r['sms'] = true;
          }
        }
      }
    }
    final n = DateTime.now();
    for (final t in all) {
      if (t.acc == 'Unknown' || t.acc == 'Cash') continue;
      final r = row(t);
      final w = r['when'] as DateTime?;
      final isM = r['m'] == true;
      final signed = t.debit ? -t.amt : t.amt;
      final counts = isM ? (w != null && t.d.isAfter(w)) : true;
      if (counts) {
        if (t.debit) {
          r['dr'] = (r['dr'] as double) + t.amt;
        } else {
          r['cr'] = (r['cr'] as double) + t.amt;
        }
      }
      if (isM) {
        if (counts) r['bal'] = (r['bal'] as double) + signed;
      } else if (t.manual && r['bal'] != null && w != null && t.d.isAfter(w)) {
        r['bal'] = (r['bal'] as double) + signed;
      }
      r['n'] = (r['n'] as int) + 1;
      final l = r['last'] as DateTime?;
      if (l == null || t.d.isAfter(l)) r['last'] = t.d;
      if (t.kind != 'transfer' && inCyc(t.d)) {
        if (t.debit) {
          r['out'] = (r['out'] as double) + t.amt;
        } else {
          r['in'] = (r['in'] as double) + t.amt;
        }
      }
    }
    final list = m.values.toList();
    return [...list.where((r) => r['bal'] != null), ...list.where((r) => r['bal'] == null)];
  }

  String accName(Map<String, dynamic> r) => accLbl[r['k']] ?? (r['k'] as String);
  String mask(double v) => hideBal ? '\u2022\u2022\u2022\u2022' : sm(v);

  bool isMainAcc(Map<String, dynamic> r) => r['bank'] != 'Unknown' || accLbl[r['k']] != null;

  Widget accRow(Map<String, dynamic> r) {
    return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => accountPage(r),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
            child: Row(children: [
              avatar(accCode(r)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(accName(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(accSub(r), style: sub),
              ])),
              const SizedBox(width: 8),
              Text(r['bal'] == null ? '-' : mask(r['bal'] as double), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ])));
  }

  List<Map<String, dynamic>> mainAccs() => accountRows().where((r) => !accHide.contains(r['k']) && isMainAcc(r)).toList();

  double totalBal(List<Map<String, dynamic>> main) {
    var t = balances()['Cash'] ?? 0.0;
    for (final r in main) {
      t += (r['bal'] as double?) ?? 0.0;
    }
    return t;
  }

  Widget accountsCard() {
    final rows = accountRows().where((r) => !accHide.contains(r['k'])).toList();
    final main = rows.where(isMainAcc).toList();
    final extra = rows.where((r) => !isMainAcc(r)).toList();
    final cash = balances()['Cash'] ?? 0.0;
    var total = cash;
    for (final r in main) {
      total += (r['bal'] as double?) ?? 0.0;
    }
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        TextButton(
            onPressed: addAccount,
            child: Text('+ Account jodo', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700))),
      ]),
      if (main.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Abhi koi pehchana hua bank account nahi', style: sub)),
      for (final r in main) accRow(r),
      InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => accountPage(cashRow()),
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
              child: Row(children: [
                avatar('CA'),
                const SizedBox(width: 12),
                const Expanded(child: Text('Cash', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Text(mask(cash), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ]))),
      Container(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
          child: Row(children: [
            const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
            Text(mask(total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
          ])),
      if (extra.isNotEmpty) ...[
        const SizedBox(height: 6),
        InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => showExtra = !showExtra),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Text('Anya / anjaan accounts (${extra.length}) \u2022 total me nahi', style: sub)),
                  Icon(showExtra ? Icons.expand_less : Icons.expand_more, size: 20),
                ]))),
        if (showExtra) for (final r in extra) accRow(r),
      ],
      const SizedBox(height: 4),
      Text('Balance SMS ke "Avl Bal" se aata hai. Account par tap karke details dekho', style: sub),
    ]));
  }

  void saveMacc() {
    sp?.setString('macc', jsonEncode(macc));
    setState(() {});
    rev.value++;
  }

  Future<void> addAccount() => accountForm();

  Future<void> accountForm([Map<String, dynamic>? r]) async {
    final Map<String, dynamic> rr = (r != null && r['m'] == true) ? r : <String, dynamic>{};
    final edit = rr.isNotEmpty;
    final bankNames = _banks.values.toSet().toList()..sort();
    var type = edit ? '${rr['type']}' : 'Bank';
    var icon = edit ? '${rr['icon']}' : 'bank';
    var iconTouched = edit;
    var bank = bankNames.first;
    var since = edit ? (rr['when'] as DateTime) : DateTime.now();
    final other = TextEditingController(), no = TextEditingController();
    final nick = TextEditingController(text: edit ? (accLbl[rr['k']] ?? '') : '');
    final bal = TextEditingController(text: edit ? fs(rr['open'] as double) : '');
    final note = TextEditingController(text: edit ? '${rr['note']}' : '');
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text(edit ? 'Account edit karo' : 'Account jodo'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!edit)
                      DropdownButtonFormField<String>(
                          value: type,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Account type'),
                          items: [for (final b in accTypes) DropdownMenuItem(value: b, child: Text(b))],
                          onChanged: (v) => ss(() {
                                type = v ?? type;
                                if (!iconTouched) icon = defIcon(type);
                              })),
                    if (edit) Text('${rr['bank']} \u2022 ${rr['acc']}', style: sub),
                    TextField(
                        controller: nick,
                        decoration: InputDecoration(labelText: !edit && type != 'Bank' ? 'Account ka naam (zaroori)' : 'Account ka naam (optional)')),
                    if (!edit && type == 'Bank') ...[
                      DropdownButtonFormField<String>(
                          value: bank,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Bank'),
                          items: [for (final b in [...bankNames, 'Other']) DropdownMenuItem(value: b, child: Text(b))],
                          onChanged: (v) => ss(() => bank = v ?? bank)),
                      if (bank == 'Other') TextField(controller: other, decoration: const InputDecoration(labelText: 'Bank ka naam')),
                    ],
                    if (!edit)
                      TextField(
                          controller: no,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          decoration: InputDecoration(
                              labelText: type == 'Bank' ? 'Account ke last 4 digit' : 'Last 4 digit (optional)', counterText: '')),
                    TextField(
                        controller: bal,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Opening balance', prefixText: rs)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: ctx, initialDate: since, firstDate: DateTime(2015), lastDate: DateTime.now());
                          if (d != null) ss(() => since = DateTime(d.year, d.month, d.day));
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text('Opening date: ${dt(since)}')),
                    const SizedBox(height: 8),
                    Wrap(spacing: 4, children: [
                      for (final e in accIcons.entries)
                        InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => ss(() {
                                  icon = e.key;
                                  iconTouched = true;
                                }),
                            child: CircleAvatar(
                                radius: 18,
                                backgroundColor: icon == e.key ? cs.primaryContainer : Colors.transparent,
                                child: Icon(e.value, size: 20)))
                    ]),
                    TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))
                  ],
                )));
    if (ok != true) return;
    final nickT = nick.text.trim();
    final opening = double.tryParse(bal.text.trim()) ?? 0.0;
    if (edit) {
      final i = macc.indexWhere((a) => '${a['bank']} ${a['acc']}' == rr['k']);
      if (i < 0) return;
      macc[i]['bal'] = opening;
      macc[i]['when'] = since.millisecondsSinceEpoch;
      macc[i]['type'] = type;
      macc[i]['icon'] = icon;
      macc[i]['note'] = note.text.trim();
      final k = rr['k'] as String;
      if (nickT.isEmpty) {
        accLbl.remove(k);
      } else {
        accLbl[k] = nickT;
      }
    } else {
      final d = no.text.trim();
      String b, acc;
      if (type == 'Bank') {
        b = bank == 'Other' ? other.text.trim() : bank;
        if (b.isEmpty || !RegExp(r'^\d{4}$').hasMatch(d)) {
          snack('Bank ka naam aur account ke last 4 digit daalo');
          return;
        }
        acc = 'XX$d';
      } else {
        b = nickT;
        if (b.isEmpty) {
          snack('Account ka naam likho');
          return;
        }
        if (d.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(d)) {
          snack('Last 4 digit sahi daalo ya khali chhodo');
          return;
        }
        acc = d.isEmpty ? type : 'XX$d';
      }
      final k = '$b $acc';
      if (macc.any((a) => a['bank'] == b && a['acc'] == acc)) {
        snack('Ye account pehle se jura hua hai');
        return;
      }
      macc.add({
        'bank': b, 'acc': acc, 'bal': opening, 'when': since.millisecondsSinceEpoch,
        'type': type, 'icon': icon, 'note': note.text.trim()
      });
      if (accHide.remove(k)) sp?.setStringList('achide', accHide.toList());
      if (nickT.isNotEmpty) accLbl[k] = nickT;
    }
    sp?.setString('acclbl', jsonEncode(accLbl));
    saveMacc();
    snack(edit ? 'Account update ho gaya' : 'Account jud gaya');
  }

  // "Abhi ka balance" set karne par opening balance is tarah adjust hota hai ki
  // Opening + Credit - Debit = naya balance
  Future<void> macEditBal(Map<String, dynamic> r) async {
    final v = await ask('Balance badlo', [['a', 'Abhi ka balance', 'n']], {'a': fs((r['bal'] as double?) ?? 0.0)});
    final x = double.tryParse(v?['a'] ?? '');
    if (x == null) return;
    final i = macc.indexWhere((a) => '${a['bank']} ${a['acc']}' == r['k']);
    if (i < 0) return;
    final w = DateTime.fromMillisecondsSinceEpoch(macc[i]['when'] as int);
    var net = 0.0;
    for (final t in all) {
      if (keyOf(t) == r['k'] && t.d.isAfter(w)) net += t.debit ? -t.amt : t.amt;
    }
    macc[i]['bal'] = x - net;
    saveMacc();
  }

  void macDelete(Map<String, dynamic> r) {
    final k = r['k'] as String;
    final cnt = all.where((t) => keyOf(t) == k).length;
    macc.removeWhere((a) => '${a['bank']} ${a['acc']}' == k);
    if (cnt > 0) {
      accHide.add(k);
      sp?.setStringList('achide', accHide.toList());
    }
    saveMacc();
    snack(cnt > 0 ? 'Account hata diya ($cnt transactions safe hain)' : 'Account hata diya');
  }

  Future<void> cashOpenEdit() async {
    final v = await ask('Cash opening balance', [['a', 'Opening balance', 'n']], {'a': fs(cashOpen)});
    final x = double.tryParse(v?['a'] ?? '');
    if (x == null) return;
    cashOpen = x;
    sp?.setDouble('cashopen', cashOpen);
    setState(() {});
    rev.value++;
  }

  void openAccManage() => openPage('Accounts manage karo', accManageBody, addAccount);

  Future<bool> macConfirmDelete(Map<String, dynamic> r) async {
    final cnt = all.where((t) => keyOf(t) == r['k']).length;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Account hatao?'),
              content: Text(cnt > 0
                  ? '${accName(r)} me $cnt transactions hain. Account hatane par ye transactions delete NAHI honge, wo Transactions list me rahenge. Sirf account list se hat jayega.'
                  : '${accName(r)} list se hat jayega.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, hatao'))
              ],
            ));
    if (ok == true) macDelete(r);
    return ok == true;
  }

  List<Widget> accManageBody() {
    final rows = accountRows();
    return [
      gap8(card(Text(
          'Yahan se apne bank accounts jodo (+ Add) ya hatao. SMS se mile accounts ko hatane par wo sirf list se chhupte hain, transactions bane rehte hain.',
          style: sub))),
      if (rows.isEmpty) emptyNote('Koi account nahi.\n+ Add dabao'),
      for (final r in rows)
        gap8(card(
            onTap: () => accountPage(r),
            Row(children: [
              Icon(iconFor(r)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(accName(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${r['m'] == true ? 'Khud jora' : 'SMS se mila'} \u2022 A/c ${r['acc']}${accHide.contains(r['k']) ? ' \u2022 Chhupa hua' : ''}',
                    style: sub),
              ])),
              Text(r['bal'] == null ? '-' : mask(r['bal'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
              PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'name') {
                      accRename(r);
                    } else if (v == 'bal') {
                      macEditBal(r);
                    } else if (v == 'edit') {
                      accountForm(r);
                    } else if (v == 'del') {
                      macConfirmDelete(r);
                    } else if (v == 'hide' || v == 'show') {
                      setState(() => v == 'hide' ? accHide.add(r['k'] as String) : accHide.remove(r['k']));
                      sp?.setStringList('achide', accHide.toList());
                      rev.value++;
                    }
                  },
                  itemBuilder: (_) => [
                        const PopupMenuItem(value: 'name', child: Text('Naam set karo')),
                        if (r['m'] == true) const PopupMenuItem(value: 'edit', child: Text('Edit account')),
                        if (r['m'] == true) const PopupMenuItem(value: 'bal', child: Text('Balance badlo')),
                        if (r['m'] == true) const PopupMenuItem(value: 'del', child: Text('Account hatao')),
                        if (r['m'] != true)
                          accHide.contains(r['k'])
                              ? const PopupMenuItem(value: 'show', child: Text('Wapas dikhao'))
                              : const PopupMenuItem(value: 'hide', child: Text('List se hatao')),
                      ]),
            ]))),
    ];
  }

  Future<void> accRename(Map<String, dynamic> r) async {
    final k = r['k'] as String;
    final v = await ask('Account ka naam', [['a', 'Naam (jaise: HDFC Salary, Papa ka account)', 't']], {'a': accLbl[k] ?? ''});
    if (v == null) return;
    final n = (v['a'] ?? '').trim();
    setState(() => n.isEmpty ? accLbl.remove(k) : accLbl[k] = n);
    sp?.setString('acclbl', jsonEncode(accLbl));
    rev.value++;
  }

  void accountDetail(Map<String, dynamic> r) => accountPage(r);

  Map<String, dynamic> cashRow() {
    final cash = balances()['Cash'] ?? 0.0;
    var cr = 0.0, dr = 0.0, atm = 0.0;
    for (final t in all) {
      if (t.manual && t.acc == 'Cash') {
        if (t.debit) {
          dr += t.amt;
        } else {
          cr += t.amt;
        }
      }
      if (!t.manual && t.method == 'ATM' && t.debit && t.kind == 'transfer') atm += t.amt;
    }
    return {
      'k': 'Cash', 'acc': 'Cash', 'bank': 'Cash', 'bal': cash, 'open': cashOpen, 'cr': cr + atm, 'dr': dr, 'atm': atm,
      'cash': true, 'type': 'Cash', 'icon': 'cash', 'note': '', 'when': null, 'm': false
    };
  }

  Map<String, dynamic>? rowFor(String k) {
    if (k == 'Cash') return cashRow();
    for (final r in accountRows()) {
      if (r['k'] == k) return r;
    }
    return null;
  }

  void accountPage(Map<String, dynamic> r0) {
    final k = r0['k'] as String;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<int>(
                valueListenable: rev,
                builder: (ctx, _, __) {
                  final r = rowFor(k);
                  if (r == null) return const Scaffold();
                  final isCash = r['cash'] == true, isM = r['m'] == true;
                  final tl = all.where((t) => isCash ? (t.manual && t.acc == 'Cash') : keyOf(t) == k).toList()
                    ..sort((a, b) => b.d.compareTo(a.d));
                  final items = dayItems(tl);
                  final bal = r['bal'] as double?;
                  final cr = r['cr'] as double, dr = r['dr'] as double;
                  final note = '${r['note']}';
                  return Scaffold(
                    appBar: AppBar(title: Text(accName(r), overflow: TextOverflow.ellipsis)),
                    body: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length + 2,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Icon(iconFor(r)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(
                                            isCash ? 'Cash' : '${r['type']} \u2022 ${r['bank'] == r['k'] ? r['acc'] : '${r['bank']} ${r['acc']}'}',
                                            style: sub)),
                                  ]),
                                  const SizedBox(height: 10),
                                  Text('Current balance', style: sub),
                                  Text(bal == null ? '-' : mask(bal), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    if (isM || isCash) Expanded(child: stat('Opening', mask((r['open'] as double?) ?? 0.0), cs.onSurface)),
                                    Expanded(child: stat('Total Credit', money(cr), gc)),
                                    Expanded(child: stat('Total Debit', money(dr), rc)),
                                  ]),
                                  const SizedBox(height: 8),
                                  if (isM)
                                    Text('Opening (${dt(r['when'] as DateTime)}) + Credit - Debit = Current. Transfer bhi credit/debit me judte hain.',
                                        style: sub),
                                  if (isM && r['smsBal'] != null)
                                    Text('Bank SMS balance: ${mask(r['smsBal'] as double)} (${dt(r['smsWhen'] as DateTime)})', style: sub),
                                  if (!isM && !isCash)
                                    Text('Balance bank SMS se (${r['when'] == null ? '-' : dt(r['when'] as DateTime)}). Credit/Debit sirf tracked transactions ke hain.',
                                        style: sub),
                                  if (isCash)
                                    Text('Opening + Credit - Debit = Current. ATM se nikale (bank se): ${money((r['atm'] as double?) ?? 0.0)} credit me shamil.',
                                        style: sub),
                                  if (note.isNotEmpty) Text('Note: $note', style: sub),
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 8, runSpacing: 4, children: [
                                    if (isM)
                                      OutlinedButton.icon(
                                          onPressed: () => accountForm(r),
                                          icon: const Icon(Icons.edit, size: 18),
                                          label: const Text('Edit')),
                                    if (isM)
                                      OutlinedButton.icon(
                                          onPressed: () => macEditBal(r),
                                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                                          label: const Text('Balance badlo')),
                                    if (isCash)
                                      OutlinedButton.icon(
                                          onPressed: cashOpenEdit,
                                          icon: const Icon(Icons.edit, size: 18),
                                          label: const Text('Opening badlo')),
                                    if (!isCash)
                                      OutlinedButton.icon(
                                          onPressed: () => accRename(r),
                                          icon: const Icon(Icons.badge_outlined, size: 18),
                                          label: const Text('Naam')),
                                    if (isM)
                                      TextButton.icon(
                                          onPressed: () async {
                                            if (await macConfirmDelete(r) && ctx.mounted) Navigator.pop(ctx);
                                          },
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          label: const Text('Hatao')),
                                    if (!isM && !isCash)
                                      TextButton.icon(
                                          onPressed: () {
                                            setState(() => accHide.add(k));
                                            sp?.setStringList('achide', accHide.toList());
                                            rev.value++;
                                            Navigator.pop(ctx);
                                          },
                                          icon: const Icon(Icons.visibility_off_outlined, size: 18),
                                          label: const Text('List se hatao')),
                                  ]),
                                ])));
                          }
                          if (i == 1) {
                            return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
                                child: Text(tl.isEmpty ? 'Is account me abhi koi transaction nahi' : 'History (${tl.length})',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
                          }
                          final it = items[i - 2];
                          if (it is _Day) return dayHdr(it);
                          return txCard(it as Tx, showDate: false);
                        }),
                  );
                })));
  }

  void editMeta(Tx t) {
    var kind = t.kind, cat = t.cat;
    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(builder: (ctx, ss) {
              final opts = catsFor(kind);
              if (!opts.contains(cat)) cat = opts.first;
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Text('Type & category'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, children: [
                    for (final k in const ['expense', 'income', 'transfer'])
                      ChoiceChip(
                          label: Text(k[0].toUpperCase() + k.substring(1)),
                          selected: kind == k,
                          onSelected: (_) => ss(() => kind = k))
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: cat,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [for (final c in opts) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => ss(() => cat = v ?? cat)),
                ])),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        setState(() {
                          t.kind = kind;
                          t.cat = cat;
                        });
                        if (t.manual) {
                          saveManual();
                        } else {
                          meta[t.id] = {'k': kind, 'c': cat};
                          sp?.setString('meta', jsonEncode(meta));
                        }
                        rev.value++;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'))
                ],
              );
            }));
  }

  void setCatBudget(String c) {
    final ctl = TextEditingController(text: (cb[c] ?? 0) > 0 ? cb[c]!.toStringAsFixed(0) : '');
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('$c budget'),
              content: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: rs)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final v = double.tryParse(ctl.text) ?? 0;
                      setState(() => v > 0 ? cb[c] = v : cb.remove(c));
                      sp?.setString('cb', jsonEncode(cb));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'))
              ],
            ));
  }

  Widget catBudgetCard(String c, double sp) {
    final lim = cb[c] ?? 0;
    final p = lim > 0 ? sp / lim : 0.0;
    final col = p >= 1 ? rc : p >= 0.9 ? Colors.deepOrange : p >= 0.8 ? Colors.amber : gc;
    final msg = lim <= 0
        ? 'Limit set nahi (tap karke set karo)'
        : p >= 1
            ? 'Budget exceeded'
            : p >= 0.9
                ? '90% reach ho gaya'
                : p >= 0.8
                    ? '80% reach ho gaya'
                    : '${(p * 100).round()}% use hua';
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: card(
            onTap: () => setCatBudget(c),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('${money(sp)} / ${lim > 0 ? money(lim) : '-'}', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ]),
              if (lim > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: p.clamp(0.0, 1.0).toDouble(), minHeight: 8, color: col)),
              ],
              const SizedBox(height: 4),
              Text(msg, style: TextStyle(fontSize: 12, color: lim > 0 ? col : cs.onSurfaceVariant)),
            ])));
  }

  List<Map<String, dynamic>> rec = [], loans = [], goals = [];
  Set<String> dupOk = {}, dupSet = {};
  String? pin;
  bool hideBal = false, lockShown = false;
  final recF = const [['name', 'Naam (Rent, Netflix...)', 't'], ['amt', 'Amount', 'n'], ['day', 'Mahine ki tareekh (1-31)', 'n']];
  final loanF = const [['name', 'Loan naam', 't'], ['emi', 'EMI amount', 'n'], ['day', 'EMI tareekh (1-31)', 'n'], ['months', 'Total mahine', 'n'], ['paid', 'Ab tak kitne EMI bhare', 'n']];
  final goalF = const [['name', 'Goal naam', 't'], ['target', 'Target amount', 'n'], ['saved', 'Ab tak jama', 'n']];

  List<Map<String, dynamic>> ld(String k) =>
      (jsonDecode(sp!.getString(k) ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)).toList();
  double nv(Map m, String k) => double.tryParse('${m[k]}') ?? 0;
  String fs(dynamic v) => v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v';

  void saveLists() {
    sp?.setString('rec', jsonEncode(rec));
    sp?.setString('loans', jsonEncode(loans));
    sp?.setString('goals', jsonEncode(goals));
    setState(() {});
    rev.value++;
  }

  bool isDup(Tx t) {
    final cur = all;
    if (!identical(cur, _dupFor) || _dupOkLen != dupOk.length) {
      _dupFor = cur;
      _dupOkLen = dupOk.length;
      final g = <String, List<Tx>>{};
      for (final x in cur) {
        (g['${x.party.toLowerCase()}|${x.amt}|${x.acc}|${x.debit}'] ??= []).add(x);
      }
      dupSet = {};
      for (final l in g.values) {
        if (l.length < 2) continue;
        l.sort((a, b) => a.d.compareTo(b.d));
        for (var i = 1; i < l.length; i++) {
          if (l[i].d.difference(l[i - 1].d).inSeconds.abs() <= 120) {
            dupSet
              ..add(l[i].id)
              ..add(l[i - 1].id);
          }
        }
      }
      dupSet.removeAll(dupOk);
    }
    return dupSet.contains(t.id);
  }

  DateTime nextDue(int day) {
    final n = DateTime.now();
    final t = DateTime(n.year, n.month, n.day);
    DateTime mk(int y, int m) => DateTime(y, m, day.clamp(1, DateTime(y, m + 1, 0).day).toInt());
    final a = mk(n.year, n.month);
    return a.isBefore(t) ? mk(n.year, n.month + 1) : a;
  }

  String ym(DateTime d) => '${d.year}-${two(d.month)}';

  DateTime dueIn(int y, int m, int day) {
    final dy = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day.clamp(1, dy).toInt());
  }

  // Bill/EMI ka transaction se milan: naam ya amount+tareekh se
  Tx? matchPay(String name, double amt, DateTime due) {
    if (amt <= 0) return null;
    final words = name.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3).toList();
    Tx? best;
    for (final t in all) {
      if (!t.debit || t.kind == 'transfer') continue;
      final diff = t.d.difference(due).inDays.abs();
      if (diff > 12) continue;
      if ((t.amt - amt).abs() > amt * 0.05 + 1) continue;
      final hay = '${nm(t)} ${t.party} ${notes[t.id] ?? ''} ${t.cat}'.toLowerCase();
      final nameOk = words.isNotEmpty && words.any((w) => hay.contains(w));
      final exact = (t.amt - amt).abs() < 0.5 && diff <= 3;
      if (nameOk || exact) {
        if (best == null || t.d.isAfter(best.d)) best = t;
      }
    }
    return best;
  }

  Map<String, dynamic> dueInfo(String kind, Map<String, dynamic> src, int idx) {
    final isEmi = kind == 'EMI';
    final name = '${src['name']}';
    final amt = nv(src, isEmi ? 'emi' : 'amt');
    final day = nv(src, 'day').toInt();
    final pm = src['pm'] is List ? (src['pm'] as List).map((e) => '$e').toList() : <String>[];
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    Map<String, dynamic> pack(DateTime cyc, DateTime shown, String st, Tx? m, bool marked) => {
          'k': kind, 'n': name, 'a': amt, 'd': shown, 'cyc': cyc, 'st': st, 'days': shown.difference(today).inDays,
          'm': m, 'marked': marked, 'src': src, 'idx': idx
        };
    // Pichhle mahine ki due (sirf naye items ke liye jinka 'cr' hai)
    final cr = src['cr'];
    if (cr is int) {
      final prev = dueIn(n.year, n.month - 1, day);
      if (DateTime.fromMillisecondsSinceEpoch(cr).isBefore(prev) && !prev.isAfter(today) && today.difference(prev).inDays <= 15) {
        final pmk = pm.contains(ym(prev));
        final pmm = pmk ? null : matchPay(name, amt, prev);
        if (!pmk && pmm == null) return pack(prev, prev, 'overdue', null, false);
      }
    }
    final cur = dueIn(n.year, n.month, day);
    final marked = pm.contains(ym(cur));
    final m = matchPay(name, amt, cur);
    if (marked || m != null) return pack(cur, dueIn(n.year, n.month + 1, day), 'paid', m, marked);
    final st = cur.isBefore(today) ? 'overdue' : (cur.difference(today).inDays <= 7 ? 'soon' : 'later');
    return pack(cur, cur, st, null, false);
  }

  void markPm(Map<String, dynamic> src, DateTime cyc, bool on) {
    final l = src['pm'] is List ? (src['pm'] as List).map((e) => '$e').toList() : <String>[];
    final k = ym(cyc);
    if (on) {
      if (!l.contains(k)) l.add(k);
    } else {
      l.remove(k);
    }
    src['pm'] = l;
  }

  List<Map<String, dynamic>> dues() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < rec.length; i++) {
      out.add(dueInfo('Bill', rec[i], i));
    }
    for (var i = 0; i < loans.length; i++) {
      if (nv(loans[i], 'paid') < nv(loans[i], 'months')) out.add(dueInfo('EMI', loans[i], i));
    }
    out.sort((a, b) => (a['d'] as DateTime).compareTo(b['d'] as DateTime));
    return out;
  }

  // Is mahine ke baaki (unpaid + late) bills/EMI ka total
  double upcomingMonth() {
    final n = DateTime.now();
    return dues().where((x) {
      if (x['st'] == 'paid') return false;
      final d = x['d'] as DateTime;
      return x['st'] == 'overdue' || (d.month == n.month && d.year == n.year);
    }).fold<double>(0, (s, x) => s + (x['a'] as double));
  }

  String dueLabel(Map<String, dynamic> x) {
    final d = x['days'] as int;
    final st = x['st'];
    if (st == 'paid') return 'Paid \u2713';
    if (st == 'overdue') return '${d.abs()} din late';
    return d == 0 ? 'Aaj due' : d == 1 ? 'Kal due' : '$d din me';
  }

  Color dueColor(Map<String, dynamic> x) {
    final st = x['st'];
    if (st == 'paid') return gc;
    if (st == 'overdue') return rc;
    if (st == 'soon' && (x['days'] as int) <= 2) return Colors.orange;
    return cs.onSurfaceVariant;
  }

  String nextTxt(String kind, Map<String, dynamic> src, int i) {
    final x = dueInfo(kind, src, i);
    return 'Next: ${dt(x['d'] as DateTime)} \u2022 ${dueLabel(x)}';
  }

  void openReminders() => openPage('Bills aur Reminders', remindersBody, addReminder);

  Future<void> addReminder() async {
    final c = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Kya jodna hai?'), children: [
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'bill'), child: const Text('Bill / Recurring payment')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'emi'), child: const Text('EMI / Loan')),
            ]));
    if (c == 'bill') {
      await editItem(rec, null, 'Recurring payment', recF);
    } else if (c == 'emi') {
      await editItem(loans, null, 'EMI / Loan', loanF);
    }
  }

  Widget remRow(Map<String, dynamic> x) {
    final isEmi = x['k'] == 'EMI';
    final src = x['src'] as Map<String, dynamic>;
    final m = x['m'] as Tx?;
    final paid = x['st'] == 'paid';
    final col = dueColor(x);
    return gap8(card(Row(children: [
      Icon(isEmi ? Icons.account_balance : Icons.repeat),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${x['n']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('${x['k']} \u2022 ${money(x['a'] as double)} \u2022 ${dt(x['d'] as DateTime)}', style: sub),
        if (m != null) Text('Match: ${nm(m)} \u2022 ${dt(m.d)}', style: TextStyle(fontSize: 12, color: gc)),
        if (x['marked'] == true) Text('Aapne paid mark kiya hai', style: sub),
      ])),
      Text(dueLabel(x), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: col)),
      PopupMenuButton<String>(
          onSelected: (v) {
            final cyc = x['cyc'] as DateTime;
            if (v == 'pay') {
              markPm(src, cyc, true);
              saveLists();
            } else if (v == 'unpay') {
              markPm(src, cyc, false);
              saveLists();
            } else if (v == 'emi') {
              if (nv(src, 'paid') < nv(src, 'months')) {
                src['paid'] = nv(src, 'paid') + 1;
                markPm(src, cyc, true);
                saveLists();
              }
            } else if (v == 'edit') {
              editItem(isEmi ? loans : rec, x['idx'] as int, isEmi ? 'Edit loan' : 'Edit', isEmi ? loanF : recF);
            }
          },
          itemBuilder: (_) => [
                if (!paid) const PopupMenuItem(value: 'pay', child: Text('Paid mark karo')),
                if (x['marked'] == true) const PopupMenuItem(value: 'unpay', child: Text('Paid hatao')),
                if (isEmi) const PopupMenuItem(value: 'emi', child: Text('EMI paid (+1)')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              ]),
    ])));
  }

  List<Widget> remindersBody() {
    final d = dues();
    final over = d.where((x) => x['st'] == 'overdue').toList();
    final soon = d.where((x) => x['st'] == 'soon').toList();
    final later = d.where((x) => x['st'] == 'later').toList();
    final paid = d.where((x) => x['st'] == 'paid').toList();
    Widget sec(String t, List<Map<String, dynamic>> l, Color c) => l.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 10, 0, 6), child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c))),
            for (final x in l) remRow(x),
          ]);
    return [
      gap8(card(Row(children: [
        Expanded(child: stat('Is mahine baaki', money(upcomingMonth()), rc)),
        Expanded(child: stat('Late', '${over.length}', over.isEmpty ? gc : rc)),
        Expanded(child: stat('Paid', '${paid.length}', gc)),
      ]))),
      if (d.isEmpty) emptyNote('Koi bill ya EMI nahi.\n+ Add dabao'),
      sec('Late / overdue', over, rc),
      sec('Is hafte (7 din)', soon, Colors.orange),
      sec('Baad me', later, cs.onSurfaceVariant),
      sec('Is mahine paid', paid, gc),
      if (d.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Bill/EMI apne aap "Paid" ho jata hai jab usi naam/amount ka debit transaction mil jaye. Na mile to menu se Paid mark karo.', style: sub)),
    ];
  }

  Widget upcomingCard() {
    final u = dues().where((x) => x['st'] == 'overdue' || x['st'] == 'soon').toList();
    if (u.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: card(
            onTap: openReminders,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Bills aur EMI (7 din)', style: TextStyle(fontWeight: FontWeight.bold))),
                const Icon(Icons.chevron_right, size: 20),
              ]),
              const SizedBox(height: 8),
              for (final x in u)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text('${x['k']}: ${x['n']}  \u2022  ${dt(x['d'] as DateTime)}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(money(x['a'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(dueLabel(x), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dueColor(x))),
                    ])),
            ])));
  }

  // ---------- Budget alerts ----------
  List<Map<String, dynamic>> budgetAlerts() {
    final out = <Map<String, dynamic>>[];
    final n = DateTime.now();
    final mAll = all.where((t) => inCyc(t.d)).toList();
    final sp = spent(mAll);
    final dim = cycDim();
    final pend = upcomingMonth();
    void lvl(String what, double used, double lim) {
      if (lim <= 0) return;
      final p = used / lim;
      if (p >= 1) {
        out.add({'l': 2, 'm': '$what budget cross ho gaya (${money(used)} / ${money(lim)})'});
      } else if (p >= 0.9 && alertPct <= 90) {
        out.add({'l': 2, 'm': '$what budget ka 90% use ho gaya'});
      } else if (p >= alertPct / 100) {
        out.add({'l': 1, 'm': '$what budget ka $alertPct% use ho gaya'});
      }
    }

    lvl('Monthly', sp, budget);
    for (final c in expCats) {
      final cs2 = spent(mAll.where((t) => t.kind == 'expense' && t.cat == c).toList());
      lvl(c, cs2, cb[c] ?? 0);
    }
    if (budget > 0 && sp < budget && cycElapsed() >= 5) {
      final proj = sp / cycElapsed() * dim;
      if (proj > budget) {
        out.add({'l': 1, 'm': 'Is raftaar se mahine ke ant tak ${money(proj)} kharch ho sakta hai (budget se ${money(proj - budget)} zyada)'});
      }
    }
    if (budget > 0 && sp < budget && pend > 0 && sp + pend > budget) {
      out.add({'l': 1, 'm': 'Baaki bills/EMI (${money(pend)}) ke baad budget cross ho sakta hai'});
    }
    final od = dues().where((x) => x['st'] == 'overdue').length;
    if (od > 0) out.add({'l': 2, 'm': '$od bill/EMI late hai', 'rem': true});
    out.sort((a, b) => (b['l'] as int).compareTo(a['l'] as int));
    return out;
  }

  Widget alertsCard() {
    final a = budgetAlerts();
    if (a.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(children: [
          for (final x in a.take(3))
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                    color: ((x['l'] as int) >= 2 ? rc : Colors.orange).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: x['rem'] == true ? openReminders : null,
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Expanded(
                                  child: Text(x['m'] as String,
                                      style: TextStyle(fontSize: 14, color: (x['l'] as int) >= 2 ? rc : Colors.orange))),
                            ]))))),
        ]));
  }

  Future<Map<String, String>?> ask(String title, List<List<String>> f, [Map<String, String>? init]) {
    final c = {for (final x in f) x[0]: TextEditingController(text: init?[x[0]] ?? '')};
    return showDialog<Map<String, String>>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(title),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final x in f)
                  TextField(
                      controller: c[x[0]],
                      keyboardType: x[2] == 'n' || x[2] == 'p' ? TextInputType.number : TextInputType.text,
                      obscureText: x[2] == 'p' || x[2] == 'w',
                      decoration: InputDecoration(labelText: x[1]))
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, {for (final e in c.entries) e.key: e.value.text.trim()}),
                    child: const Text('Save'))
              ],
            ));
  }

  Future<void> editItem(List<Map<String, dynamic>> list, int? i, String title, List<List<String>> f) async {
    final r = await ask(title, f, i == null ? null : {for (final x in f) x[0]: fs(list[i][x[0]])});
    if (r == null || (r[f.first[0]] ?? '').isEmpty) return;
    final m = <String, dynamic>{
      for (final x in f) x[0]: x[2] == 'n' ? (double.tryParse(r[x[0]]!) ?? 0) : r[x[0]]
    };
    if (m.containsKey('day')) m['day'] = nv(m, 'day').clamp(1, 31).toDouble();
    if (i == null) {
      m['cr'] = DateTime.now().millisecondsSinceEpoch;
      list.add(m);
    } else {
      for (final e in list[i].entries) {
        m.putIfAbsent(e.key, () => e.value);
      }
      list[i] = m;
    }
    saveLists();
  }

  void openPage(String title, List<Widget> Function() body, VoidCallback? onAdd) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<int>(
                valueListenable: rev,
                builder: (ctx, _, __) => Scaffold(
                      appBar: AppBar(title: Text(title)),
                      floatingActionButton: onAdd == null
                          ? null
                          : FloatingActionButton.extended(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add')),
                      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: body()),
                    ))));
  }

  Widget emptyNote(String s) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(s, textAlign: TextAlign.center)));
  Widget gap8(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w);

  List<Widget> recBody() => [
        if (rec.isEmpty) emptyNote('Koi recurring payment nahi.\n+ Add dabao (rent, Netflix, recharge...)'),
        for (var i = 0; i < rec.length; i++)
          gap8(card(Row(children: [
            const Icon(Icons.repeat),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${rec[i]['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${money(nv(rec[i], 'amt'))} \u2022 har mahine ${fs(rec[i]['day'])} tareekh', style: sub),
              Text(nextTxt('Bill', rec[i], i), style: sub),
            ])),
            PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'del') {
                    rec.removeAt(i);
                    saveLists();
                  } else if (v == 'pay') {
                    markPm(rec[i], dueInfo('Bill', rec[i], i)['cyc'] as DateTime, true);
                    saveLists();
                  } else {
                    editItem(rec, i, 'Edit', recF);
                  }
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pay', child: Text('Is mahine paid mark karo')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'del', child: Text('Delete'))
                    ]),
          ]))),
      ];

  List<Widget> loanBody() {
    final act = loans.where((l) => nv(l, 'paid') < nv(l, 'months')).toList();
    final monthly = act.fold<double>(0, (s, l) => s + nv(l, 'emi'));
    final remain = act.fold<double>(0, (s, l) => s + (nv(l, 'months') - nv(l, 'paid')) * nv(l, 'emi'));
    return [
      gap8(card(Row(children: [
        Expanded(child: stat('Monthly EMI', money(monthly), rc)),
        Expanded(child: stat('Total remaining', money(remain), cs.onSurface)),
      ]))),
      if (loans.isEmpty) emptyNote('Koi loan / EMI nahi.\n+ Add dabao'),
      for (var i = 0; i < loans.length; i++)
        gap8(card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${loans[i]['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'del') {
                    loans.removeAt(i);
                    saveLists();
                  } else if (v == 'paid') {
                    if (nv(loans[i], 'paid') < nv(loans[i], 'months')) {
                      markPm(loans[i], dueInfo('EMI', loans[i], i)['cyc'] as DateTime, true);
                      loans[i]['paid'] = nv(loans[i], 'paid') + 1;
                      saveLists();
                    }
                  } else {
                    editItem(loans, i, 'Edit loan', loanF);
                  }
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'paid', child: Text('EMI paid (+1)')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'del', child: Text('Delete'))
                    ]),
          ]),
          Text('${money(nv(loans[i], 'emi'))} / month'),
          const SizedBox(height: 8),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: nv(loans[i], 'months') > 0
                      ? (nv(loans[i], 'paid') / nv(loans[i], 'months')).clamp(0.0, 1.0).toDouble()
                      : 0.0,
                  minHeight: 8,
                  color: gc)),
          const SizedBox(height: 6),
          Text('Paid ${fs(loans[i]['paid'])} / ${fs(loans[i]['months'])}  \u2022  Remaining ${money((nv(loans[i], 'months') - nv(loans[i], 'paid')) * nv(loans[i], 'emi'))}',
              style: sub),
          Text(nv(loans[i], 'paid') < nv(loans[i], 'months')
              ? nextTxt('EMI', loans[i], i)
              : 'Loan complete!', style: sub),
        ]))),
    ];
  }

  List<Widget> goalBody() => [
        if (goals.isEmpty) emptyNote('Koi savings goal nahi.\n+ Add dabao (House, Phone, Emergency...)'),
        for (var i = 0; i < goals.length; i++)
          gap8(card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${goals[i]['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'del') {
                      goals.removeAt(i);
                      saveLists();
                    } else if (v == 'add') {
                      final r = await ask('Paise jodo', [['amt', 'Amount', 'n']]);
                      final a = double.tryParse(r?['amt'] ?? '') ?? 0;
                      if (a > 0) {
                        goals[i]['saved'] = nv(goals[i], 'saved') + a;
                        saveLists();
                      }
                    } else {
                      editItem(goals, i, 'Edit goal', goalF);
                    }
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(value: 'add', child: Text('Paise jodo')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'del', child: Text('Delete'))
                      ]),
            ]),
            Text('${money(nv(goals[i], 'saved'))} / ${money(nv(goals[i], 'target'))}'),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: nv(goals[i], 'target') > 0
                        ? (nv(goals[i], 'saved') / nv(goals[i], 'target')).clamp(0.0, 1.0).toDouble()
                        : 0.0,
                    minHeight: 8,
                    color: gc)),
            const SizedBox(height: 4),
            Text('${nv(goals[i], 'target') > 0 ? (nv(goals[i], 'saved') * 100 / nv(goals[i], 'target')).round() : 0}% complete', style: sub),
          ]))),
      ];

  Widget moreTile(IconData ic, String t, String s, VoidCallback f) => gap8(card(
      onTap: f,
      Row(children: [
        avatar(tileCode(t), bg: cs.primaryContainer, fg: cs.primary, size: 48),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(s, style: sub),
        ])),
        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ])));

  Widget morePage() {
    final monthly = loans.where((l) => nv(l, 'paid') < nv(l, 'months')).fold<double>(0, (s, l) => s + nv(l, 'emi'));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      head('More'),
      moreTile(Icons.account_balance_wallet_outlined, 'Accounts manage karo', '${accountRows().length} accounts \u2022 jodo / hatao', openAccManage),
      moreTile(Icons.notifications_active_outlined, 'Bills aur Reminders', '${dues().where((x) => x['st'] == 'overdue').length} late \u2022 is mahine baaki ${money(upcomingMonth())}', openReminders),
      moreTile(Icons.repeat, 'Recurring Payments', '${rec.length} payments', () => openPage('Recurring Payments', recBody, () => editItem(rec, null, 'Recurring payment', recF))),
      moreTile(Icons.account_balance, 'EMI / Loans', 'Monthly EMI ${money(monthly)}', () => openPage('EMI / Loans', loanBody, () => editItem(loans, null, 'EMI / Loan', loanF))),
      moreTile(Icons.savings_outlined, 'Savings Goals', '${goals.length} goals', () => openPage('Savings Goals', goalBody, () => editItem(goals, null, 'Savings goal', goalF))),
      moreTile(Icons.insights_outlined, 'Tracking Report', 'SMS / Email / Manual ka summary', () => openPage('Tracking Report', trackBody, null)),
      moreTile(Icons.settings_outlined, 'Settings', 'App lock, backup, export', () => openPage('Settings', settingsBody, null)),
    ]);
  }

  String hp(String s) {
    var h = 5381;
    for (final c in 'mk$s'.codeUnits) {
      h = ((h * 33) ^ c) & 0x7fffffff;
    }
    return h.toString();
  }

  void snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      pausedAt = DateTime.now().millisecondsSinceEpoch;
      if (pin != null && lockDelay == 0) showLock();
    }
    if (s == AppLifecycleState.resumed) {
      if (pin != null && lockDelay > 0 && DateTime.now().millisecondsSinceEpoch - pausedAt >= lockDelay * 1000) showLock();
      onResume();
    }
  }

  // App khulte hi naye SMS / email apne aap aa jayein
  void onResume() {
    if (sp == null || refreshing) return;
    autoBackups();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastLoadMs > 60000 && !needSms) load();
    final last = sp?.getInt('emLast') ?? 0;
    if (sp?.getString('eAddr') != null && now - last > 300000) syncEmail(quiet: true);
  }

  void showLock() {
    if (lockShown || pin == null || !mounted) return;
    lockShown = true;
    Navigator.of(context)
        .push(MaterialPageRoute(
            fullscreenDialog: true, builder: (_) => PopScope(canPop: false, child: LockScreen((v) => hp(v) == pin))))
        .then((_) => lockShown = false);
  }

  Future<void> setPin() async {
    final r = await ask('PIN set karo', [['a', 'Naya PIN (4-6 digit)', 'p'], ['b', 'PIN dobara', 'p']]);
    if (r == null) return;
    if (!RegExp(r'^\d{4,6}$').hasMatch(r['a']!) || r['a'] != r['b']) {
      snack('PIN 4-6 digit ka ho aur dono baar same ho');
      return;
    }
    pin = hp(r['a']!);
    sp?.setString('pin', pin!);
    setState(() {});
    rev.value++;
    snack('App lock on ho gaya');
  }

  Future<void> changePin() async {
    final r = await ask('PIN badlo', [['o', 'Purana PIN', 'p'], ['a', 'Naya PIN (4-6 digit)', 'p'], ['b', 'Naya PIN dobara', 'p']]);
    if (r == null) return;
    if (hp(r['o']!) != pin) {
      snack('Purana PIN galat hai');
    } else if (!RegExp(r'^\d{4,6}$').hasMatch(r['a']!) || r['a'] != r['b']) {
      snack('Naya PIN 4-6 digit ka ho aur dono baar same ho');
    } else {
      pin = hp(r['a']!);
      sp?.setString('pin', pin!);
      snack('PIN badal gaya');
    }
  }

  Future<void> removePin() async {
    final r = await ask('Current PIN', [['a', 'PIN', 'p']]);
    if (r == null) return;
    if (hp(r['a']!) == pin) {
      pin = null;
      sp?.remove('pin');
      setState(() {});
      rev.value++;
      snack('App lock band ho gaya');
    } else {
      snack('Galat PIN');
    }
  }

  Map<String, dynamic> backupMap({bool withEmail = true}) => {
        'v': 1, 'budget': budget, 'manual': manual.map((e) => e.toJson()).toList(), 'names': names, 'alias': alias,
        'hidden': hidden.toList(), 'meta': meta, 'cb': cb, 'rec': rec, 'loans': loans, 'goals': goals,
        'dupok': dupOk.toList(), 'acclbl': accLbl, 'achide': accHide.toList(), 'macc': macc,
        'notes': notes, 'cashopen': cashOpen, 'start': startD.millisecondsSinceEpoch,
        if (withEmail) 'eAddr': sp?.getString('eAddr'),
        if (withEmail) 'ePass': sp?.getString('ePass'),
      };

  Future<void> backup() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(backupMap())));
    snack('Backup copy ho gaya (Gmail link bhi isme hai). Notes me save karo, kaam hone ke baad delete kar dena');
  }

  // ---------- Snapshots (is phone me apne aap backup) ----------
  List<Map<String, dynamic>> snapList() {
    final out = <Map<String, dynamic>>[];
    for (final e in sp?.getStringList('snaps') ?? <String>[]) {
      try {
        out.add(Map<String, dynamic>.from(jsonDecode(e) as Map));
      } catch (_) {}
    }
    return out;
  }

  Future<void> takeSnapshot(String tag) async {
    try {
      final z = base64Encode(gzip.encode(utf8.encode(jsonEncode(backupMap(withEmail: false)))));
      final l = sp?.getStringList('snaps') ?? <String>[];
      l.add(jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'tag': tag, 'z': z}));
      while (l.length > 5) {
        l.removeAt(0);
      }
      await sp?.setStringList('snaps', l);
    } catch (_) {}
  }

  void autoBackups() {
    if (sp == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final snaps = snapList().where((e) => e['tag'] == 'auto').toList();
    final lastSnap = snaps.isEmpty ? 0 : (snaps.last['t'] as int);
    if (now - lastSnap > 86400000) takeSnapshot('auto');
    final mode = sp?.getString('ebMode') ?? 'off';
    if (mode != 'off' && sp?.getString('eAddr') != null) {
      final last = sp?.getInt('ebLast') ?? 0;
      if (now - last > (mode == 'daily' ? 86400000 : 604800000)) emailBackup(quiet: true);
    }
  }

  void openSnaps() => openPage('Auto snapshots', snapBody, () async {
        await takeSnapshot('manual');
        rev.value++;
        snack('Snapshot ban gaya');
      });

  List<Widget> snapBody() {
    final l = snapList().reversed.toList();
    return [
      gap8(card(Text(
          'App har 24 ghante me apne aap data ka snapshot leti hai (last 5 rakhti hai). Restore se pehle bhi ek snapshot ban jata hai. Ye sirf is phone me rehte hain. Phone ya uninstall se bachne ke liye Gmail backup use karo.',
          style: sub))),
      if (l.isEmpty) emptyNote('Abhi koi snapshot nahi.\n+ Add dabao'),
      for (final e in l)
        gap8(card(Row(children: [
          const Icon(Icons.history),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${dt(DateTime.fromMillisecondsSinceEpoch(e['t'] as int))}  ${tm(DateTime.fromMillisecondsSinceEpoch(e['t'] as int))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${e['tag'] == 'auto' ? 'Auto' : e['tag'] == 'manual' ? 'Manual' : 'Restore se pehle'} \u2022 ${((e['z'] as String).length / 1024).ceil()} KB', style: sub),
          ])),
          PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'restore') {
                  try {
                    restore(utf8.decode(gzip.decode(base64Decode(e['z'] as String))));
                  } catch (_) {
                    snack('Snapshot padh nahi paya');
                  }
                } else {
                  final raw = sp?.getStringList('snaps') ?? <String>[];
                  raw.removeWhere((x) => (jsonDecode(x) as Map)['t'] == e['t']);
                  sp?.setStringList('snaps', raw);
                  rev.value++;
                }
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'restore', child: Text('Restore karo')),
                    PopupMenuItem(value: 'del', child: Text('Delete')),
                  ]),
        ]))),
    ];
  }

  // ---------- Gmail se backup / restore ----------
  String ebSub() {
    final l = sp?.getInt('ebLast');
    if (l == null) return 'Abhi tak nahi bheja';
    final d = DateTime.fromMillisecondsSinceEpoch(l);
    return 'Last: ${dt(d)} ${tm(d)}';
  }

  String ebModeLabel() {
    final m = sp?.getString('ebMode') ?? 'off';
    return m == 'daily' ? 'Roz' : m == 'weekly' ? 'Har hafte' : 'Off';
  }

  Future<void> pickEbMode() async {
    final v = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Auto email backup'), children: [
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'off'), child: const Text('Off')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'weekly'), child: const Text('Har hafte')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'daily'), child: const Text('Roz')),
            ]));
    if (v == null) return;
    await sp?.setString('ebMode', v);
    rev.value++;
  }

  Future<void> emailBackup({bool quiet = false}) async {
    final addr = sp?.getString('eAddr'), pass = sp?.getString('ePass');
    if (addr == null || pass == null) {
      if (!quiet) snack('Pehle Gmail jodo');
      return;
    }
    if (ebBusy) return;
    ebBusy = true;
    if (!quiet) snack('Backup email bhej raha hoon...');
    final client = mail.SmtpClient('mykharcha', isLogEnabled: false);
    try {
      const to = Duration(seconds: 45);
      await client.connectToServer('smtp.gmail.com', 465, isSecure: true).timeout(to);
      await client.ehlo().timeout(to);
      await client.authenticate(addr, pass, mail.AuthMechanism.plain).timeout(to);
      final data = base64Encode(utf8.encode(jsonEncode(backupMap(withEmail: false))));
      final lines = <String>[];
      for (var i = 0; i < data.length; i += 76) {
        lines.add(data.substring(i, i + 76 > data.length ? data.length : i + 76));
      }
      final now = DateTime.now();
      final b = mail.MessageBuilder()
        ..from = [mail.MailAddress('Mera Kharcha', addr)]
        ..to = [mail.MailAddress('Mera Kharcha', addr)]
        ..subject = 'MeraKharcha-Backup ${dt(now)} ${tm(now)}'
        ..text = 'Ye Mera Kharcha app ka backup hai. Ise delete mat karo.\n\n---BEGIN---\n${lines.join('\n')}\n---END---\n';
      await client.sendMessage(b.buildMimeMessage()).timeout(const Duration(seconds: 90));
      await sp?.setInt('ebLast', now.millisecondsSinceEpoch);
      if (!quiet && mounted) snack('Backup Gmail par bhej diya');
    } catch (e) {
      if (!quiet && mounted) snack('Email backup nahi ho paya. Internet aur Gmail App Password check karo');
    } finally {
      try {
        await client.quit();
      } catch (_) {}
      ebBusy = false;
      rev.value++;
    }
  }

  Future<void> emailRestore() async {
    final addr = sp?.getString('eAddr'), pass = sp?.getString('ePass');
    if (addr == null || pass == null) {
      snack('Pehle Gmail jodo');
      return;
    }
    snack('Gmail me backup dhoondh raha hoon...');
    final client = mail.ImapClient(isLogEnabled: false);
    final cands = <MapEntry<DateTime, String>>[];
    var failed = false;
    try {
      const to = Duration(seconds: 60);
      await client.connectToServer('imap.gmail.com', 993, isSecure: true).timeout(to);
      await client.login(addr, pass).timeout(to);
      await client.selectInbox().timeout(to);
      final r = await client.fetchRecentMessages(messageCount: 200, criteria: 'BODY.PEEK[]').timeout(const Duration(seconds: 180));
      for (final m in r.messages) {
        if (!(m.decodeSubject() ?? '').startsWith('MeraKharcha-Backup')) continue;
        final text = m.decodeTextPlainPart() ?? '';
        final a = text.indexOf('---BEGIN---'), b = text.indexOf('---END---');
        if (a < 0 || b < a) continue;
        cands.add(MapEntry(m.decodeDate() ?? DateTime(2000), text.substring(a + 11, b)));
      }
    } catch (_) {
      failed = true;
    } finally {
      try {
        await client.logout();
      } catch (_) {}
    }
    if (!mounted) return;
    if (failed) {
      snack('Gmail se connect nahi ho paya');
      return;
    }
    if (cands.isEmpty) {
      snack('Last 200 emails me koi backup nahi mila');
      return;
    }
    cands.sort((a, b) => b.key.compareTo(a.key));
    final pick = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Kaunsa backup restore karna hai?'), children: [
              for (var i = 0; i < cands.length && i < 8; i++)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, i),
                    child: Text('${dt(cands[i].key)}  ${tm(cands[i].key)} \u2022 ${(cands[i].value.length / 1024).ceil()} KB')),
            ]));
    if (pick == null) return;
    try {
      final txt = utf8.decode(base64Decode(cands[pick].value.replaceAll(RegExp(r'\s+'), '')));
      await restore(txt);
    } catch (_) {
      snack('Ye backup email padh nahi paya');
    }
  }

  Future<bool> confirmRestore(Map<String, dynamic> j) async {
    int n(String k) => j[k] is List ? (j[k] as List).length : 0;
    final st = j['start'] is int ? dt(DateTime.fromMillisecondsSinceEpoch(j['start'] as int)) : '-';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Restore karna hai?'),
              content: Text(
                  'Is backup me:\n\u2022 ${n('manual')} manual transactions\n\u2022 ${n('macc')} jode hue accounts\n\u2022 ${n('rec')} bills, ${n('loans')} EMI, ${n('goals')} goals\n\u2022 Tracking start: $st\n\nYe maujooda data ko replace karega. Pehle apne aap ek snapshot ban jayega (Settings \u2192 Auto snapshots se wapas la sakte ho).'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, restore karo'))
              ],
            ));
    return ok == true;
  }

  String themeLabel() => themeN.value == ThemeMode.light ? 'Light' : themeN.value == ThemeMode.system ? 'System ke hisaab se' : 'Dark';

  Future<void> pickTheme() async {
    final v = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Theme'), children: [
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'dark'), child: const Text('Dark')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'light'), child: const Text('Light')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'system'), child: const Text('System ke hisaab se')),
            ]));
    if (v == null) return;
    await sp?.setString('theme', v);
    themeN.value = v == 'light' ? ThemeMode.light : v == 'system' ? ThemeMode.system : ThemeMode.dark;
    setState(() {});
    rev.value++;
  }

  Future<void> pickAccent() async {
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
              final t = Theme.of(ctx).colorScheme;
              final custom = accentIdx >= accents.length;
              void pick(int i) {
                accentIdx = i;
                sp?.setInt('accent', i);
                styleN.value++;
                ss(() {});
              }

              Widget sw(String name, Widget face, bool on, VoidCallback f) => GestureDetector(
                  onTap: f,
                  child: SizedBox(
                      width: 62,
                      child: Column(children: [
                        Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? t.onSurface : t.outlineVariant, width: on ? 3 : 1)),
                            child: ClipOval(child: face)),
                        const SizedBox(height: 4),
                        Text(name, style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
                      ])));
              return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('App ka rang'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Wrap(spacing: 8, runSpacing: 12, children: [
                      for (var i = 0; i < accents.length; i++)
                        sw(accents[i].n, ColoredBox(color: accents[i].dk, child: accentIdx == i ? Icon(Icons.check, color: accents[i].lt, size: 22) : null), accentIdx == i, () => pick(i)),
                      sw(
                          'Custom',
                          DecoratedBox(
                              decoration: const BoxDecoration(
                                  gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Color(0xFFFF00FF), Colors.red])),
                              child: custom ? const Icon(Icons.check, color: Colors.white, size: 22) : const Icon(Icons.colorize, color: Colors.white, size: 20)),
                          custom,
                          () => pick(accents.length)),
                    ]),
                    if (custom) ...[
                      const SizedBox(height: 16),
                      Text('Apna rang chuno', style: TextStyle(color: t.onSurfaceVariant, fontSize: 12)),
                      Slider(
                          value: accentHue,
                          min: 0,
                          max: 360,
                          onChanged: (x) {
                            accentHue = x;
                            styleN.value++;
                            ss(() {});
                          },
                          onChangeEnd: (x) => sp?.setDouble('hue', x)),
                    ],
                  ])),
                  actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))]);
            }));
    setState(() {});
    rev.value++;
  }

  Future<void> pickLockDelay() async {
    final v = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Auto-lock kab ho?'), children: [
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Turant (app chhodte hi)')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 60), child: const Text('1 minute baad')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 300), child: const Text('5 minute baad')),
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 900), child: const Text('15 minute baad')),
            ]));
    if (v == null) return;
    lockDelay = v;
    await sp?.setInt('lockdelay', v);
    setState(() {});
    rev.value++;
  }

  String lockDelayLabel() => lockDelay == 0 ? 'Turant (app chhodte hi)' : '${lockDelay ~/ 60} minute baad';

  Future<void> restore(String txt) async {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(txt) as Map<String, dynamic>;
      if (j['v'] != 1) throw 'bad';
    } catch (_) {
      snack('Backup text sahi nahi hai');
      return;
    }
    if (!await confirmRestore(j)) return;
    await takeSnapshot('pre-restore');
    try {
      List<Map<String, dynamic>> lm(String k) => (j[k] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        budget = (j['budget'] as num).toDouble();
        manual = (j['manual'] as List).map((e) => Tx.fromJson(Map<String, dynamic>.from(e))).toList();
        names = Map<String, String>.from(j['names']);
        alias = Map<String, String>.from(j['alias']);
        hidden = (j['hidden'] as List).map((e) => '$e').toSet();
        dupOk = (j['dupok'] as List).map((e) => '$e').toSet();
        meta = (j['meta'] as Map).map<String, Map<String, String>>((k, v) => MapEntry(k.toString(), Map<String, String>.from(v as Map)));
        cb = (j['cb'] as Map).map<String, double>((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
        rec = lm('rec');
        loans = lm('loans');
        goals = lm('goals');
        accLbl = j['acclbl'] == null ? {} : Map<String, String>.from(j['acclbl']);
        accHide = j['achide'] == null ? {} : (j['achide'] as List).map((e) => '$e').toSet();
        macc = j['macc'] == null ? [] : (j['macc'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        notes = j['notes'] == null ? {} : Map<String, String>.from(j['notes']);
        cashOpen = (j['cashopen'] as num?)?.toDouble() ?? 0.0;
        if (j['start'] is int) startD = DateTime.fromMillisecondsSinceEpoch(j['start'] as int);
      });
      sp?.setString('notes', jsonEncode(notes));
      sp?.setDouble('cashopen', cashOpen);
      sp?.setInt('start', startD.millisecondsSinceEpoch);
      sp?.setString('acclbl', jsonEncode(accLbl));
      sp?.setStringList('achide', accHide.toList());
      sp?.setString('macc', jsonEncode(macc));
      sp?.setDouble('budget', budget);
      sp?.setStringList('hidden', hidden.toList());
      sp?.setStringList('dupok', dupOk.toList());
      sp?.setString('meta', jsonEncode(meta));
      sp?.setString('cb', jsonEncode(cb));
      saveManual();
      saveNames();
      saveLists();
      final ea = j['eAddr'], ep = j['ePass'];
      if (ea is String && ep is String && ea.isNotEmpty && ep.isNotEmpty) {
        sp?.setString('eAddr', ea);
        sp?.setString('ePass', ep);
        setState(() {});
      }
      await load();
      syncEmail();
      snack('Restore ho gaya');
    } catch (_) {
      snack('Backup text sahi nahi hai');
    }
  }

  void restoreDialog() {
    final c = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Restore backup'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Dhyan: maujooda manual data, naam, budget, goals sab replace ho jayenge.', style: sub),
                TextField(controller: c, maxLines: 5, decoration: const InputDecoration(hintText: 'Backup text yahan paste karo')),
                TextButton.icon(
                    onPressed: () async {
                      final d = await Clipboard.getData('text/plain');
                      c.text = d?.text ?? '';
                    },
                    icon: const Icon(Icons.paste),
                    label: const Text('Clipboard se paste')),
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      restore(c.text.trim());
                    },
                    child: const Text('Restore'))
              ],
            ));
  }

  Future<void> exportCsv([List<Tx>? only]) async {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final l = (only ?? all).toList()..sort((a, b) => b.d.compareTo(a.d));
    final b = StringBuffer('Date,Time,Type,Category,Name,Amount,Direction,Bank,Account,Method,Reference,Note,AccountName\n');
    for (final t in l) {
      b.writeln([
        '${t.d.year}-${two(t.d.month)}-${two(t.d.day)}', tm(t.d), t.kind, t.cat, q(nm(t)), t.amt.toStringAsFixed(2),
        t.debit ? 'Debit' : 'Credit', q(t.bank), t.acc, t.method, t.ref, q(notes[t.id] ?? ''), q(accLbl[mapKey(t)] ?? '')
      ].join(','));
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    snack('${l.length} transactions ka CSV copy ho gaya. Google Sheets/Excel me paste karo');
  }

  Future<void> copySummary(String title, List<Tx> l) async {
    final ct = <String, double>{};
    for (final t in l.where((t) => t.debit && t.kind != 'transfer')) {
      ct[t.cat] = (ct[t.cat] ?? 0) + t.amt;
    }
    final ck = ct.keys.toList()..sort((a, b) => ct[b]!.compareTo(ct[a]!));
    final tot = ct.values.fold<double>(0, (a, v) => a + v);
    final b = StringBuffer('Mera Kharcha \u2022 $title\n');
    b.writeln('Income: ${money(got(l))}');
    b.writeln('Expense: ${money(spent(l))}');
    b.writeln('Net: ${sm(got(l) - spent(l))}');
    b.writeln('Transactions: ${l.length}');
    if (ck.isNotEmpty) b.writeln('\nTop categories:');
    for (final c in ck.take(6)) {
      b.writeln('$c: ${money(ct[c]!)} (${(ct[c]! * 100 / tot).round()}%)');
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    snack('Summary copy ho gaya. WhatsApp/Notes me paste karo');
  }

  List<Widget> settingsBody() => [
        gap8(card(SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide balances'),
            subtitle: Text('Home par balance aur accounts chhupao', style: sub),
            value: hideBal,
            onChanged: (v) {
              hideBal = v;
              sp?.setBool('hide', v);
              setState(() {});
              rev.value++;
            }))),
        moreTile(Icons.tune, 'Home ke sections', '${_secNames.length - hsec.where(_secNames.containsKey).length}/${_secNames.length} on \u2022 Accounts card on/off yahan se', pickSections),
        moreTile(Icons.event_repeat, 'Mahine ki start date', cycleDay == 1 ? 'Har mahine ki 1 tarikh se (default)' : 'Har mahine ki $cycleDay tarikh se \u2022 ${cycLabel()}', pickCycleDay),
        moreTile(Icons.notifications_active_outlined, 'Budget alert %', 'Budget ka $alertPct% use hone par warning', pickAlertPct),
        moreTile(Icons.rule, 'Custom category rules', crules.isEmpty ? 'Koi rule nahi \u2022 keyword se category set karo' : '${crules.length} rules', openRules),
        moreTile(Icons.person_outline, sp?.getString('pName') ?? 'Profile', '+91 ${sp?.getString('pPhone') ?? ''} \u2022 ${sp?.getString('eAddr') ?? 'Gmail nahi juda'}', () {}),
        moreTile(Icons.logout, 'Logout', 'Profile aur Gmail hatao (transactions phone me rahenge)', confirmLogout),
        if (pin == null)
          moreTile(Icons.lock_outline, 'App Lock (PIN)', 'Off \u2022 PIN lagao', setPin)
        else ...[
          moreTile(Icons.lock, 'PIN badlo', 'App Lock on hai', changePin),
          moreTile(Icons.lock_open, 'PIN hatao', 'App Lock band karo', removePin),
          moreTile(Icons.timer_outlined, 'Auto-lock', lockDelayLabel(), pickLockDelay),
        ],
        moreTile(Icons.event_available_outlined, 'Tracking start date', '${dt(startD)} se pehle ki entries nahi dikhengi', pickStart),
        if (sp?.getString('eAddr') == null)
          moreTile(Icons.email_outlined, 'Email tracking (Gmail)', 'Off \u2022 Gmail jodo', setupEmail)
        else ...[
          moreTile(Icons.sync, 'Email sync abhi', '${sp?.getString('eAddr')} \u2022 ${emLine()}', () => syncEmail()),
          moreTile(Icons.email, 'Email hatao', 'Email tracking band karo', confirmRemoveEmail),
        ],
        if (accHide.isNotEmpty)
          moreTile(Icons.visibility_outlined, 'Chhupaye hue accounts', '${accHide.length} accounts \u2022 tap karke sab wapas lao', () {
            setState(() => accHide.clear());
            sp?.setStringList('achide', <String>[]);
            rev.value++;
            snack('Sab accounts wapas aa gaye');
          }),
        moreTile(Icons.palette_outlined, 'Theme', themeLabel(), pickTheme),
        moreTile(Icons.color_lens_outlined, 'App ka rang', '${accentName()} \u2022 11 rang + custom', pickAccent),
        gap8(card(SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pure black (AMOLED)'),
            subtitle: Text('Dark theme me asli kala background. Battery bachti hai', style: sub),
            value: amoled,
            onChanged: (v) {
              amoled = v;
              sp?.setBool('amoled', v);
              styleN.value++;
              setState(() {});
              rev.value++;
            }))),
        moreTile(Icons.history, 'Auto snapshots', '${snapList().length} saved \u2022 har 24 ghante apne aap', openSnaps),
        if (sp?.getString('eAddr') != null) ...[
          moreTile(Icons.forward_to_inbox, 'Backup Gmail par bhejo', ebSub(), () => emailBackup()),
          moreTile(Icons.cloud_download_outlined, 'Gmail se restore', 'Gmail me bheje backup se data wapas lao', emailRestore),
          moreTile(Icons.schedule_send_outlined, 'Auto email backup', ebModeLabel(), pickEbMode),
        ],
        moreTile(Icons.backup_outlined, 'Backup', 'Poora data copy hoga, Notes/WhatsApp me save karo', backup),
        moreTile(Icons.restore, 'Restore', 'Backup text paste karke wapas lao', restoreDialog),
        moreTile(Icons.table_chart_outlined, 'Export CSV', 'Sheets/Excel me paste karne ke liye', exportCsv),
        moreTile(Icons.info_outline, 'About', 'Mera Kharcha \u2022 Phase 11 Theme \u2022 data sirf is phone me rehta hai', () {}),
      ];

  int trd = 0;
  List<Tx> mails = [];
  DateTime startD = DateTime(2000);
  bool emBusy = false;
  String emStatus = '';

  bool near(Tx a, Tx b) =>
      a.amt == b.amt &&
      a.debit == b.debit &&
      a.d.difference(b.d).inMinutes.abs() <= 15 &&
      (a.acc == b.acc || a.acc == 'Unknown' || b.acc == 'Unknown');

  Tx asEmail(Tx x) => Tx(x.id.startsWith('r') ? x.id : 'e${x.id}', x.d, x.amt, x.debit, x.acc, x.bank, x.method, x.party, x.ref,
      kind: x.kind, cat: x.cat, bal: x.bal, src: 'email');

  Future<void> pickStart() async {
    final p = await showDatePicker(context: context, initialDate: startD, firstDate: DateTime(2015), lastDate: DateTime.now());
    if (p == null) return;
    setState(() => startD = DateTime(p.year, p.month, p.day));
    sp?.setInt('start', startD.millisecondsSinceEpoch);
    rev.value++;
    snack('Ab ${dt(startD)} se pehle ki entries nahi dikhengi');
  }

  Future<void> pickSections() async {
    final sel = {...hsec};
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Home par kya dikhe?'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final e in _secNames.entries)
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.value),
                          value: !sel.contains(e.key),
                          onChanged: (v) => ss(() => v ? sel.remove(e.key) : sel.add(e.key))),
                  ]),
                  actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
                )));
    setState(() => hsec = sel);
    await sp?.setStringList('hsec', hsec.toList());
    rev.value++;
  }

  Future<void> pickCycleDay() async {
    var v = cycleDay.toDouble();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Mahina kis tarikh se shuru?'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(v.round() == 1 ? '1 tarikh (normal mahina)' : 'Har mahine ki ${v.round()} tarikh se'),
                    Slider(value: v, min: 1, max: 28, divisions: 27, label: '${v.round()}', onChanged: (x) => ss(() => v = x)),
                    Text('Salary 1 ko nahi aati to uski tarikh chuno. Budget, Home ka hisaab aur alerts isi cycle se chalenge. Max 28.',
                        style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))
                  ],
                )));
    if (ok != true) return;
    setState(() => cycleDay = v.round());
    await sp?.setInt('cycday', cycleDay);
    rev.value++;
  }

  Future<void> pickAlertPct() async {
    var v = alertPct.toDouble();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Budget alert %'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${v.round()}% use hone par warning'),
                    Slider(value: v, min: 50, max: 95, divisions: 9, label: '${v.round()}%', onChanged: (x) => ss(() => v = x)),
                    Text('Monthly aur category budget dono par lagega. 100% par "cross ho gaya" alert hamesha aayega.',
                        style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))
                  ],
                )));
    if (ok != true) return;
    setState(() => alertPct = v.round());
    await sp?.setInt('alertpct', alertPct);
    rev.value++;
  }

  void reapplyRules() {
    for (final t in [...sms, ...mails]) {
      applyMeta(t);
    }
    rev.value++;
  }

  Future<void> saveRules() async {
    await sp?.setString('crules', jsonEncode(crules));
    reapplyRules();
    if (mounted) setState(() {});
  }

  Future<void> addRule() async {
    final kc = TextEditingController();
    String cat = expCats.first;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Naya rule'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: kc, decoration: const InputDecoration(labelText: 'Keyword (naam me ye ho)', hintText: 'jaise: chai, gym, rent')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: cat,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [for (final c in [...expCats, ...incCats].toSet()) DropdownMenuItem(value: c, child: Text(c))],
                        onChanged: (v) => ss(() => cat = v ?? cat)),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))
                  ],
                )));
    final k = kc.text.trim().toLowerCase();
    if (ok != true || k.length < 2) return;
    crules[k] = cat;
    await saveRules();
    snack('Rule save ho gaya');
  }

  List<Widget> rulesBody() => [
        if (crules.isEmpty) emptyNote('Koi rule nahi.\n+ Add dabao. Jaise "chai" \u2192 Food. Jis transaction ke naam me ye keyword ho, wo us category me jayega.'),
        for (final e in crules.entries)
          gap8(card(Row(children: [
            const Icon(Icons.rule),
            const SizedBox(width: 12),
            Expanded(child: Text('"${e.key}"  \u2192  ${e.value}', style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  crules.remove(e.key);
                  await saveRules();
                }),
          ]))),
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Agar kisi transaction ki category aapne haath se badli hai, to wahi rahegi (rule usse nahi badlega).', style: sub)),
      ];

  void openRules() => openPage('Custom category rules', rulesBody, addRule);

  Future<void> confirmLogout() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Logout?'),
              content: const Text('Profile aur Gmail App Password hat jayega. Phone me saved transactions, budget aur backup nahi hatenge. Dobara login karna padega.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, logout'))
              ],
            ));
    if (ok != true) return;
    for (final k in ['pName', 'pPhone', 'eAddr', 'ePass', 'emLast']) {
      await sp?.remove(k);
    }
    authN.value++;
  }

  Future<void> setupEmail() async {
    final r = await ask('Gmail se jodo', [['a', 'Gmail address', 't'], ['b', 'App Password (16 letter)', 'w']]);
    if (r == null || !(r['a'] ?? '').contains('@') || (r['b'] ?? '').isEmpty) return;
    sp?.setString('eAddr', r['a']!.trim());
    sp?.setString('ePass', r['b']!.replaceAll(' ', ''));
    setState(() {});
    rev.value++;
    await syncEmail();
  }

  void removeEmail() {
    sp?.remove('eAddr');
    sp?.remove('ePass');
    setState(() {
      mails = [];
      emStatus = '';
    });
    rev.value++;
    snack('Email tracking band ho gaya');
  }

  String emLine() {
    if (emStatus.isNotEmpty) return emStatus;
    final l = sp?.getInt('emLast');
    if (l == null) return 'Abhi tak sync nahi hua';
    final d = DateTime.fromMillisecondsSinceEpoch(l);
    return 'Last sync ${dt(d)} ${tm(d)}';
  }

  Future<void> confirmRemoveEmail() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Gmail hatao?'),
              content: const Text('Email tracking band ho jayegi aur saved App Password hat jayega. Dobara jodne ke liye naya 16-letter App Password chahiye hoga.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, hatao'))
              ],
            ));
    if (ok == true) removeEmail();
  }

  Future<void> syncEmail({bool quiet = false}) async {
    final addr = sp?.getString('eAddr'), pass = sp?.getString('ePass');
    if (addr == null || pass == null || emBusy) return;
    emBusy = true;
    if (mounted) setState(() => emStatus = 'Sync ho raha hai...');
    rev.value++;
    final client = mail.ImapClient(isLogEnabled: false);
    try {
      const to = Duration(seconds: 45);
      await client.connectToServer('imap.gmail.com', 993, isSecure: true).timeout(to);
      await client.login(addr, pass).timeout(to);
      await client.selectInbox().timeout(to);
      final r = await client.fetchRecentMessages(messageCount: 150, criteria: 'BODY.PEEK[]').timeout(const Duration(seconds: 120));
      final styleRe = RegExp(r'<(style|script)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false);
      final tagRe = RegExp(r'<[^>]*>');
      final spaceRe = RegExp(r'\s+');
      final otpRe = RegExp(r'[^.]*\b(?:otp|request)\b[^.]*\.', caseSensitive: false);
      final out = <Tx>[];
      final ids = <String>{};
      for (final m in r.messages) {
        final d = m.decodeDate() ?? DateTime.now();
        if (d.isBefore(startD)) continue;
        var text = m.decodeTextPlainPart() ?? '';
        if (text.trim().isEmpty) {
          text = (m.decodeTextHtmlPart() ?? '')
              .replaceAll(styleRe, ' ')
              .replaceAll(tagRe, ' ')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&');
        }
        text = '${m.decodeSubject() ?? ''}. $text'.replaceAll(spaceRe, ' ');
        text = text.replaceAll(otpRe, ' ');
        final from = (m.from != null && m.from!.isNotEmpty) ? m.from!.first.email : '';
        final x = parse(text, d.millisecondsSinceEpoch, from);
        if (x == null) continue;
        final e = asEmail(x);
        if (seen.contains(e.id) || sms.any((s) => near(s, e)) || !ids.add(e.id)) continue;
        applyMeta(e);
        out.add(e);
      }
      sp?.setInt('emLast', DateTime.now().millisecondsSinceEpoch);
      if (mounted) {
        final n = DateTime.now();
        setState(() {
          mails = out;
          emStatus = '${out.length} email transactions \u2022 sync ${tm(n)}';
        });
      }
    } catch (e) {
      // Password / login KABHI automatically nahi hatayenge, sirf message dikhayenge
      final m = '$e'.toLowerCase();
      final auth = m.contains('auth') || m.contains('credential') || m.contains('login') || m.contains('password');
      final msg = auth
          ? 'Gmail login nahi hua. App Password check karo (aapka password save hai, hataya nahi gaya)'
          : 'Gmail se connect nahi ho paya (internet?). Baad me dobara try hoga';
      if (mounted) {
        setState(() => emStatus = msg);
        if (!quiet) snack(msg);
      }
    } finally {
      try {
        await client.logout();
      } catch (_) {}
      emBusy = false;
      rev.value++;
    }
  }

  List<Widget> trackBody() {
    final now = DateTime.now();
    final from = trd == 0 ? startD : DateTime(now.year, now.month, now.day).subtract(Duration(days: trd - 1));
    final l = all.where((t) => !t.d.isBefore(from)).toList()..sort((a, b) => b.d.compareTo(a.d));
    String srcOf(Tx t) => t.manual ? 'Manual' : t.src == 'email' ? 'Email' : 'SMS';
    final bySrc = <String, List<Tx>>{};
    final bank = <String, double>{}, cat = <String, double>{};
    for (final t in l) {
      (bySrc[srcOf(t)] ??= []).add(t);
      if (t.debit && t.kind != 'transfer') {
        bank[t.bank] = (bank[t.bank] ?? 0) + t.amt;
        cat[t.cat] = (cat[t.cat] ?? 0) + t.amt;
      }
    }
    final emails = bySrc['Email'] ?? <Tx>[];
    Widget kv(String title, Map<String, double> m) {
      final k = m.keys.toList()..sort((a, b) => m[b]!.compareTo(m[a]!));
      return gap8(card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (k.isEmpty) Text('Koi data nahi', style: sub),
        for (final x in k.take(8))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [Expanded(child: Text(x)), Text(money(m[x]!), style: const TextStyle(fontWeight: FontWeight.bold))])),
      ])));
    }

    final net = got(l) - spent(l);
    return [
      chips(const {'0': 'Since start', '7': '7 Days', '30': '1 Month'}, '$trd', (v) {
        trd = int.parse(v);
        setState(() {});
        rev.value++;
      }),
      const SizedBox(height: 10),
      gap8(card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tracking: ${dt(from)} se aaj tak', style: sub),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: stat('Expense', money(spent(l)), rc)),
          Expanded(child: stat('Income', money(got(l)), gc)),
          Expanded(child: stat('Net', sm(net), cs.onSurface)),
        ]),
        const SizedBox(height: 8),
        Text('${l.length} transactions'),
      ]))),
      gap8(card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Source-wise', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final e in const ['SMS', 'Email', 'Manual'])
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(e)),
                Text('${(bySrc[e] ?? <Tx>[]).length} txns \u2022 Out ${money(spent(bySrc[e] ?? <Tx>[]))} \u2022 In ${money(got(bySrc[e] ?? <Tx>[]))}', style: sub),
              ])),
      ]))),
      kv('Bank-wise kharcha', bank),
      kv('Category-wise kharcha', cat),
      const SizedBox(height: 6),
      const Text('Email se mile transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (sp?.getString('eAddr') == null)
        emptyNote('Email tracking off hai.\nSettings me Gmail jodo.')
      else if (emails.isEmpty)
        emptyNote('Is period me email se koi transaction nahi mila.')
      else
        for (final t in emails.take(40)) txCard(t),
    ];
  }

  List<Tx> get all {
    final k = Object.hash(identityHashCode(sms), sms.length, identityHashCode(mails), mails.length,
        identityHashCode(manual), manual.length, identityHashCode(hidden), hidden.length, startD);
    if (_allC == null || k != _allK) {
      _allK = k;
      _allC = [...sms, ...mails, ...manual].where((t) => !hidden.contains(t.id) && !t.d.isBefore(startD)).toList();
    }
    return _allC!;
  }

  String nm(Tx t) =>
      names[t.id] ?? alias[t.party.toLowerCase()] ?? (t.party == '-' || _badNameRe.hasMatch(t.party) ? 'Unknown recipient' : t.party);

  String dayLabel(DateTime d) {
    final n = DateTime.now();
    final a = DateTime(d.year, d.month, d.day), b = DateTime(n.year, n.month, n.day);
    final diff = b.difference(a).inDays;
    return diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : dt(d);
  }

  List<Tx> filtered() {
    final now = DateTime.now();
    final from = (range == 'c' || range == 'd')
        ? cr?.start
        : range == '15'
            ? now.subtract(const Duration(days: 15))
            : range == '7'
                ? now.subtract(const Duration(days: 7))
                : range == '30'
                    ? now.subtract(const Duration(days: 30))
                    : range == 'm'
                        ? DateTime(now.year, now.month)
                        : null;
    final s = q.trim().toLowerCase();
    final out = all.where((t) {
      if (type == 'exp' && t.kind != 'expense') return false;
      if (type == 'inc' && t.kind != 'income') return false;
      if (type == 'trf' && t.kind != 'transfer') return false;
      if (catF != 'all' && t.cat != catF) return false;
      if (src != 'all' && t.bank != src && t.acc != src) return false;
      if (from != null && t.d.isBefore(from)) return false;
      if ((range == 'c' || range == 'd') && cr != null && !t.d.isBefore(cr!.end.add(const Duration(days: 1)))) return false;
      if (s.isEmpty) return true;
      final hay =
          '${nm(t)} ${t.party} ${t.bank} ${t.acc} ${t.method} ${t.ref} ${t.amt} ${t.amt.round()} ${t.kind} ${t.cat} ${accLbl[keyOf(t)] ?? ''} ${notes[t.id] ?? ''} ${t.debit ? 'debit expense sent' : 'credit income received'}'
              .toLowerCase();
      return hay.contains(s);
    }).toList();
    if (minA != null || maxA != null) {
      out.removeWhere((t) => (minA != null && t.amt < minA!) || (maxA != null && t.amt > maxA!));
    }
    switch (sortBy) {
      case 'old':
        out.sort((a, b) => a.d.compareTo(b.d));
        break;
      case 'hi':
        out.sort((a, b) => b.amt.compareTo(a.amt));
        break;
      case 'lo':
        out.sort((a, b) => a.amt.compareTo(b.amt));
        break;
      default:
        out.sort((a, b) => b.d.compareTo(a.d));
    }
    return out;
  }

  String amtLabel() => minA == null && maxA == null
      ? 'Amount range'
      : '${minA != null ? money(minA!) : '0'} - ${maxA != null ? money(maxA!) : 'max'}';

  Future<void> pickAmount() async {
    final v = await ask('Amount range', [
      ['a', 'Minimum amount', 'n'],
      ['b', 'Maximum amount', 'n']
    ], {
      'a': minA == null ? '' : fs(minA),
      'b': maxA == null ? '' : fs(maxA)
    });
    if (v == null) return;
    setState(() {
      minA = double.tryParse(v['a'] ?? '');
      maxA = double.tryParse(v['b'] ?? '');
    });
  }

  final rev = ValueNotifier<int>(0);
  static const gc = mint, rc = salmon;
  ColorScheme get cs => Theme.of(context).colorScheme;
  TextStyle get sub => TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

  Widget card(Widget child, {VoidCallback? onTap, EdgeInsets pad = const EdgeInsets.all(16)}) => Material(
      color: cs.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(onTap: onTap, child: Padding(padding: pad, child: child)));

  String initials(String s) {
    final w = s.split(RegExp(r'[\s/_.\-@]+')).where((x) => RegExp(r'[A-Za-z0-9]').hasMatch(x)).toList();
    if (w.isEmpty) return '?';
    if (w.length == 1) return (w.first.length >= 2 ? w.first.substring(0, 2) : w.first).toUpperCase();
    return (w[0][0] + w[1][0]).toUpperCase();
  }

  Widget avatar(String text, {Color? bg, Color? fg, double size = 46}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg ?? cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.33, color: fg ?? cs.primary)));

  Color txTint(String cat) {
    switch (cat) {
      case 'Food':
        return const Color(0xFFFFB36B);
      case 'Grocery':
        return mint;
      case 'Travel':
        return const Color(0xFF7CB8FF);
      case 'Shopping':
        return const Color(0xFFFF9BC2);
      case 'Bills':
        return const Color(0xFFFFD36B);
      case 'EMI':
        return const Color(0xFFB79CFF);
      case 'Medical':
        return const Color(0xFFFF8A7A);
      case 'Salary':
      case 'Other income':
        return const Color(0xFF6ED3C0);
      case 'Cashback':
        return const Color(0xFF6FE0F2);
      case 'Refund':
        return const Color(0xFFB5E67A);
      case 'Transfer':
        return const Color(0xFF9FB3C8);
      default:
        return const Color(0xFFA9B4C2);
    }
  }

  String accCode(Map<String, dynamic> r) {
    const codes = {
      'Kotak Bank': 'KB', 'HDFC Bank': 'HD', 'SBI': 'SB', 'ICICI Bank': 'IC', 'Axis Bank': 'AX', 'PNB': 'PN',
      'Bank of Baroda': 'BB', 'Canara Bank': 'CB', 'Yes Bank': 'YB', 'IDFC First': 'IF', 'Union Bank': 'UB',
      'IndusInd': 'IN', 'Paytm Bank': 'PY', 'Federal Bank': 'FB', 'India Post Payments Bank': 'IP', 'Bank of India': 'BI',
      'Indian Bank': 'IB', 'IDBI Bank': 'ID', 'RBL Bank': 'RB', 'Central Bank': 'CN', 'AU Small Finance': 'AU',
      'Airtel Payments Bank': 'AP'
    };
    return codes['${r['bank']}'] ?? initials(accName(r));
  }

  String tileCode(String t) {
    const m = {
      'Accounts manage karo': 'AC', 'Bills aur Reminders': 'BR', 'Recurring Payments': 'RP', 'EMI / Loans': 'EM',
      'Savings Goals': 'SG', 'Tracking Report': 'TR', 'Settings': 'ST'
    };
    return m[t] ?? initials(t);
  }

  Widget head(String t, {String? sub}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 0, 16),
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))),
        ])),
        InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: refreshing ? null : refresh,
            child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
                child: Center(
                    child: refreshing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 22)))),
      ]));

  Widget stat(String label, String value, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: sub),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: c)),
      ]);

  Widget chips(Map<String, String> o, String cur, void Function(String) on) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final e in o.entries)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                  label: Text(e.value,
                      style: TextStyle(
                          fontWeight: cur == e.key ? FontWeight.w800 : FontWeight.w500,
                          color: cur == e.key ? cs.onPrimary : cs.onSurface)),
                  selected: cur == e.key,
                  showCheckmark: false,
                  selectedColor: cs.primary,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: cur == e.key ? cs.primary : cs.outline),
                  shape: const StadiumBorder(),
                  onSelected: (_) => on(e.key)))
      ]));

  Widget navBar() {
    const items = ['Home', 'Transactions', 'Reports', 'Budget', 'More'];
    return SafeArea(
        top: false,
        child: Container(
            decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant))),
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: SizedBox(
                height: 48,
                child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                    flex: i == 1 ? 14 : 10,
                    child: Center(
                        child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => setState(() => tab = i),
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(color: tab == i ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(items[i],
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: tab == i ? FontWeight.w800 : FontWeight.w500,
                                            color: tab == i ? cs.onPrimary : cs.onSurfaceVariant)))))))
            ]))));
  }

  Widget smsGuide() => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        const Icon(Icons.sms_failed_outlined, size: 56),
        const SizedBox(height: 16),
        const Text('SMS access chahiye', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Android ne is app ko "restricted" maana hai kyunki ye Play Store se install nahi hui. Ye sirf ek baar ka kaam hai:',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        card(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('1. Phone Settings \u2192 Apps \u2192 is app (expense_tracker) par jao'),
          SizedBox(height: 8),
          Text('2. Upar right me \u22EE (teen dot) dabao'),
          SizedBox(height: 8),
          Text('3. "Allow restricted settings" dabao, PIN/fingerprint do'),
          SizedBox(height: 8),
          Text('4. Permissions \u2192 SMS \u2192 Allow'),
          SizedBox(height: 8),
          Text('5. Wapas yahan aao aur neeche wala button dabao'),
        ])),
        const SizedBox(height: 8),
        Text('Agar \u22EE me ye option na dikhe, to pehle ek baar app ko SMS permission maangne do (neeche wala button), phir \u22EE dobara dekho.', style: sub),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: () => load(force: true),
            icon: const Icon(Icons.check),
            label: const Text('Maine allow kar diya, check karo')),
        const SizedBox(height: 8),
        TextButton(
            onPressed: () => setState(() {
                  skipSms = true;
                  needSms = false;
                }),
            child: const Text('Abhi bina SMS ke chalao')),
      ]);

  @override
  Widget build(BuildContext context) {
    Widget page() {
      switch (tab) {
        case 1:
          return txPage();
        case 2:
          return reportPage();
        case 3:
          return budgetPage();
        case 4:
          return morePage();
        default:
          return home();
      }
    }

    return Scaffold(
      body: SafeArea(
          child: needSms
              ? smsGuide()
              : status.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(status, textAlign: TextAlign.center)))
              : page()),
      floatingActionButton: tab <= 1
          ? FloatingActionButton.extended(onPressed: addManual, icon: const Icon(Icons.add), label: const Text('Add'))
          : null,
      bottomNavigationBar: navBar(),
    );
  }

  Widget budgetCard(double sp) {
    final p = budget <= 0 ? 0.0 : sp / budget;
    final over = sp > budget;
    final col = over ? rc : gc;
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Monthly Budget', style: TextStyle(color: cs.onSurfaceVariant))),
        Text('${(p * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w800, color: col)),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit, size: 18), onPressed: editBudget),
      ]),
      Text.rich(TextSpan(children: [
        TextSpan(text: money(sp), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        TextSpan(text: ' / ${money(budget)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ])),
      const SizedBox(height: 12),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: p.clamp(0.0, 1.0).toDouble(), minHeight: 12, color: col, backgroundColor: cs.surfaceContainerHighest)),
      const SizedBox(height: 10),
      Text(over ? 'Budget cross ho gaya!' : '${money(budget - sp)} bacha hai', style: TextStyle(color: over ? rc : cs.onSurfaceVariant)),
    ]));
  }

  Widget swipeBg(Color col, IconData ic, String label, Alignment al) => Container(
      color: col,
      alignment: al,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]));

  // Transfer ke do legs hote hain (a = from, b = to). Dono saath hatenge.
  List<Tx> legsOf(Tx t) {
    if (!t.manual || t.id.length < 2 || !(t.id.endsWith('a') || t.id.endsWith('b'))) return [t];
    final base = t.id.substring(0, t.id.length - 1);
    final l = manual
        .where((x) => x.id.length == t.id.length && x.id.startsWith(base) && (x.id.endsWith('a') || x.id.endsWith('b')))
        .toList();
    return l.isEmpty ? [t] : l;
  }

  void removeTx(Tx t) {
    final man = t.manual;
    final legs = man ? legsOf(t) : <Tx>[];
    setState(() {
      if (man) {
        manual.removeWhere((x) => legs.any((l) => l.id == x.id));
      } else {
        hidden.add(t.id);
      }
    });
    if (man) {
      saveManual();
    } else {
      sp?.setStringList('hidden', hidden.toList());
    }
    rev.value++;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(man ? 'Transaction delete ho gaya' : 'Transaction ignore ho gaya'),
          action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                setState(() {
                  if (man) {
                    manual.addAll(legs);
                  } else {
                    hidden.remove(t.id);
                  }
                });
                if (man) {
                  saveManual();
                } else {
                  sp?.setStringList('hidden', hidden.toList());
                }
                rev.value++;
              })));
  }

  Widget txCard(Tx t, {bool showDate = true}) {
    final isTr = t.kind == 'transfer';
    final c = isTr ? Colors.blueGrey : t.debit ? rc : gc;
    final cat = isTr ? 'Transfer' : t.cat;
    final info = '${showDate ? '${dt(t.d)} \u2022 ' : ''}$cat \u2022 ${t.bank} \u2022 ${tm(t.d)}';
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Dismissible(
                key: ObjectKey(t),
                background: swipeBg(Colors.indigo, Icons.edit, 'Rename', Alignment.centerLeft),
                secondaryBackground:
                    swipeBg(t.manual ? Colors.red : Colors.deepOrange, t.manual ? Icons.delete : Icons.visibility_off, t.manual ? 'Delete' : 'Ignore', Alignment.centerRight),
                confirmDismiss: (dir) async {
                  if (dir == DismissDirection.startToEnd) {
                    rename(t);
                  } else {
                    removeTx(t);
                  }
                  return false;
                },
                child: card(
                    onTap: () => detail(t),
                    Row(children: [
                      avatar(initials(nm(t)), bg: txTint(cat), fg: const Color(0xFF0B0F14)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nm(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        if (notes[t.id] != null && notes[t.id]!.isNotEmpty)
                          Text(notes[t.id]!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sub.copyWith(fontStyle: FontStyle.italic)),
                        const SizedBox(height: 3),
                        Text(info, maxLines: 1, overflow: TextOverflow.ellipsis, style: sub),
                        if (isDup(t)) const Text('\u26A0 Possible duplicate', style: TextStyle(fontSize: 12, color: Colors.amber)),
                      ])),
                      const SizedBox(width: 8),
                      Text('${t.debit ? '-' : '+'}${money(t.amt)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c)),
                    ])))));
  }

  Widget dayHdr(_Day d) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(children: [
        Expanded(child: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        if (d.out > 0) Text('-${money(d.out)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rc)),
        if (d.out > 0 && d.inn > 0) const SizedBox(width: 10),
        if (d.inn > 0) Text('+${money(d.inn)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gc)),
      ]));

  List<Object> dayItems(List<Tx> g) {
    final out = <Object>[];
    var i = 0;
    while (i < g.length) {
      final k = dayLabel(g[i].d);
      final grp = <Tx>[];
      var j = i;
      while (j < g.length && dayLabel(g[j].d) == k) {
        grp.add(g[j]);
        j++;
      }
      out.add(_Day(k, spent(grp), got(grp)));
      out.addAll(grp);
      i = j;
    }
    return out;
  }

  Widget peopleCard(List<Tx> l) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: card(
          onTap: () => personPage(l),
          Row(children: [
            avatar(initials(nm(l.first))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nm(l.first), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${l.length} transactions', style: sub),
              Text('Last: ${dt(l.first.d)}', style: sub),
            ])),
            const SizedBox(width: 8),
            Text(spent(l) > 0 ? 'Sent ${money(spent(l))}' : 'Received ${money(got(l))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ])));

  Widget home() {
    final n = DateTime.now();
    final m = all.where((t) => inCyc(t.d)).toList();
    final bal = got(m) - spent(m);
    final ma = mainAccs();
    final tb = totalBal(ma);
    final rec = all.toList()..sort((a, b) => b.d.compareTo(a.d));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
      head('Mera Kharcha', sub: '${n.day} ${mon[n.month - 1]} ${n.year}'),
      if (smsBlocked)
        Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: card(
                onTap: () => setState(() => needSms = true),
                Row(children: [
                  const Icon(Icons.sms_failed_outlined, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(child: Text('SMS access band hai, naye SMS nahi aayenge. Tap karke allow karne ka tareeka dekho', style: sub)),
                  const Icon(Icons.chevron_right),
                ]))),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary.withOpacity(0.22))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Total balance', style: TextStyle(color: cs.onPrimaryContainer))),
            IconButton(
                visualDensity: VisualDensity.compact,
                color: cs.onPrimaryContainer,
                icon: Icon(hideBal ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () {
                  setState(() => hideBal = !hideBal);
                  sp?.setBool('hide', hideBal);
                  rev.value++;
                }),
          ]),
          Text(mask(tb), style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: cs.onPrimaryContainer)),
          Text('${ma.length} accounts + cash', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.7))),
          const SizedBox(height: 12),
          Divider(color: cs.onPrimaryContainer.withOpacity(0.2)),
          const SizedBox(height: 4),
          Text(cycleDay == 1 ? '${mon[n.month - 1]} ka hisaab' : '${cycLabel()} ka hisaab', style: TextStyle(color: cs.onPrimaryContainer)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: stat('Income', money(got(m)), gc)),
            Expanded(child: stat('Expense', money(spent(m)), rc)),
            Expanded(child: stat('Net', hideBal ? '\u2022\u2022\u2022\u2022' : sm(bal), bal < 0 ? rc : gc)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      if (secOn('alerts')) alertsCard(),
      if (secOn('acc')) ...[accountsCard(), const SizedBox(height: 14)],
      if (secOn('budget')) ...[budgetCard(spent(m)), const SizedBox(height: 14)],
      if (secOn('bills')) upcomingCard(),
      const SizedBox(height: 4),
      if (secOn('recent')) ...[
        Row(children: [
          const Expanded(child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => setState(() => tab = 1), child: const Text('See all')),
        ]),
        if (rec.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Abhi koi transaction nahi'))),
        for (final t in rec.take(6)) txCard(t),
      ],
    ]);
  }

  Future<void> pickRange(String v) async {
    if (v == 'd') {
      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime.now());
      if (d != null) {
        final day = DateTime(d.year, d.month, d.day);
        setState(() {
          cr = DateTimeRange(start: day, end: day);
          range = 'd';
        });
      }
      return;
    }
    if (v == 'c') {
      final now = DateTime.now();
      final r = await showDateRangePicker(context: context, firstDate: DateTime(2015), lastDate: now);
      if (r != null) {
        setState(() {
          cr = r;
          range = 'c';
        });
      }
    } else {
      setState(() => range = v);
    }
  }

  Widget txPage() {
    final f = filtered();
    final srcs = <String>{
      for (final t in all) ...[if (t.bank != 'Unknown') t.bank, if (t.acc != 'Unknown') t.acc]
    };
    final sv = srcs.contains(src) ? src : 'all';
    final net = got(f) - spent(f);
    final items = <Object>[];
    if (mode == 'tx') {
      if (sortBy == 'hi' || sortBy == 'lo') {
        items.addAll(f);
      } else {
        items.addAll(dayItems(f));
      }
    } else {
      final g = <String, List<Tx>>{};
      for (final t in f) {
        (g[nm(t).toLowerCase()] ??= []).add(t);
      }
      final keys = g.keys.toList()
        ..sort((a, b) => (spent(g[b]!) + got(g[b]!)).compareTo(spent(g[a]!) + got(g[a]!)));
      for (final k in keys) {
        items.add(g[k]!);
      }
    }
    if (items.isEmpty) items.add('Koi transaction nahi mila');
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      head('Transactions', sub: '${f.length} txns'),
      TextField(
        controller: qc,
        onChanged: (v) {
          _deb?.cancel();
          _deb = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => q = v);
          });
        },
        decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceContainer,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Name, bank, account, amount or UPI',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: cs.outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: cs.outlineVariant)),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _deb?.cancel();
                      qc.clear();
                      setState(() => q = '');
                    })),
      ),
      const SizedBox(height: 10),
      chips(const {'all': 'All', 'exp': 'Expense', 'inc': 'Income', 'trf': 'Transfer'}, type, (v) => setState(() => type = v)),
      const SizedBox(height: 4),
      chips({'all': 'All Categories', for (final c in [...expCats, ...incCats, 'Transfer']) c: c}, catF, (v) => setState(() => catF = v)),
      const SizedBox(height: 4),
      chips({'all': 'All Banks', for (final s in srcs) s: s}, sv, (v) => setState(() => src = v)),
      const SizedBox(height: 4),
      chips({
        'all': 'All Time',
        '7': '7 Days',
        '15': '15 Days',
        '30': '1 Month',
        'd': range == 'd' && cr != null ? dt(cr!.start) : 'Ek din',
        'c': range == 'c' && cr != null ? '${dt(cr!.start)} - ${dt(cr!.end)}' : 'Custom'
      }, range, pickRange),
      const SizedBox(height: 4),
      chips(const {'new': 'Latest', 'old': 'Oldest', 'hi': 'Highest amount', 'lo': 'Lowest amount'}, sortBy, (v) => setState(() => sortBy = v)),
      const SizedBox(height: 4),
      chips({'amt': amtLabel()}, minA != null || maxA != null ? 'amt' : '', (_) => pickAmount()),
      const SizedBox(height: 12),
      card(Row(children: [
        Expanded(child: stat('Credit', money(got(f)), gc)),
        Expanded(child: stat('Debit', money(spent(f)), rc)),
        Expanded(child: stat('Net', '${net < 0 ? '-' : ''}${money(net.abs())}', cs.onSurface)),
      ])),
      const SizedBox(height: 12),
      Center(
          child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'tx', label: Text('Transactions'), icon: Icon(Icons.receipt_long)),
          ButtonSegment(value: 'ppl', label: Text('People'), icon: Icon(Icons.people))
        ],
        selected: {mode},
        onSelectionChanged: (s) => setState(() => mode = s.first),
      )),
      const SizedBox(height: 8),
    ]);
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return header;
          final it = items[i - 1];
          if (it is String) {
            return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Text(it, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)));
          }
          if (it is _Day) return dayHdr(it);
          if (it is Tx) return txCard(it, showDate: sortBy == 'hi' || sortBy == 'lo');
          return peopleCard(it as List<Tx>);
        });
  }

  void personPage(List<Tx> l) {
    final ids = l.map((e) => e.id).toSet();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<int>(
                valueListenable: rev,
                builder: (ctx, _, __) {
                  final g = all.where((t) => ids.contains(t.id)).toList()..sort((a, b) => b.d.compareTo(a.d));
                  if (g.isEmpty) return const Scaffold();
                  final items = dayItems(g);
                  return Scaffold(
                    appBar: AppBar(
                        title: Text(nm(g.first), overflow: TextOverflow.ellipsis),
                        actions: [
                          TextButton.icon(
                              onPressed: () => rename(g.first, group: true),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Rename'))
                        ]),
                    body: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(spent(g) > 0 ? 'Total sent' : 'Total received', style: sub),
                                  Text(money(spent(g) > 0 ? spent(g) : got(g)),
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${g.length} transactions'
                                      '${spent(g) > 0 && got(g) > 0 ? '  \u2022  Received ${money(got(g))}' : ''}'),
                                ])));
                          }
                          final it = items[i - 1];
                          if (it is String) {
                            return Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 8),
                                child: Text(it, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)));
                          }
                          if (it is _Day) return dayHdr(it);
                          return txCard(it as Tx, showDate: false);
                        }),
                  );
                })));
  }

  Future<void> editNote(Tx t) async {
    final v = await ask('Note / description', [['a', 'Note', 't']], {'a': notes[t.id] ?? ''});
    if (v == null) return;
    final n = (v['a'] ?? '').trim();
    setState(() => n.isEmpty ? notes.remove(t.id) : notes[t.id] = n);
    sp?.setString('notes', jsonEncode(notes));
    rev.value++;
  }

  Future<void> confirmDeleteTx(Tx t) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Transaction hatao?'),
              content: Text(t.manual
                  ? '${money(t.amt)} ka ye transaction delete ho jayega aur account balance dobara calculate hoga.${t.kind == 'transfer' ? ' Transfer ke dono hisse (from aur to) hatenge.' : ''}'
                  : 'Ye SMS/email se aaya transaction hai. Ise ignore (chhupa) kar denge, balance aur reports me nahi judega.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.manual ? 'Delete' : 'Ignore'))
              ],
            ));
    if (ok == true) removeTx(t);
  }

  void detail(Tx t) {
    final key = mapKey(t);
    final accTxt = accLbl[key] ?? key;
    final isTr = t.kind == 'transfer';
    Widget kv(String a, String b, {Color? c}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a, style: sub),
          const SizedBox(width: 16),
          Flexible(child: Text(b, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, color: c))),
        ]));
    final nt = notes[t.id] ?? '';
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isTr ? 'Transfer' : t.debit ? 'Debit' : 'Credit', style: TextStyle(color: isTr ? Colors.blueGrey : t.debit ? rc : gc)),
                  Text(money(t.amt), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  kv('Transaction ID', t.id),
                  kv('Date', dt(t.d)),
                  kv('Time', tm(t.d)),
                  kv('Account', accTxt),
                  kv('Type', '${t.debit ? 'Debit' : 'Credit'} \u2022 ${t.kind[0].toUpperCase()}${t.kind.substring(1)}'),
                  kv('Amount', '${t.debit ? '-' : '+'}${money(t.amt)}', c: t.debit ? rc : gc),
                  kv('Category', isTr ? 'Transfer' : t.cat),
                  kv('Description', nm(t)),
                  if (nm(t) != t.party && t.party != '-') kv('Original', t.party),
                  if (nt.isNotEmpty) kv('Note', nt),
                  kv('Method', t.method),
                  if (t.ref.isNotEmpty) kv('Reference', t.ref),
                  if (isDup(t))
                    TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => dupOk.add(t.id));
                          sp?.setStringList('dupok', dupOk.toList());
                          rev.value++;
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Keep both (duplicate nahi hai)')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (t.manual) {
                            addManual(t);
                          } else {
                            editMeta(t);
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(t.manual ? 'Edit' : 'Edit type / category')),
                    OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          rename(t);
                        },
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('Rename')),
                    OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          editNote(t);
                        },
                        icon: const Icon(Icons.notes, size: 18),
                        label: const Text('Note')),
                    TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          confirmDeleteTx(t);
                        },
                        icon: Icon(Icons.delete_outline, size: 18, color: rc),
                        label: Text(t.manual ? 'Delete' : 'Ignore', style: TextStyle(color: rc))),
                  ]),
                ]))));
  }

  void rename(Tx t, {bool group = false}) {
    final c = TextEditingController(text: nm(t) == 'Unknown recipient' ? '' : nm(t));
    var grp = group && t.party != '-';
    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Rename transaction'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Original:', style: sub),
                    Text(t.party == '-' ? 'Unknown' : t.party),
                    const SizedBox(height: 14),
                    Text('New name:', style: sub),
                    const SizedBox(height: 6),
                    TextField(
                        controller: c,
                        autofocus: true,
                        decoration: InputDecoration(
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                    if (t.party != '-')
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: grp,
                          onChanged: (v) => ss(() => grp = v ?? false),
                          title: const Text('Is party ke sabhi transactions ka')),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          final n = c.text.trim();
                          setState(() {
                            if (n.isEmpty) {
                              names.remove(t.id);
                              if (grp) alias.remove(t.party.toLowerCase());
                            } else if (grp) {
                              alias[t.party.toLowerCase()] = n;
                              names.remove(t.id);
                            } else {
                              names[t.id] = n;
                            }
                          });
                          saveNames();
                          rev.value++;
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'))
                  ],
                )));
  }

  void addManual([Tx? edit]) {
    final isEdit = edit != null;
    final ed = edit ?? Tx('', DateTime.now(), 0, false, '', '', '', '-', '');
    final accMap = <String, List<String>>{'Cash': ['Cash', 'Cash']};
    for (final t in all) {
      if (t.acc != 'Unknown' && !accHide.contains(keyOf(t))) accMap[keyOf(t)] = [t.bank, t.acc];
    }
    for (final a in macc) {
      accMap['${a['bank']} ${a['acc']}'] = [a['bank'] as String, a['acc'] as String];
    }
    final legs = isEdit ? legsOf(ed) : <Tx>[];
    final tr = isEdit && ed.kind == 'transfer' && legs.length == 2;
    final fromLeg = tr ? legs.firstWhere((x) => x.debit) : null;
    final toLeg = tr ? legs.firstWhere((x) => !x.debit) : null;
    if (isEdit) {
      for (final t in tr ? [fromLeg!, toLeg!] : [ed]) {
        accMap.putIfAbsent(mapKey(t), () => [t.bank, t.acc]);
      }
    }
    final names2 = accMap.keys.toList();
    final a = TextEditingController(text: isEdit ? fs(ed.amt) : '');
    final n = TextEditingController(text: isEdit && !tr && ed.party != '-' ? ed.party : '');
    final noteC = TextEditingController(text: isEdit ? (notes[ed.id] ?? '') : '');
    var kind = !isEdit
        ? 'expense'
        : tr
            ? 'transfer'
            : ed.kind == 'income'
                ? 'income'
                : ed.kind == 'expense'
                    ? 'expense'
                    : (ed.debit ? 'expense' : 'income');
    var cat = isEdit && !tr ? ed.cat : expCats.first;
    if (!catsFor(kind).contains(cat)) cat = catsFor(kind).first;
    var acc = !isEdit ? 'Cash' : mapKey(tr ? fromLeg! : ed);
    var to = tr ? mapKey(toLeg!) : names2.first;
    var method = isEdit ? ed.method : 'UPI';
    final methods = ['UPI', 'Cash', 'Card', 'NEFT/IMPS', 'Other'];
    if (!methods.contains(method)) methods.add(method);
    var when = isEdit ? ed.d : DateTime.now();
    var saving = false;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit Transaction' : 'Add Transaction', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'income', label: Text('Credit')),
                        ButtonSegment(value: 'expense', label: Text('Debit')),
                        ButtonSegment(value: 'transfer', label: Text('Transfer'))
                      ],
                      selected: {kind},
                      onSelectionChanged: (s) => ss(() {
                            kind = s.first;
                            if (!catsFor(kind).contains(cat)) cat = catsFor(kind).first;
                          })),
                  const SizedBox(height: 8),
                  TextField(
                      controller: a,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount', prefixText: rs)),
                  if (kind != 'transfer')
                    DropdownButtonFormField<String>(
                        value: cat,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [for (final c in catsFor(kind)) DropdownMenuItem(value: c, child: Text(c))],
                        onChanged: (v) => ss(() => cat = v ?? cat)),
                  DropdownButtonFormField<String>(
                      value: acc,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: kind == 'transfer' ? 'From account' : 'Account'),
                      items: [for (final c in names2) DropdownMenuItem(value: c, child: Text(accLbl[c] ?? c))],
                      onChanged: (v) => ss(() => acc = v ?? acc)),
                  if (kind == 'transfer')
                    DropdownButtonFormField<String>(
                        value: to,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'To account'),
                        items: [for (final c in names2) DropdownMenuItem(value: c, child: Text(accLbl[c] ?? c))],
                        onChanged: (v) => ss(() => to = v ?? to))
                  else
                    TextField(
                        controller: n,
                        decoration: InputDecoration(labelText: kind == 'income' ? 'Received from' : 'Paid to')),
                  DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Payment'),
                      items: [for (final c in methods) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => ss(() => method = v ?? method)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: when,
                                  firstDate: DateTime(2015),
                                  lastDate: DateTime.now().add(const Duration(days: 1)));
                              if (d != null) ss(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(dt(when)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () async {
                              final tp = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                              if (tp != null) ss(() => when = DateTime(when.year, when.month, when.day, tp.hour, tp.minute));
                            },
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(tm(when)))),
                  ]),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Note / description (optional)')),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: saving
                              ? null
                              : () {
                                  final v = double.tryParse(a.text.trim());
                                  if (v == null || v <= 0) return;
                                  if (kind == 'transfer' && acc == to) return;
                                  ss(() => saving = true);
                                  final nm1 = n.text.trim().isEmpty ? '-' : n.text.trim();
                                  final oldIds = isEdit ? legs.map((x) => x.id).toSet() : <String>{};
                                  final micro = DateTime.now().microsecondsSinceEpoch;
                                  final base = tr ? ed.id.substring(0, ed.id.length - 1) : 'm$micro';
                                  final id1 = isEdit && !tr ? ed.id : 'm$micro';
                                  Tx mk(String id, bool deb, String ac, String party) => Tx(
                                      id, when, v, deb, accMap[ac]![1], accMap[ac]![0], method, party, '',
                                      manual: true, kind: kind, cat: kind == 'transfer' ? 'Transfer' : cat);
                                  final newTx = kind == 'transfer'
                                      ? [mk('${base}a', true, acc, 'To ${accLbl[to] ?? to}'), mk('${base}b', false, to, 'From ${accLbl[acc] ?? acc}')]
                                      : [mk(id1, kind == 'expense', acc, nm1)];
                                  setState(() {
                                    manual.removeWhere((x) => oldIds.contains(x.id));
                                    manual.addAll(newTx);
                                    for (final id in oldIds) {
                                      notes.remove(id);
                                    }
                                    final nt = noteC.text.trim();
                                    if (nt.isNotEmpty) {
                                      for (final x in newTx) {
                                        notes[x.id] = nt;
                                      }
                                    }
                                  });
                                  saveManual();
                                  sp?.setString('notes', jsonEncode(notes));
                                  rev.value++;
                                  Navigator.pop(ctx);
                                },
                          child: Text(isEdit ? 'Update Transaction' : 'Save Transaction'))),
                ])))));
  }

  DateTimeRange reportRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTimeRange days(int n) => DateTimeRange(start: today.subtract(Duration(days: n - 1)), end: today);
    switch (rp) {
      case '7':
        return days(7);
      case '15':
        return days(15);
      case '90':
        return days(90);
      case 'm':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
      case 'lm':
        return DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0));
      case 'c':
        return rcr ?? days(30);
      default:
        return days(30);
    }
  }

  DateTimeRange prevRange(DateTimeRange r) {
    if (rp == 'm') {
      final ps = DateTime(r.start.year, r.start.month - 1, 1);
      final lastPrev = DateTime(r.start.year, r.start.month, 0).day;
      return DateTimeRange(start: ps, end: DateTime(ps.year, ps.month, r.end.day < lastPrev ? r.end.day : lastPrev));
    }
    if (rp == 'lm') {
      return DateTimeRange(start: DateTime(r.start.year, r.start.month - 1, 1), end: DateTime(r.start.year, r.start.month, 0));
    }
    final span = r.end.difference(r.start).inDays + 1;
    return DateTimeRange(start: r.start.subtract(Duration(days: span)), end: r.start.subtract(const Duration(days: 1)));
  }

  List<Tx> reportTx(DateTimeRange r) => all
      .where((t) =>
          !t.d.isBefore(r.start) && t.d.isBefore(r.end.add(const Duration(days: 1))) && (racc == 'all' || mapKey(t) == racc))
      .toList();

  Future<void> pickReportRange(String v) async {
    if (v == 'c') {
      final r = await showDateRangePicker(context: context, firstDate: DateTime(2015), lastDate: DateTime.now());
      if (r != null) {
        setState(() {
          rcr = r;
          rp = 'c';
          pieSel = null;
        });
      }
    } else {
      setState(() {
        rp = v;
        pieSel = null;
      });
    }
  }

  // Net worth ka anuman: abhi ka total balance - baad ke (income - expense)
  List<MapEntry<String, double>> netWorthSeries() {
    final now = DateTime.now();
    final nowTotal = totalBal(mainAccs());
    final txs = all.where((t) => t.kind != 'transfer').toList();
    final out = <MapEntry<String, double>>[];
    for (var k = 5; k >= 0; k--) {
      final end = k == 0 ? now : DateTime(now.year, now.month - k + 1, 1).subtract(const Duration(milliseconds: 1));
      var after = 0.0;
      for (final t in txs) {
        if (t.d.isAfter(end)) after += t.debit ? -t.amt : t.amt;
      }
      out.add(MapEntry(mon[DateTime(now.year, now.month - k, 1).month - 1], nowTotal - after));
    }
    return out;
  }

  Widget reportPage() {
    final r = reportRange();
    final span = r.end.difference(r.start).inDays + 1;
    final l = reportTx(r);
    final pl = reportTx(prevRange(r));
    final monthly = span > 62;
    final bStart = <DateTime>[];
    if (!monthly) {
      for (var i = 0; i < span; i++) {
        bStart.add(r.start.add(Duration(days: i)));
      }
    } else {
      var c = DateTime(r.start.year, r.start.month, 1);
      while (!c.isAfter(r.end)) {
        bStart.add(c);
        c = DateTime(c.year, c.month + 1, 1);
      }
    }
    final nb = bStart.length;
    final ex = List<double>.filled(nb, 0), inc = List<double>.filled(nb, 0), cnt = List<int>.filled(nb, 0);
    int bi(DateTime d) => monthly ? (d.year - bStart.first.year) * 12 + d.month - bStart.first.month : d.difference(r.start).inDays;
    for (final t in l) {
      if (t.kind == 'transfer') continue;
      final i = bi(t.d);
      if (i < 0 || i >= nb) continue;
      (t.debit ? ex : inc)[i] += t.amt;
      cnt[i]++;
    }
    final byAcc = <String, double>{}, accCnt = <String, int>{}, ct = <String, double>{}, pct = <String, double>{};
    final outBy = <String, List<Tx>>{}, inBy = <String, List<Tx>>{};
    for (final t in l.where((t) => t.kind != 'transfer')) {
      if (t.debit) {
        final k = keyOf(t);
        byAcc[k] = (byAcc[k] ?? 0) + t.amt;
        accCnt[k] = (accCnt[k] ?? 0) + 1;
        ct[t.cat] = (ct[t.cat] ?? 0) + t.amt;
        (outBy[nm(t)] ??= []).add(t);
      } else {
        (inBy[nm(t)] ??= []).add(t);
      }
    }
    for (final t in pl.where((t) => t.debit && t.kind != 'transfer')) {
      pct[t.cat] = (pct[t.cat] ?? 0) + t.amt;
    }
    final keys = byAcc.keys.toList();
    final ck = ct.keys.toList()..sort((a, b) => ct[b]!.compareTo(ct[a]!));
    final ctTotal = ct.values.fold<double>(0, (a, v) => a + v);
    final topOut = outBy.keys.toList()..sort((a, b) => spent(outBy[b]!).compareTo(spent(outBy[a]!)));
    final topIn = inBy.keys.toList()..sort((a, b) => got(inBy[b]!).compareTo(got(inBy[a]!)));
    final step = monthly ? 1 : span <= 7 ? 1 : span <= 15 ? 2 : span <= 31 ? 5 : 7;
    final colors = [Colors.indigo, Colors.purple, Colors.teal, Colors.orange, Colors.pink, Colors.cyan];
    final exp = spent(l), incm = got(l), pExp = spent(pl), pInc = got(pl);
    final net = incm - exp;
    String chg(double c, double p) => p <= 0 ? (c > 0 ? 'naya' : '-') : '${c >= p ? '+' : '-'}${((c - p).abs() * 100 / p).round()}%';
    Color chgCol(double c, double p, bool badUp) => p <= 0 || c == p ? cs.onSurfaceVariant : ((c > p) == badUp ? rc : gc);
    final deltas = <MapEntry<String, double>>[
      for (final c in {...ct.keys, ...pct.keys}) MapEntry(c, (ct[c] ?? 0) - (pct[c] ?? 0))
    ]..sort((a, b) => b.value.compareTo(a.value));
    final ups = deltas.where((e) => e.value > 0).take(3).toList();
    final downs = deltas.reversed.where((e) => e.value < 0).take(3).toList();
    final nw = netWorthSeries();
    // insights
    final expTx = l.where((t) => t.debit && t.kind != 'transfer').toList();
    Tx? big;
    for (final t in expTx) {
      if (big == null || t.amt > big.amt) big = t;
    }
    final wd = List<double>.filled(7, 0);
    for (final t in expTx) {
      wd[t.d.weekday - 1] += t.amt;
    }
    var wdMax = 0;
    for (var i = 1; i < 7; i++) {
      if (wd[i] > wd[wdMax]) wdMax = i;
    }
    const wdNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final insights = <String>[
      if (ck.isNotEmpty) 'Sabse zyada kharcha ${ck.first} me: ${money(ct[ck.first]!)} (${(ct[ck.first]! * 100 / ctTotal).round()}%)',
      if (expTx.isNotEmpty) 'Roz ka average kharcha: ${money(exp / span)}',
      if (big != null) 'Sabse bada kharcha: ${money(big.amt)} \u2022 ${nm(big)} (${dt(big.d)})',
      if (expTx.isNotEmpty && wd[wdMax] > 0) '${wdNames[wdMax]} ko sabse zyada kharcha hota hai (${money(wd[wdMax])})',
      if (incm > 0) 'Bachat: ${((incm - exp) * 100 / incm).round()}% income ki (${sm(incm - exp)})',
      '${expTx.length} kharch ke transactions is period me',
    ];
    final accOpts = <String, String>{'all': 'All Accounts', 'Cash': 'Cash'};
    for (final a in accountRows()) {
      if (!accHide.contains(a['k'])) accOpts[a['k'] as String] = accName(a);
    }
    if (!accOpts.containsKey(racc)) racc = 'all';
    final title = '${dt(r.start)} - ${dt(r.end)}';
    const gap = SizedBox(height: 14);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      head('Reports', sub: title),
      Row(children: [
        Expanded(
            child: chips({
          '7': '7 Days',
          '15': '15 Days',
          '30': '30 Days',
          'm': 'This month',
          'lm': 'Last month',
          '90': '3 Months',
          'c': rp == 'c' && rcr != null ? '${dt(rcr!.start)} - ${dt(rcr!.end)}' : 'Custom'
        }, rp, pickReportRange)),
        PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            onSelected: (v) {
              if (v == 'csv') {
                exportCsv(l);
              } else {
                copySummary(title, l);
              }
            },
            itemBuilder: (_) => const [
                  PopupMenuItem(value: 'csv', child: Text('CSV copy (is report ka)')),
                  PopupMenuItem(value: 'sum', child: Text('Summary text copy')),
                ]),
      ]),
      const SizedBox(height: 4),
      chips(accOpts, racc, (v) => setState(() {
            racc = v;
            pieSel = null;
          })),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: sub),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: stat('Expense', money(exp), rc)),
          Expanded(child: stat('Income', money(incm), gc)),
          Expanded(child: stat('Net', sm(net), net < 0 ? rc : gc)),
        ]),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pichhle period se tulna', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('${dt(prevRange(r).start)} - ${dt(prevRange(r).end)}', style: sub),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: Text('Expense')),
          Text('${money(pExp)} \u2192 ${money(exp)}  ', style: sub),
          Text(chg(exp, pExp), style: TextStyle(fontWeight: FontWeight.bold, color: chgCol(exp, pExp, true))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Expanded(child: Text('Income')),
          Text('${money(pInc)} \u2192 ${money(incm)}  ', style: sub),
          Text(chg(incm, pInc), style: TextStyle(fontWeight: FontWeight.bold, color: chgCol(incm, pInc, false))),
        ]),
        if (ups.isNotEmpty || downs.isNotEmpty) const Divider(),
        for (final e in ups)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.trending_up, size: 18, color: rc),
                const SizedBox(width: 8),
                Expanded(child: Text('${e.key} badha')),
                Text('+${money(e.value)}', style: const TextStyle(fontWeight: FontWeight.bold, color: rc)),
              ])),
        for (final e in downs)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.trending_down, size: 18, color: gc),
                const SizedBox(width: 8),
                Expanded(child: Text('${e.key} ghata')),
                Text('-${money(e.value.abs())}', style: const TextStyle(fontWeight: FontWeight.bold, color: gc)),
              ])),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(monthly ? 'Monthly expense (tap a bar)' : 'Daily expense (tap a bar)', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: BarChart(BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < nb; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: ex[i],
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(4),
                      width: monthly ? 16 : span <= 7 ? 18 : span <= 15 ? 12 : span <= 31 ? 6 : 3)
                ])
            ],
            barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (g, gi, rr, ri) => BarTooltipItem(
                        '${monthly ? '${mon[bStart[gi].month - 1]} ${bStart[gi].year}' : dt(bStart[gi])}\nExpense ${money(ex[gi])}\nIncome ${money(inc[gi])}\n${cnt[gi]} txns',
                        const TextStyle(color: Colors.white, fontSize: 12)))),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => v.toInt() % step == 0 && v.toInt() < nb
                          ? Text(monthly ? mon[bStart[v.toInt()].month - 1] : '${bStart[v.toInt()].day}', style: const TextStyle(fontSize: 11))
                          : const SizedBox())),
            ),
          )),
        ),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Net worth trend (anuman)', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Abhi ke total balance aur income/expense ke hisaab se pichhle 6 mahine', style: sub),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        return i >= 0 && i < nw.length && v == i.toDouble() ? Text(nw[i].key, style: const TextStyle(fontSize: 11)) : const SizedBox();
                      })),
            ),
            lineBarsData: [
              LineChartBarData(
                  spots: [for (var i = 0; i < nw.length; i++) FlSpot(i.toDouble(), nw[i].value)],
                  isCurved: true,
                  color: cs.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: cs.primary.withOpacity(0.12)))
            ],
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                          for (final p in spots)
                            LineTooltipItem('${nw[p.x.toInt()].key}\n${mask(p.y)}', const TextStyle(color: Colors.white, fontSize: 12))
                        ])),
          )),
        ),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (l.isEmpty) const Text('Is period me koi transaction nahi'),
        for (final x in insights)
          if (l.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(x)),
                ])),
      ])),
      if (racc == 'all' && keys.isNotEmpty) ...[
        gap,
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Account-wise spending (tap a slice)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              pieTouchData: PieTouchData(touchCallback: (e, rr) {
                if (e is FlTapUpEvent) {
                  final i = rr?.touchedSection?.touchedSectionIndex;
                  setState(() => pieSel = (i == null || i < 0) ? null : i);
                }
              }),
              sections: [
                for (var i = 0; i < keys.length; i++)
                  PieChartSectionData(
                      value: byAcc[keys[i]], title: '', radius: pieSel == i ? 62 : 52, color: colors[i % colors.length])
              ],
            )),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (var i = 0; i < keys.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10, color: colors[i % colors.length]),
                const SizedBox(width: 4),
                Text(accLbl[keys[i]] ?? keys[i], style: sub),
              ])
          ]),
          if (pieSel != null && pieSel! < keys.length)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${accLbl[keys[pieSel!]] ?? keys[pieSel!]}: ${money(byAcc[keys[pieSel!]]!)} \u2022 ${accCnt[keys[pieSel!]]} transactions',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
        ])),
      ],
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (ck.isEmpty) const Text('Is period me koi kharcha nahi'),
        for (final k in ck)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(k)),
                  Text('${(ct[k]! * 100 / ctTotal).round()}%  ', style: sub),
                  Text(money(ct[k]!), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: (ct[k]! / ctTotal).clamp(0.0, 1.0).toDouble(), minHeight: 6, color: catColor(k))),
              ])),
      ])),
      gap,
      const Text('Top spending people / merchants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (topOut.isEmpty) const Text('Is period me koi kharcha nahi'),
      for (final k in topOut.take(10))
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: card(
                onTap: () => personPage(outBy[k]!),
                Row(children: [
                  const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${outBy[k]!.length} transactions', style: sub),
                  ])),
                  Text(money(spent(outBy[k]!)), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]))),
      if (topIn.isNotEmpty) ...[
        gap,
        const Text('Top income sources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final k in topIn.take(5))
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: card(
                  onTap: () => personPage(inBy[k]!),
                  Row(children: [
                    const CircleAvatar(radius: 16, child: Icon(Icons.south_west, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${inBy[k]!.length} transactions', style: sub),
                    ])),
                    Text(money(got(inBy[k]!)), style: const TextStyle(fontWeight: FontWeight.bold, color: gc)),
                  ]))),
      ],
    ]);
  }

  Widget budgetPage() {
    final n = DateTime.now();
    final sp = spent(all.where((t) => inCyc(t.d)).toList());
    final dim = cycDim();
    final el = cycElapsed();
    final left = dim - el + 1;
    final up = upcomingMonth();
    final safe = (budget - sp - up) / left;
    final proj = sp / el * dim;
    final mm = all.where((t) => inCyc(t.d) && t.kind == 'expense').toList();
    Widget tile(String l, String v, Color c) => Expanded(
        child: card(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: sub),
              const SizedBox(height: 4),
              Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
            ]),
            pad: const EdgeInsets.all(14)));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      head('Budget', sub: cycLabel()),
      budgetCard(sp),
      const SizedBox(height: 12),
      alertsCard(),
      Row(children: [
        tile('Daily average', money(sp / el), cs.onSurface),
        const SizedBox(width: 12),
        tile('Month-end anuman', money(proj), proj > budget ? rc : cs.onSurface),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        tile('Baaki din', '$left', cs.onSurface),
        const SizedBox(width: 12),
        tile('Roz kharch limit', safe > 0 ? money(safe) : '${rs}0', safe > 0 ? gc : rc),
      ]),
      const SizedBox(height: 12),
      card(Row(children: [
        Expanded(child: Text('Baaki bills / EMI (is mahine)', style: sub)),
        Text(money(up), style: const TextStyle(fontWeight: FontWeight.w800)),
      ])),
      const SizedBox(height: 22),
      const Text('Category budgets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      for (final c in expCats) catBudgetCard(c, spent(mm.where((t) => t.cat == c).toList())),
      const SizedBox(height: 14),
      FilledButton.tonalIcon(onPressed: editBudget, icon: const Icon(Icons.edit), label: const Text('Edit budget')),
    ]);
  }

  void editBudget() {
    final c = TextEditingController(text: budget.toStringAsFixed(0));
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Monthly budget'),
              content: TextField(controller: c, keyboardType: TextInputType.number),
              actions: [
                TextButton(
                    onPressed: () {
                      setState(() => budget = double.tryParse(c.text) ?? budget);
                      sp?.setDouble('budget', budget);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'))
              ],
            ));
  }
}

class LockScreen extends StatefulWidget {
  final bool Function(String) check;
  const LockScreen(this.check, {super.key});
  @override
  State<LockScreen> createState() => _LockState();
}

class _LockState extends State<LockScreen> {
  final c = TextEditingController();
  bool bad = false;
  int fails = 0;
  DateTime? until;
  Timer? tk;

  bool get locked => until != null && DateTime.now().isBefore(until!);
  int get secLeft => until == null ? 0 : until!.difference(DateTime.now()).inSeconds + 1;

  @override
  void dispose() {
    tk?.cancel();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock, size: 56),
                      const SizedBox(height: 16),
                      const Text('Mera Kharcha', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('PIN daalo'),
                      const SizedBox(height: 16),
                      TextField(
                          controller: c,
                          autofocus: true,
                          enabled: !locked,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 24, letterSpacing: 8),
                          decoration: InputDecoration(
                              counterText: '', errorText: locked ? '$secLeft second baad try karo' : bad ? 'Galat PIN' : null),
                          onChanged: (v) {
                            if (locked) {
                              c.clear();
                              return;
                            }
                            if (v.length >= 4 && widget.check(v)) {
                              Navigator.pop(context);
                            } else if (v.length >= 6) {
                              c.clear();
                              fails++;
                              if (fails % 5 == 0) {
                                final secs = (fails ~/ 5) * 30 > 300 ? 300 : (fails ~/ 5) * 30;
                                until = DateTime.now().add(Duration(seconds: secs));
                                tk?.cancel();
                                tk = Timer.periodic(const Duration(seconds: 1), (t) {
                                  if (!mounted) {
                                    t.cancel();
                                    return;
                                  }
                                  if (!locked) t.cancel();
                                  setState(() {});
                                });
                              }
                              setState(() => bad = true);
                            } else if (bad) {
                              setState(() => bad = false);
                            }
                          }),
                    ])))));
  }
}


// ---------- Phase 9: Login (Mobile number + Gmail, sirf is phone me) ----------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SharedPreferences? sp;

  @override
  void initState() {
    super.initState();
    authN.addListener(_r);
    SharedPreferences.getInstance().then((v) {
      if (mounted) setState(() => sp = v);
    });
  }

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    authN.removeListener(_r);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = sp;
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (s.getString('pPhone') != null) return const Home();
    return LoginScreen(s, () => setState(() {}));
  }
}

class LoginScreen extends StatefulWidget {
  final SharedPreferences sp;
  final VoidCallback onDone;
  const LoginScreen(this.sp, this.onDone, {super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController nc, pc, gc, ac;
  String? err;
  bool busy = false, hasSaved = false;

  @override
  void initState() {
    super.initState();
    final sp = widget.sp;
    nc = TextEditingController(text: sp.getString('pName') ?? '');
    pc = TextEditingController(text: sp.getString('pPhone') ?? '');
    gc = TextEditingController(text: sp.getString('eAddr') ?? '');
    ac = TextEditingController();
    hasSaved = sp.getString('eAddr') != null && sp.getString('ePass') != null;
  }

  @override
  void dispose() {
    nc.dispose();
    pc.dispose();
    gc.dispose();
    ac.dispose();
    super.dispose();
  }

  Future<String?> verify(String addr, String pass) async {
    final c = mail.ImapClient(isLogEnabled: false);
    try {
      const to = Duration(seconds: 25);
      await c.connectToServer('imap.gmail.com', 993, isSecure: true).timeout(to);
      await c.login(addr, pass).timeout(to);
      return null;
    } catch (e) {
      final m = '$e'.toLowerCase();
      final bad = m.contains('auth') || m.contains('credential') || m.contains('login') || m.contains('password') || m.contains('invalid');
      return bad ? 'Gmail ya App Password galat hai' : 'Gmail se connect nahi ho paya. Internet check karo';
    } finally {
      try {
        await c.disconnect();
      } catch (_) {}
    }
  }

  Future<void> submit({bool skipGmail = false}) async {
    final name = nc.text.trim();
    var phone = pc.text.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.startsWith('+91')) phone = phone.substring(3);
    if (phone.length == 12 && phone.startsWith('91')) phone = phone.substring(2);
    final g = gc.text.trim().toLowerCase();
    final pass = ac.text.replaceAll(' ', '');
    if (name.isEmpty) return setState(() => err = 'Naam daalo');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) return setState(() => err = 'Sahi 10 digit mobile number daalo');
    if (!skipGmail && !RegExp(r'^[a-z0-9._%+\-]+@(gmail|googlemail)\.com$').hasMatch(g)) {
      return setState(() => err = 'Sahi Gmail address daalo (xyz@gmail.com)');
    }
    final sp = widget.sp;
    final oldAddr = sp.getString('eAddr');
    final keepOld = !skipGmail && pass.isEmpty && hasSaved && oldAddr == g;
    if (!skipGmail && !keepOld) {
      if (pass.length != 16) return setState(() => err = 'App Password 16 letter ka hota hai');
      setState(() {
        err = null;
        busy = true;
      });
      final e = await verify(g, pass);
      if (!mounted) return;
      if (e != null) {
        setState(() {
          busy = false;
          err = e;
        });
        return;
      }
    }
    await sp.setString('pName', name);
    await sp.setString('pPhone', phone);
    if (skipGmail) {
      await sp.remove('eAddr');
      await sp.remove('ePass');
    } else if (!keepOld) {
      await sp.setString('eAddr', g);
      await sp.setString('ePass', pass);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    InputDecoration dec(String l, {String? hint, String? prefix}) => InputDecoration(
        labelText: l, hintText: hint, prefixText: prefix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  Icon(Icons.account_balance_wallet, size: 52, color: cs.primary),
                  const SizedBox(height: 12),
                  const Text('Mera Kharcha', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Login karo. SMS aur Gmail ke transactions yahan dikhenge.', style: sub),
                  const SizedBox(height: 24),
                  TextField(controller: nc, textCapitalization: TextCapitalization.words, decoration: dec('Naam')),
                  const SizedBox(height: 14),
                  TextField(
                      controller: pc,
                      keyboardType: TextInputType.phone,
                      maxLength: 14,
                      decoration: dec('Mobile number', prefix: '+91 ').copyWith(counterText: '')),
                  const SizedBox(height: 14),
                  TextField(controller: gc, keyboardType: TextInputType.emailAddress, decoration: dec('Gmail address', hint: 'xyz@gmail.com')),
                  const SizedBox(height: 14),
                  TextField(
                      controller: ac,
                      obscureText: true,
                      decoration: dec('Gmail App Password (16 letter)', hint: hasSaved ? 'Pehle se saved hai, khali chhod sakte ho' : null)),
                  const SizedBox(height: 8),
                  Text(
                      'App Password kaise banaye: Google Account \u2192 Security \u2192 2-Step Verification on karo \u2192 App passwords \u2192 naam do \u2192 16 letter ka code copy karo. Ye normal Gmail password nahi hai. Ye sirf is phone me save hota hai.',
                      style: sub),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(err!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                          onPressed: busy ? null : () => submit(),
                          child: busy
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Text('Login', style: TextStyle(fontWeight: FontWeight.w800)))),
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                          onPressed: busy ? null : () => submit(skipGmail: true),
                          child: const Text('Gmail baad me jodunga (sirf SMS)'))),
                ]))));
  }
}
