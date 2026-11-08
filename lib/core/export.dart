import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import 'currency.dart';
import 'loans.dart';
import 'planning.dart';
import 'plans.dart';
import 'round6.dart';
import 'store.dart';
import 'util.dart';

/// The built-in PDF fonts only cover Latin-1, so other characters (emoji, ₹, €…) are swapped or dropped.
String latin(String s) {
  const rep = {'€': 'EUR ', '₹': 'Rs ', '₨': 'Rs ', '£': 'GBP ', '¥': 'JPY ', '–': '-', '—': '-', '•': '·', '’': "'", '‘': "'", '“': '"', '”': '"', '…': '...', '≈': '~', '→': '->'};
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (rep.containsKey(ch)) {
      b.write(rep[ch]);
    } else if (r < 256) {
      b.write(ch);
    }
  }
  return b.toString().trim();
}

String slashDate(String d) {
  final x = parseDate(d);
  return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

J exportCfg(AppStore s) {
  if (s.settings['exportCfg'] is! Map) {
    s.settings['exportCfg'] = <String, dynamic>{'overview': true, 'charts': true, 'insights': true, 'txlist': true, 'income': true, 'behavior': true, 'top': true, 'budget': true, 'predict': false, 'bank': false, 'bankAccs': <dynamic>[]};
  }
  return s.settings['exportCfg'] as J;
}

/// Financial Summary Report as a PDF (same sections as the in-app preview / web report).
Future<Uint8List> buildReportPdf(AppStore s, String f, String t) async {
  final cfg = exportCfg(s);
  String B(num v) => latin(money(v, s.base));
  final h = s.healthScore(f, t);
  final st = h.st, ps = h.ps;
  final L = s.statList(f, t);
  final exp = L.where(s.isExp).toList(), inc = L.where(s.isInc).toList();
  final by = <String, double>{};
  for (final x in exp) {
    by['${x['catId']}'] = (by['${x['catId']}'] ?? 0) + s.tBase(x);
  }
  final cats = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final net = st.inc - st.exp;
  final nw = s.netWorthDetail();
  final pr = '${fmtDate(f)} - ${fmtDate(t)}';
  final green = PdfColor.fromHex('#2FAE72'), red = PdfColor.fromHex('#D93F38'), muted = PdfColor.fromHex('#6A747D'), dark = PdfColor.fromHex('#0E2A1F');
  String cn(String? id) => latin('${s.cat(id)?['name'] ?? 'Other'}');

  pw.Widget title(String x) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: green, width: 1))),
        child: pw.Text(latin(x), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dark)),
      );
  pw.Widget table(List<String> head, List<List<String>> rows, {List<int> right = const []}) => pw.TableHelper.fromTextArray(
        headers: head.map(latin).toList(),
        data: rows.map((r) => r.map(latin).toList()).toList(),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: green),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        cellAlignments: {for (final i in right) i: pw.Alignment.centerRight},
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#EEF0F2'), width: .5)),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      );
  pw.Widget metric(String k, String v, PdfColor c) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(3),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F6F7'), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(latin(k), style: pw.TextStyle(fontSize: 8, color: muted)), pw.Text(latin(v), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: c))]),
        ),
      );

  final body = <pw.Widget>[
    pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: dark, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('FINANCIAL REPORT', style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9, letterSpacing: 2)),
        pw.Text('Financial Summary Report', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(latin(pr), style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
        pw.Text(latin('Prepared for: ${s.settings['name'] ?? 'You'}'), style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
      ]),
    ),
    pw.SizedBox(height: 8),
    pw.Row(children: [metric('Total Income', B(st.inc), green), metric('Total Expenses', B(st.exp), red), metric(net >= 0 ? 'Net Surplus' : 'Net Deficit', B(net), net >= 0 ? green : red), metric('Savings Rate', '${(h.sr * 100).toStringAsFixed(1)}%', h.sr >= 0 ? green : red)]),
    pw.Row(children: [metric('Cash In', B(st.cin), green), metric('Cash Out', B(st.cout), red)]),
  ];
  if (cfg['overview'] == true) {
    body.addAll([
      title('Financial Health Score'),
      pw.Text('${h.score} / 100  ·  Grade ${h.grade} - ${h.label}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C9830F'))),
      pw.SizedBox(height: 6),
      table(['Area', 'Points', 'Note'], [for (final x in h.parts) [x.$1, '${x.$2} / ${x.$3}', x.$4]], right: [1]),
      pw.SizedBox(height: 6),
      pw.Text('Recommendations', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      for (final (i, r) in s.recommendations(h, B).indexed) pw.Text('${i + 1}. ${latin(r)}', style: const pw.TextStyle(fontSize: 9)),
    ]);
  }
  body.addAll([
    title('Net Worth Statement'),
    pw.Text('Net worth: ${B(nw.net)}   ·   Net savings this period: ${B(net)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    pw.SizedBox(height: 4),
    table(['Assets', 'Amount'], [for (final g in nw.groups) [g.name, B(g.v)], ['Total Assets', B(nw.A)]], right: [1]),
    pw.SizedBox(height: 4),
    table(['Liabilities', 'Amount'], [for (final g in nw.lgroups) [g.name, B(g.v)], ['Total Liabilities', B(nw.L)]], right: [1]),
    title('Cash Flow Statement'),
    table(['', 'Amount'], [['Cash In', B(st.cin)], ['Cash Out', B(st.cout)], ['Net Cash Flow', B(st.cin - st.cout)]], right: [1]),
  ]);
  if (cfg['income'] == true) {
    final ib = <String, double>{};
    for (final x in inc) {
      ib['${x['catId']}'] = (ib['${x['catId']}'] ?? 0) + s.tBase(x);
    }
    body.addAll([pw.SizedBox(height: 4), table(['Income', 'Amount'], [for (final e in ib.entries) [cn(e.key), B(e.value)], ['Total Income', B(st.inc)]], right: [1])]);
  }
  body.addAll([
    pw.SizedBox(height: 4),
    table(['Expenses', 'Amount', '%'], [for (final e in cats) [cn(e.key), B(e.value), '${(e.value / st.exp * 100).toStringAsFixed(1)}%'], ['Total Expenses', B(st.exp), '']], right: [1, 2]),
  ]);
  if (cfg['behavior'] == true) {
    final wd = List<double>.filled(7, 0);
    for (final x in exp) {
      wd[parseDate('${x['date']}').weekday - 1] += s.tBase(x);
    }
    body.addAll([title('Spending by Day of Week'), table(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], [wd.map((v) => B(v)).toList()])]);
  }
  if (cfg['budget'] == true && s.budgets.isNotEmpty) {
    body.addAll([
      title('Budget Performance'),
      table(['Budget', 'Period', 'Spent', 'Budget', 'Used'], [for (final b in s.budgets) ['${b['name']}', '${b['period'] ?? 'monthly'}', B(s.budgetSpent(b)), B(toD(b['amount'])), '${(toD(b['amount']) > 0 ? s.budgetSpent(b) / toD(b['amount']) * 100 : 0).toStringAsFixed(0)}%']], right: [2, 3, 4]),
    ]);
  }
  if (s.loans.isNotEmpty || s.installments.isNotEmpty) {
    body.addAll([
      title('Debt & Liabilities'),
      pw.Text('Monthly payments: ${B(s.monthlyDebtPayments())}', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 4),
      table(['Debt', 'Monthly', 'Remaining'], [
        for (final l in s.loans) ['${l['name']}', latin(money(s.emiOf(l), s.lcur(l))), latin(money(s.loanRemain(l), s.lcur(l)))],
        for (final x in s.installments) ['${x['title']}', B(toD(x['amount'])), B(s.instRemain(x))],
      ], right: [1, 2]),
    ]);
  }
  if (cfg['predict'] == true) {
    final ms = [for (var i = 1; i <= 3; i++) addMonthsYm(ym(f), -i)];
    final vals = [for (final k in ms) s.stats(monthStart(k), monthEnd(k)).exp];
    body.addAll([title('Expense Prediction'), pw.Text('Next month forecast (3-month average): ${B(vals.fold(0.0, (a, v) => a + v) / 3)}', style: const pw.TextStyle(fontSize: 10)), table(['Month', 'Expenses'], [for (var i = 0; i < 3; i++) [fmtMonth(ms[i]), B(vals[i])]], right: [1])]);
  }
  if (cfg['insights'] == true) {
    String ch(double a, double b) => b != 0 ? '${((a - b) / b.abs() * 100).toStringAsFixed(1)}%' : '-';
    body.addAll([
      title('Behavioral Insights'),
      if (cats.isNotEmpty) pw.Text('Your highest spending category this period was "${cn(cats.first.key)}".', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      table(['Metric', 'This period', 'Previous period', 'Change'], [
        ['Income', B(st.inc), B(ps.inc), ch(st.inc, ps.inc)],
        ['Expenses', B(st.exp), B(ps.exp), ch(st.exp, ps.exp)],
        ['Net Savings', B(net), B(ps.inc - ps.exp), ch(net, ps.inc - ps.exp)],
      ], right: [1, 2, 3]),
    ]);
  }
  if (cfg['top'] == true) {
    final te = (exp.toList()..sort((a, b) => s.tBase(b).compareTo(s.tBase(a)))).take(5);
    final ti = (inc.toList()..sort((a, b) => s.tBase(b).compareTo(s.tBase(a)))).take(5);
    List<List<String>> rows(Iterable<J> l) => [for (final x in l) [slashDate('${x['date']}'), '${'${x['note'] ?? ''}'.isNotEmpty ? x['note'] : s.txTitle(x)}', s.txTitle(x), B(s.tBase(x))]];
    body.addAll([title('Largest Expenses'), table(['Date', 'Description', 'Category', 'Amount'], rows(te), right: [3]), title('Largest Income'), table(['Date', 'Description', 'Category', 'Amount'], rows(ti), right: [3])]);
  }
  if (cfg['txlist'] == true) {
    final all = [...L]..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    body.addAll([
      title('Transaction List - ${all.length} transactions'),
      table(['Date', 'Description', 'Category', 'Wallet', 'Amount'], [
        for (final x in all.take(1000)) [slashDate('${x['date']}'), '${'${x['note'] ?? ''}'.isNotEmpty ? x['note'] : s.txTitle(x)}', s.txTitle(x), s.accName(x['accId']), '${x['type'] == 'income' ? '+' : '-'} ${B(s.tBase(x))}'],
      ], right: [4]),
    ]);
  }
  if (cfg['bank'] == true) {
    for (final st2 in bankStatements(s, f, t)) {
      body.addAll([
        title('Bank Statement - ${st2.name}'),
        pw.Text(latin('${st2.cur} · ${slashDate(f)} - ${slashDate(t)} · Opening ${money(st2.open, st2.cur)} · Money out ${money(st2.out, st2.cur)} · Money in ${money(st2.inn, st2.cur)} · Closing ${money(st2.close, st2.cur)}'), style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        table(['Date', 'Description', 'Debit', 'Credit', 'Balance'], [
          [slashDate(f), 'Opening balance', '', '', latin(money(st2.open, st2.cur))],
          for (final r in st2.rows) [slashDate(r.date), r.desc, r.debit == 0 ? '' : latin(money(r.debit, st2.cur)), r.credit == 0 ? '' : latin(money(r.credit, st2.cur)), latin(money(r.bal, st2.cur))],
          ['', 'Closing balance', latin(money(st2.out, st2.cur)), latin(money(st2.inn, st2.cur)), latin(money(st2.close, st2.cur))],
        ], right: [2, 3, 4]),
      ]);
    }
  }

  final doc = pw.Document(title: 'Financial Summary Report', author: AppConfig.appName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('${AppConfig.appName} · Confidential', style: pw.TextStyle(fontSize: 8, color: muted)),
      pw.Text('Generated ${latin(fmtDate(today()))} · Page ${c.pageNumber} of ${c.pagesCount}', style: pw.TextStyle(fontSize: 8, color: muted)),
    ]),
    build: (_) => body,
  ));
  return doc.save();
}

class StatementRow {
  StatementRow(this.date, this.desc, this.debit, this.credit, this.bal);
  final String date, desc;
  final double debit, credit, bal;
}

class Statement {
  Statement(this.name, this.cur, this.open, this.out, this.inn, this.rows);
  final String name, cur;
  final double open, out, inn;
  final List<StatementRow> rows;
  double get close => open - out + inn;
}

/// Bank statements for the accounts chosen in Export settings.
List<Statement> bankStatements(AppStore s, String f, String t) {
  final out = <Statement>[];
  for (final id in ((exportCfg(s)['bankAccs'] as List?) ?? const []).map((e) => '$e')) {
    final a = s.acc(id);
    if (a == null) continue;
    final open = s.txns.where((x) => x['accId'] == id && '${x['date']}'.compareTo(f) < 0).fold(0.0, (v, x) => v + (x['type'] == 'income' ? toD(x['amount']) : -toD(x['amount'])));
    final tl = s.txns.where((x) => x['accId'] == id && '${x['date']}'.compareTo(f) >= 0 && '${x['date']}'.compareTo(t) <= 0).toList()..sort((x, y) => '${x['date']}${x['time'] ?? ''}'.compareTo('${y['date']}${y['time'] ?? ''}'));
    var bal = open, dr = 0.0, cr = 0.0;
    final rows = <StatementRow>[];
    for (final x in tl) {
      final isCr = x['type'] == 'income';
      final v = toD(x['amount']);
      bal += isCr ? v : -v;
      if (isCr) {
        cr += v;
      } else {
        dr += v;
      }
      rows.add(StatementRow('${x['date']}', '${'${x['note'] ?? ''}'.isNotEmpty ? x['note'] : s.txTitle(x)}', isCr ? 0 : v, isCr ? v : 0, bal));
    }
    out.add(Statement('${a['name']}', '${a['currency']}', open, dr, cr, rows));
  }
  return out;
}

// ======================================================================= Excel (.xlsx) — written directly, no extra plugin
String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _col(int i) {
  var n = i + 1, s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _sheetXml(List<List<Object?>> rows) {
  final b = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    b.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      if (v == null) continue;
      final ref = '${_col(c)}${r + 1}';
      final head = r == 0 ? ' s="1"' : '';
      if (v is num) {
        b.write('<c r="$ref"$head><v>${v.isFinite ? v : 0}</v></c>');
      } else {
        b.write('<c r="$ref" t="inlineStr"$head><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

Uint8List buildXlsx(List<(String, List<List<Object?>>)> sheets) {
  final a = Archive();
  void add(String name, String text) {
    final bytes = utf8.encode(text);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  final names = <String>[];
  for (final sh in sheets) {
    var n = sh.$1.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    if (n.length > 31) n = n.substring(0, 31);
    if (n.isEmpty) n = 'Sheet';
    var k = n, i = 2;
    while (names.contains(k)) {
      k = '${n.substring(0, n.length > 28 ? 28 : n.length)} ${i++}';
    }
    names.add(k);
  }
  add('[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>');
  add('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  add('xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>');
  add('xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');
  add('xl/styles.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs></styleSheet>');
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i].$2));
  }
  final out = ZipEncoder().encode(a);
  // ignore: dead_null_aware_expression
  return Uint8List.fromList(out ?? <int>[]);
}

/// The report as an Excel workbook: Summary, Categories, Transactions (+ bank statements).
Uint8List buildReportXlsx(AppStore s, String f, String t) {
  final cfg = exportCfg(s);
  final h = s.healthScore(f, t);
  final st = h.st;
  final L = s.statList(f, t);
  final exp = L.where(s.isExp).toList(), inc = L.where(s.isInc).toList();
  double r2(double v) => round2(v);
  final sheets = <(String, List<List<Object?>>)>[
    (
      'Summary',
      [
        ['Financial Summary Report', '${fmtDate(f)} - ${fmtDate(t)}'],
        ['Main currency', s.base],
        ['Total income', r2(st.inc)],
        ['Total expenses', r2(st.exp)],
        ['Net', r2(st.inc - st.exp)],
        ['Savings rate %', r2(h.sr * 100)],
        ['Cash in', r2(st.cin)],
        ['Cash out', r2(st.cout)],
        ['Financial health score', h.score],
        ['Grade', '${h.grade} - ${h.label}'],
        ['Net worth', r2(s.netWorthDetail().net)],
      ]
    ),
  ];
  final byE = <String, (double, int)>{}, byI = <String, (double, int)>{};
  for (final x in exp) {
    final o = byE['${x['catId']}'] ?? (0.0, 0);
    byE['${x['catId']}'] = (o.$1 + s.tBase(x), o.$2 + 1);
  }
  for (final x in inc) {
    final o = byI['${x['catId']}'] ?? (0.0, 0);
    byI['${x['catId']}'] = (o.$1 + s.tBase(x), o.$2 + 1);
  }
  sheets.add((
    'Categories',
    [
      ['Type', 'Category', 'Amount (${s.base})', 'Transactions', '% of total'],
      for (final e in (byE.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1)))) ['Expense', '${s.cat(e.key)?['name'] ?? 'Other'}', r2(e.value.$1), e.value.$2, st.exp != 0 ? r2(e.value.$1 / st.exp * 100) : 0],
      if (cfg['income'] == true)
        for (final e in (byI.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1)))) ['Income', '${s.cat(e.key)?['name'] ?? 'Other'}', r2(e.value.$1), e.value.$2, st.inc != 0 ? r2(e.value.$1 / st.inc * 100) : 0],
    ]
  ));
  if (cfg['budget'] == true && s.budgets.isNotEmpty) {
    sheets.add(('Budgets', [
      ['Budget', 'Period', 'Spent', 'Budget', 'Used %'],
      for (final b in s.budgets) ['${b['name']}', '${b['period'] ?? 'monthly'}', r2(s.budgetSpent(b)), toD(b['amount']), toD(b['amount']) > 0 ? r2(s.budgetSpent(b) / toD(b['amount']) * 100) : 0],
    ]));
  }
  final all = [...L]..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
  sheets.add((
    'Transactions',
    [
      ['Date', 'Type', 'Description', 'Category', 'Wallet', 'Amount', 'Currency', 'Amount (${s.base})', 'Tags'],
      for (final x in all)
        [
          '${x['date']}',
          '${x['type']}',
          '${'${x['note'] ?? ''}'.isNotEmpty ? x['note'] : s.txTitle(x)}',
          s.txTitle(x),
          s.accName(x['accId']),
          (x['type'] == 'income' ? 1 : -1) * toD(x['amount']),
          s.accCur(x['accId']?.toString()),
          (x['type'] == 'income' ? 1 : -1) * r2(s.tBase(x)),
          ((x['tags'] as List?) ?? const []).join(', '),
        ],
    ]
  ));
  if (cfg['bank'] == true) {
    for (final b in bankStatements(s, f, t)) {
      sheets.add((
        'Statement ${b.name}',
        [
          ['Date', 'Description', 'Debit (${b.cur})', 'Credit (${b.cur})', 'Balance (${b.cur})'],
          [f, 'Opening balance', null, null, round2(b.open)],
          for (final r in b.rows) [r.date, r.desc, r.debit == 0 ? null : r.debit, r.credit == 0 ? null : r.credit, round2(r.bal)],
          ['', 'Closing balance', round2(b.out), round2(b.inn), round2(b.close)],
        ]
      ));
    }
  }
  return buildXlsx(sheets);
}

/// All transactions as an Excel workbook (used by Backup & Restore "Export to Excel").
Uint8List buildAllTxXlsx(AppStore s) {
  final all = [...s.txns]..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
  return buildXlsx([
    (
      'Transactions',
      [
        ['Date', 'Time', 'Type', 'Kind', 'Description', 'Category', 'Wallet', 'Amount', 'Currency', 'Amount (${s.base})', 'Tags'],
        for (final x in all) ['${x['date']}', '${x['time'] ?? ''}', '${x['type']}', '${x['kind'] ?? 'normal'}', '${x['note'] ?? ''}', s.txTitle(x), s.accName(x['accId']), toD(x['amount']), s.accCur(x['accId']?.toString()), round2(s.tBase(x)), ((x['tags'] as List?) ?? const []).join(', ')],
      ]
    ),
    ('Accounts', [
      ['Account', 'Type', 'Currency', 'Balance'],
      for (final a in s.accounts) ['${a['name']}', '${a['type'] ?? 'wallet'}', '${a['currency']}', s.accBal(a)],
    ]),
  ]);
}
