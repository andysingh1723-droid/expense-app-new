import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enough_mail/enough_mail.dart' as mail;
import 'package:another_telephony/telephony.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

const rs = '\u20B9';
const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

void main() => runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
    home: const Home()));

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
  'federal': 'Federal Bank'
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
    hidden = (sp!.getStringList('hidden') ?? <String>[]).toSet();
    meta = (jsonDecode(sp!.getString('meta') ?? '{}') as Map)
        .map<String, Map<String, String>>((k, v) => MapEntry(k.toString(), Map<String, String>.from(v as Map)));
    cb = (jsonDecode(sp!.getString('cb') ?? '{}') as Map).map<String, double>((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    rec = ld('rec');
    loans = ld('loans');
    goals = ld('goals');
    dupOk = (sp!.getStringList('dupok') ?? <String>[]).toSet();
    pin = sp!.getString('pin');
    hideBal = sp!.getBool('hide') ?? false;
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
  }

  Future<void> load() async {
    final t = Telephony.instance;
    if (await t.requestSmsPermissions != true) {
      if (mounted) setState(() => status = 'SMS permission nahi mili. Allow karke refresh dabao.');
      return;
    }
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
    }
  }

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
    var cash = 0.0;
    for (final t in all) {
      if (t.manual && t.acc == 'Cash') cash += t.debit ? -t.amt : t.amt;
      if (!t.manual && t.method == 'ATM' && t.debit && t.kind == 'transfer') cash += t.amt;
    }
    out['Cash'] = cash;
    return out;
  }

  Widget accountsCard() {
    final b = balances();
    final total = b.values.fold<double>(0, (a, v) => a + v);
    const bold = TextStyle(fontWeight: FontWeight.bold);
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Accounts', style: bold),
      const SizedBox(height: 8),
      for (final e in b.entries)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(e.key == 'Cash' ? Icons.payments_outlined : Icons.account_balance_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(e.key)),
              Text(hideBal ? '\u2022\u2022\u2022\u2022' : sm(e.value), style: bold),
            ])),
      const Divider(),
      Row(children: [const Expanded(child: Text('Total', style: bold)), Text(hideBal ? '\u2022\u2022\u2022\u2022' : sm(total), style: bold)]),
      const SizedBox(height: 4),
      Text('Bank balance SMS ke "Avl Bal" se aata hai', style: sub),
    ]));
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
                Text('${money(sp)} / ${lim > 0 ? money(lim) : '-'}'),
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

  List<Map<String, dynamic>> dues() {
    final out = <Map<String, dynamic>>[];
    for (final r in rec) {
      out.add({'n': '${r['name']}', 'a': nv(r, 'amt'), 'd': nextDue(nv(r, 'day').toInt()), 'k': 'Bill'});
    }
    for (final l in loans) {
      if (nv(l, 'paid') < nv(l, 'months')) {
        out.add({'n': '${l['name']}', 'a': nv(l, 'emi'), 'd': nextDue(nv(l, 'day').toInt()), 'k': 'EMI'});
      }
    }
    out.sort((a, b) => (a['d'] as DateTime).compareTo(b['d'] as DateTime));
    return out;
  }

  double upcomingMonth() {
    final n = DateTime.now();
    return dues().where((x) {
      final d = x['d'] as DateTime;
      return d.month == n.month && d.year == n.year;
    }).fold<double>(0, (s, x) => s + (x['a'] as double));
  }

  Widget upcomingCard() {
    final n = DateTime.now();
    final lim = DateTime(n.year, n.month, n.day).add(const Duration(days: 8));
    final u = dues().where((x) => (x['d'] as DateTime).isBefore(lim)).toList();
    if (u.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Upcoming (7 din)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final x in u)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${x['k']}: ${x['n']}  \u2022  ${dt(x['d'] as DateTime)}')),
                  Text(money(x['a'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
                ])),
        ])));
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
      list.add(m);
    } else {
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
              Text('Next: ${dt(nextDue(nv(rec[i], 'day').toInt()))}', style: sub),
            ])),
            PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'del') {
                    rec.removeAt(i);
                    saveLists();
                  } else {
                    editItem(rec, i, 'Edit', recF);
                  }
                },
                itemBuilder: (_) => const [
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
              ? 'Next EMI: ${dt(nextDue(nv(loans[i], 'day').toInt()))}'
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
        CircleAvatar(child: Icon(ic)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(s, style: sub),
        ])),
        const Icon(Icons.chevron_right),
      ])));

  Widget morePage() {
    final monthly = loans.where((l) => nv(l, 'paid') < nv(l, 'months')).fold<double>(0, (s, l) => s + nv(l, 'emi'));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      head('More'),
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
    if (s == AppLifecycleState.paused && pin != null) showLock();
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

  Future<void> backup() async {
    final j = {
      'v': 1, 'budget': budget, 'manual': manual.map((e) => e.toJson()).toList(), 'names': names, 'alias': alias,
      'hidden': hidden.toList(), 'meta': meta, 'cb': cb, 'rec': rec, 'loans': loans, 'goals': goals, 'dupok': dupOk.toList()
    };
    await Clipboard.setData(ClipboardData(text: jsonEncode(j)));
    snack('Backup copy ho gaya. Ab Notes ya WhatsApp me paste karke save karo');
  }

  Future<void> restore(String txt) async {
    try {
      final j = jsonDecode(txt) as Map<String, dynamic>;
      if (j['v'] != 1) throw 'bad';
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
      });
      sp?.setDouble('budget', budget);
      sp?.setStringList('hidden', hidden.toList());
      sp?.setStringList('dupok', dupOk.toList());
      sp?.setString('meta', jsonEncode(meta));
      sp?.setString('cb', jsonEncode(cb));
      saveManual();
      saveNames();
      saveLists();
      await load();
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

  Future<void> exportCsv() async {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final l = all.toList()..sort((a, b) => b.d.compareTo(a.d));
    final b = StringBuffer('Date,Time,Type,Category,Name,Amount,Direction,Bank,Account,Method,Reference\n');
    for (final t in l) {
      b.writeln([
        '${t.d.year}-${two(t.d.month)}-${two(t.d.day)}', tm(t.d), t.kind, t.cat, q(nm(t)), t.amt.toStringAsFixed(2),
        t.debit ? 'Debit' : 'Credit', q(t.bank), t.acc, t.method, t.ref
      ].join(','));
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    snack('${l.length} transactions ka CSV copy ho gaya. Google Sheets/Excel me paste karo');
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
        if (pin == null)
          moreTile(Icons.lock_outline, 'App Lock (PIN)', 'Off \u2022 PIN lagao', setPin)
        else ...[
          moreTile(Icons.lock, 'PIN badlo', 'App Lock on hai', changePin),
          moreTile(Icons.lock_open, 'PIN hatao', 'App Lock band karo', removePin),
        ],
        moreTile(Icons.event_available_outlined, 'Tracking start date', '${dt(startD)} se pehle ki entries nahi dikhengi', pickStart),
        if (sp?.getString('eAddr') == null)
          moreTile(Icons.email_outlined, 'Email tracking (Gmail)', 'Off \u2022 Gmail jodo', setupEmail)
        else ...[
          moreTile(Icons.sync, 'Email sync abhi', emStatus.isEmpty ? '${sp?.getString('eAddr')}' : emStatus, syncEmail),
          moreTile(Icons.email, 'Email hatao', 'Email tracking band karo', removeEmail),
        ],
        moreTile(Icons.backup_outlined, 'Backup', 'Poora data copy hoga, Notes/WhatsApp me save karo', backup),
        moreTile(Icons.restore, 'Restore', 'Backup text paste karke wapas lao', restoreDialog),
        moreTile(Icons.table_chart_outlined, 'Export CSV', 'Sheets/Excel me paste karne ke liye', exportCsv),
        moreTile(Icons.info_outline, 'About', 'Mera Kharcha \u2022 data sirf is phone me rehta hai', () {}),
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

  Future<void> syncEmail() async {
    final addr = sp?.getString('eAddr'), pass = sp?.getString('ePass');
    if (addr == null || pass == null || emBusy) return;
    emBusy = true;
    final client = mail.ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      await client.login(addr, pass);
      await client.selectInbox();
      final r = await client.fetchRecentMessages(messageCount: 150, criteria: 'BODY.PEEK[]');
      final out = <Tx>[];
      final ids = <String>{};
      for (final m in r.messages) {
        final d = m.decodeDate() ?? DateTime.now();
        if (d.isBefore(startD)) continue;
        var text = m.decodeTextPlainPart() ?? '';
        if (text.trim().isEmpty) {
          text = (m.decodeTextHtmlPart() ?? '')
              .replaceAll(RegExp(r'<(style|script)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ')
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&');
        }
        text = '${m.decodeSubject() ?? ''}. $text'.replaceAll(RegExp(r'\s+'), ' ');
        text = text.replaceAll(RegExp(r'[^.]*\b(?:otp|request)\b[^.]*\.', caseSensitive: false), ' ');
        final from = (m.from != null && m.from!.isNotEmpty) ? m.from!.first.email : '';
        final x = parse(text, d.millisecondsSinceEpoch, from);
        if (x == null) continue;
        final e = asEmail(x);
        if (seen.contains(e.id) || sms.any((s) => near(s, e)) || !ids.add(e.id)) continue;
        applyMeta(e);
        out.add(e);
      }
      try {
        await client.logout();
      } catch (_) {}
      if (!mounted) return;
      final n = DateTime.now();
      setState(() {
        mails = out;
        emStatus = '${out.length} email transactions \u2022 sync ${tm(n)}';
      });
      rev.value++;
    } catch (e) {
      if (mounted) snack('Email sync fail: $e');
    } finally {
      emBusy = false;
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
    final from = range == 'c'
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
      if (range == 'c' && cr != null && !t.d.isBefore(cr!.end.add(const Duration(days: 1)))) return false;
      if (s.isEmpty) return true;
      final hay =
          '${nm(t)} ${t.party} ${t.bank} ${t.acc} ${t.method} ${t.ref} ${t.amt} ${t.amt.round()} ${t.kind} ${t.cat} ${t.debit ? 'debit expense sent' : 'credit income received'}'
              .toLowerCase();
      return hay.contains(s);
    }).toList();
    out.sort((a, b) => b.d.compareTo(a.d));
    return out;
  }

  final rev = ValueNotifier<int>(0);
  static const gc = Color(0xFF34C77B), rc = Color(0xFFF0616D);
  ColorScheme get cs => Theme.of(context).colorScheme;
  TextStyle get sub => TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

  Widget card(Widget child, {VoidCallback? onTap, EdgeInsets pad = const EdgeInsets.all(14)}) => Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: pad, child: child)));

  Widget head(String t, {String? sub}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 12),
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          if (sub != null) Text(sub, style: TextStyle(color: cs.onSurfaceVariant)),
        ])),
        IconButton(
            icon: refreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: refreshing ? null : refresh),
      ]));

  Widget stat(String label, String value, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: sub),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c)),
      ]);

  Widget chips(Map<String, String> o, String cur, void Function(String) on) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final e in o.entries)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(e.value), selected: cur == e.key, onSelected: (_) => on(e.key)))
      ]));

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
          child: status.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(status, textAlign: TextAlign.center)))
              : page()),
      floatingActionButton: tab <= 1
          ? FloatingActionButton.extended(onPressed: addManual, icon: const Icon(Icons.add), label: const Text('Add'))
          : null,
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Budget'),
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'More'),
          ]),
    );
  }

  Widget budgetCard(double sp) {
    final p = budget <= 0 ? 0.0 : (sp / budget).clamp(0.0, 1.0).toDouble();
    final over = sp > budget;
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Monthly Budget', style: TextStyle(fontWeight: FontWeight.bold))),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit, size: 20), onPressed: editBudget),
      ]),
      Text('${money(sp)} / ${money(budget)}'),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: p, minHeight: 10, color: over ? rc : gc)),
      const SizedBox(height: 6),
      Text(over ? 'Budget cross ho gaya!' : '${money(budget - sp)} bacha hai',
          style: TextStyle(color: over ? rc : cs.onSurfaceVariant)),
    ]));
  }

  Widget txCard(Tx t) {
    final c = t.kind == 'transfer' ? Colors.blueGrey : t.debit ? rc : gc;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: card(
            onTap: () => detail(t),
            Row(children: [
              CircleAvatar(
                  backgroundColor: c.withOpacity(0.15),
                  child: Icon(t.debit ? Icons.arrow_upward : Icons.arrow_downward, color: c, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nm(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${dt(t.d)} \u2022 ${tm(t.d)}', style: sub),
                Text('${t.bank} \u2022 ${t.method} \u2022 ${t.kind == 'transfer' ? 'Transfer' : t.cat}', style: sub),
                if (isDup(t)) const Text('\u26A0 Possible duplicate', style: TextStyle(fontSize: 12, color: Colors.amber)),
              ])),
              const SizedBox(width: 8),
              Text('${t.debit ? '-' : '+'}${money(t.amt)}', style: TextStyle(fontWeight: FontWeight.bold, color: c)),
            ])));
  }

  Widget peopleCard(List<Tx> l) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: card(
          onTap: () => personPage(l),
          Row(children: [
            const CircleAvatar(child: Icon(Icons.person)),
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
    final m = all.where((t) => t.d.year == n.year && t.d.month == n.month).toList();
    final bal = got(m) - spent(m);
    final rec = all.toList()..sort((a, b) => b.d.compareTo(a.d));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
      head('Mera Kharcha', sub: '${n.day} ${mon[n.month - 1]} ${n.year}'),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${mon[n.month - 1]} balance', style: TextStyle(color: cs.onPrimaryContainer)),
          const SizedBox(height: 6),
          Text(hideBal ? '\u2022\u2022\u2022\u2022' : '${bal < 0 ? '-' : ''}${money(bal.abs())}',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: stat('Income', money(got(m)), gc)),
            Expanded(child: stat('Expense', money(spent(m)), rc)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      accountsCard(),
      const SizedBox(height: 14),
      budgetCard(spent(m)),
      const SizedBox(height: 14),
      upcomingCard(),
      const SizedBox(height: 4),
      Row(children: [
        const Expanded(child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        TextButton(onPressed: () => setState(() => tab = 1), child: const Text('See all')),
      ]),
      if (rec.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Abhi koi transaction nahi'))),
      for (final t in rec.take(6)) txCard(t),
    ]);
  }

  Future<void> pickRange(String v) async {
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
      String? last;
      for (final t in f) {
        final k = dayLabel(t.d);
        if (k != last) {
          items.add(k);
          last = k;
        }
        items.add(t);
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
      head('Transactions'),
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
            fillColor: cs.surfaceContainerHigh,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Name, bank, account, amount or UPI',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
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
        'c': cr == null ? 'Custom' : '${dt(cr!.start)} - ${dt(cr!.end)}'
      }, range, pickRange),
      const SizedBox(height: 12),
      card(Row(children: [
        Expanded(child: stat('Txns', '${f.length}', cs.onSurface)),
        Expanded(child: stat('Income', money(got(f)), gc)),
        Expanded(child: stat('Expense', money(spent(f)), rc)),
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
          if (it is Tx) return txCard(it);
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
                  final items = <Object>[];
                  String? last;
                  for (final t in g) {
                    final k = dayLabel(t.d);
                    if (k != last) {
                      items.add(k);
                      last = k;
                    }
                    items.add(t);
                  }
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
                          return txCard(it as Tx);
                        }),
                  );
                })));
  }

  void detail(Tx t) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.debit ? 'Expense' : 'Income', style: TextStyle(color: t.debit ? rc : gc)),
              Text(money(t.amt), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(nm(t), style: const TextStyle(fontSize: 18)),
              if (nm(t) != t.party && t.party != '-') Text('Original: ${t.party}', style: sub),
              const SizedBox(height: 8),
              Text('${dt(t.d)}  ${tm(t.d)}'),
              Text('Bank: ${t.bank}'),
              Text('Account: ${t.acc}'),
              Text('Method: ${t.method}'),
              Text('Type: ${t.kind[0].toUpperCase()}${t.kind.substring(1)}  \u2022  Category: ${t.cat}'),
              TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    editMeta(t);
                  },
                  icon: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Change type / category')),
              if (isDup(t))
                TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => dupOk.add(t.id));
                      sp?.setStringList('dupok', dupOk.toList());
                      rev.value++;
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Keep both (duplicate nahi hai)')),
              if (t.ref.isNotEmpty) Text('Reference: ${t.ref}'),
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      rename(t);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Rename')),
                if (!t.manual) ...[
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => hidden.add(t.id));
                        sp?.setStringList('hidden', hidden.toList());
                        rev.value++;
                      },
                      child: const Text('Ignore'))
                ],
                if (t.manual) ...[
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => manual.removeWhere((x) => x.id == t.id));
                        saveManual();
                        rev.value++;
                      },
                      child: const Text('Delete'))
                ]
              ]),
            ])));
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

  void addManual() {
    final accMap = <String, List<String>>{'Cash': ['Cash', 'Cash']};
    for (final t in all) {
      if (t.acc != 'Unknown') accMap[t.bank == 'Unknown' ? t.acc : '${t.bank} ${t.acc}'] = [t.bank, t.acc];
    }
    final names2 = accMap.keys.toList();
    final a = TextEditingController(), n = TextEditingController();
    var kind = 'expense', cat = expCats.first, acc = 'Cash', to = names2.first, method = 'UPI';
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Add Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'income', label: Text('Income')),
                        ButtonSegment(value: 'expense', label: Text('Expense')),
                        ButtonSegment(value: 'transfer', label: Text('Transfer'))
                      ],
                      selected: {kind},
                      onSelectionChanged: (s) => ss(() {
                            kind = s.first;
                            cat = catsFor(kind).first;
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
                      decoration: InputDecoration(labelText: kind == 'transfer' ? 'From account' : 'Account'),
                      items: [for (final c in names2) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => ss(() => acc = v ?? acc)),
                  if (kind == 'transfer')
                    DropdownButtonFormField<String>(
                        value: to,
                        decoration: const InputDecoration(labelText: 'To account'),
                        items: [for (final c in names2) DropdownMenuItem(value: c, child: Text(c))],
                        onChanged: (v) => ss(() => to = v ?? to))
                  else
                    TextField(
                        controller: n,
                        decoration: InputDecoration(labelText: kind == 'income' ? 'Received from' : 'Paid to')),
                  DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Payment'),
                      items: [for (final c in const ['UPI', 'Cash', 'Card', 'NEFT/IMPS', 'Other']) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => ss(() => method = v ?? method)),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () {
                            final v = double.tryParse(a.text);
                            if (v == null || v <= 0) return;
                            if (kind == 'transfer' && acc == to) return;
                            final now = DateTime.now();
                            final base = 'm${now.microsecondsSinceEpoch}';
                            final nm1 = n.text.trim().isEmpty ? '-' : n.text.trim();
                            Tx mk(String id, bool deb, String ac, String party) => Tx(id, now, v, deb, accMap[ac]![1],
                                accMap[ac]![0], method, party, '',
                                manual: true, kind: kind, cat: kind == 'transfer' ? 'Transfer' : cat);
                            setState(() {
                              if (kind == 'transfer') {
                                manual.add(mk('${base}a', true, acc, 'To $to'));
                                manual.add(mk('${base}b', false, to, 'From $acc'));
                              } else {
                                manual.add(mk(base, kind == 'expense', acc, nm1));
                              }
                            });
                            saveManual();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save Transaction'))),
                ])))));
  }

  Widget reportPage() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: rd - 1));
    final l = all.where((t) => !t.d.isBefore(start)).toList();
    final days = List.generate(rd, (i) => start.add(Duration(days: i)));
    final ex = List<double>.filled(rd, 0), inc = List<double>.filled(rd, 0), cnt = List<int>.filled(rd, 0);
    for (final t in l) {
      final i = t.d.difference(start).inDays;
      if (i < 0 || i >= rd) continue;
      if (t.kind == 'transfer') continue;
      (t.debit ? ex : inc)[i] += t.amt;
      cnt[i]++;
    }
    final byAcc = <String, double>{}, accCnt = <String, int>{}, top = <String, double>{}, ct = <String, double>{};
    for (final t in l.where((t) => t.debit && t.kind != 'transfer')) {
      final k = t.bank == 'Unknown' || t.bank == t.acc ? t.acc : '${t.bank} ${t.acc}';
      byAcc[k] = (byAcc[k] ?? 0) + t.amt;
      accCnt[k] = (accCnt[k] ?? 0) + 1;
      top[nm(t)] = (top[nm(t)] ?? 0) + t.amt;
      ct[t.cat] = (ct[t.cat] ?? 0) + t.amt;
    }
    final keys = byAcc.keys.toList();
    final tk = top.keys.toList()..sort((a, b) => top[b]!.compareTo(top[a]!));
    final ck = ct.keys.toList()..sort((a, b) => ct[b]!.compareTo(ct[a]!));
    final ctTotal = ct.values.fold<double>(0, (a, v) => a + v);
    final step = rd <= 7 ? 1 : rd <= 15 ? 2 : 5;
    final colors = [Colors.indigo, Colors.purple, Colors.teal, Colors.orange, Colors.pink, Colors.cyan];
    final net = got(l) - spent(l);
    const gap = SizedBox(height: 14);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      head('Reports'),
      chips(const {'7': '7 Days', '15': '15 Days', '30': '1 Month'}, '$rd', (v) => setState(() {
            rd = int.parse(v);
            pieSel = null;
          })),
      gap,
      card(Row(children: [
        Expanded(child: stat('Expense', money(spent(l)), rc)),
        Expanded(child: stat('Income', money(got(l)), gc)),
        Expanded(child: stat('Net', '${net < 0 ? '-' : ''}${money(net.abs())}', cs.onSurface)),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily expense (tap a bar)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: BarChart(BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < rd; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: ex[i],
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(4),
                      width: rd <= 7 ? 18 : rd <= 15 ? 12 : 6)
                ])
            ],
            barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                        '${dt(days[gi])}\nExpense ${money(ex[gi])}\nIncome ${money(inc[gi])}\n${cnt[gi]} txns',
                        const TextStyle(color: Colors.white, fontSize: 12)))),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => v.toInt() % step == 0 && v.toInt() < rd
                          ? Text('${days[v.toInt()].day}', style: const TextStyle(fontSize: 11))
                          : const SizedBox())),
            ),
          )),
        ),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Account-wise spending (tap a slice)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 36,
            pieTouchData: PieTouchData(touchCallback: (e, r) {
              if (e is FlTapUpEvent) {
                final i = r?.touchedSection?.touchedSectionIndex;
                setState(() => pieSel = (i == null || i < 0) ? null : i);
              }
            }),
            sections: [
              for (var i = 0; i < keys.length; i++)
                PieChartSectionData(
                    value: byAcc[keys[i]],
                    title: '',
                    radius: pieSel == i ? 62 : 52,
                    color: colors[i % colors.length])
            ],
          )),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (var i = 0; i < keys.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 10, color: colors[i % colors.length]),
              const SizedBox(width: 4),
              Text(keys[i], style: sub),
            ])
        ]),
        if (pieSel != null && pieSel! < keys.length)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${keys[pieSel!]}: ${money(byAcc[keys[pieSel!]]!)} \u2022 ${accCnt[keys[pieSel!]]} transactions',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
      ])),
      gap,
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (ck.isEmpty) const Text('Is period me koi kharcha nahi'),
        for (final k in ck)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(k)),
                Text('${(ct[k]! * 100 / ctTotal).round()}%  ', style: sub),
                Text(money(ct[k]!), style: const TextStyle(fontWeight: FontWeight.bold)),
              ])),
      ])),
      gap,
      const Text('Top spending people / merchants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (tk.isEmpty) const Text('Is period me koi kharcha nahi'),
      for (final k in tk.take(5))
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: card(Row(children: [
              const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(money(top[k]!), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]))),
    ]);
  }

  Widget budgetPage() {
    final n = DateTime.now();
    final sp = spent(all.where((t) => t.d.year == n.year && t.d.month == n.month).toList());
    final dim = DateTime(n.year, n.month + 1, 0).day;
    final left = dim - n.day + 1;
    final up = upcomingMonth();
    final safe = (budget - sp - up) / left;
    final mm = all.where((t) => t.d.year == n.year && t.d.month == n.month && t.kind == 'expense').toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      head('Budget', sub: '${mon[n.month - 1]} ${n.year}'),
      budgetCard(sp),
      const SizedBox(height: 14),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stat('Daily average so far', money(sp / n.day), cs.onSurface),
        const SizedBox(height: 12),
        stat('Mahine ke baaki din', '$left', cs.onSurface),
        const SizedBox(height: 12),
        stat('Baaki bills / EMI (is mahine)', money(up), cs.onSurface),
        const SizedBox(height: 12),
        stat('Roz kitna kharch kar sakte ho', safe > 0 ? money(safe) : '${rs}0', safe > 0 ? gc : rc),
      ])),
      const SizedBox(height: 18),
      const Text('Category budgets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
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
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 24, letterSpacing: 8),
                          decoration: InputDecoration(counterText: '', errorText: bad ? 'Galat PIN' : null),
                          onChanged: (v) {
                            if (v.length >= 4 && widget.check(v)) {
                              Navigator.pop(context);
                            } else if (v.length >= 6) {
                              c.clear();
                              setState(() => bad = true);
                            } else if (bad) {
                              setState(() => bad = false);
                            }
                          }),
                    ])))));
  }
}
