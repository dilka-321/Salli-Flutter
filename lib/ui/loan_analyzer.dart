import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'analytics_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================================================================= loan maths
const kLoanTypes = ['Personal', 'Vehicle', 'Housing', 'Business', 'Microfinance', 'Other'];
const kTypicalRates = {'Personal': (12.0, 24.0), 'Vehicle': (8.0, 18.0), 'Housing': (7.0, 14.0), 'Business': (10.0, 20.0), 'Microfinance': (15.0, 36.0)};

double emiFor(double p, double ratePct, int n) {
  if (n <= 0 || p <= 0) return 0;
  final r = ratePct / 1200;
  if (r == 0) return p / n;
  return p * r * math.pow(1 + r, n) / (math.pow(1 + r, n) - 1);
}

/// Yearly rate (%) that gives this monthly instalment (0 when the instalment doesn't cover the amount).
double rateFromEmi(double p, double emi, int n) {
  if (p <= 0 || n <= 0 || emi * n <= p) return 0;
  var lo = 0.0, hi = 200.0;
  for (var i = 0; i < 80; i++) {
    final mid = (lo + hi) / 2;
    if (emiFor(p, mid, n) > emi) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return (lo + hi) / 2;
}

class LoanInput {
  LoanInput({required this.type, required this.amount, required this.months, required this.rate, this.income = 0, this.obligations = 0, this.fees = 0});
  final String type;
  final double amount, rate, income, obligations, fees;
  final int months;
}

class Factor {
  Factor(this.name, this.sub, this.grade);
  final String name, sub;
  final int grade; // 0 good, 1 fair, 2 poor
}

class LoanResult {
  LoanResult(this.i) {
    emi = emiFor(i.amount, i.rate, i.months);
    total = emi * i.months;
    interest = math.max(0.0, total - i.amount);
    endDate = addMonths(today(), i.months);
    final share = i.income > 0 ? emi / i.income : null;
    final burden = i.amount > 0 ? interest / i.amount : 0.0;
    final typ = kTypicalRates[i.type];
    factors = [
      Factor('Affordability', 'EMI as a share of income', share == null ? 1 : share <= .3 ? 0 : share <= .45 ? 1 : 2),
      Factor('Interest Burden', 'Total interest relative to principal', burden <= .2 ? 0 : burden <= .5 ? 1 : 2),
      Factor('Loan Term', 'Length of repayment period', i.months <= 60 ? 0 : i.months <= 120 ? 1 : 2),
      Factor('Interest Rate', 'Annual interest rate level', typ == null ? (i.rate <= 15 ? 0 : i.rate <= 25 ? 1 : 2) : (i.rate <= typ.$2 ? 0 : i.rate <= typ.$2 + 5 ? 1 : 2)),
    ];
    risk = factors.fold(0, (a, f) => a + f.grade);
    final dti = i.income > 0 ? (emi + i.obligations) / i.income : 0.0;
    status = risk <= 2 && dti <= .5 ? 'Safe' : risk <= 4 && dti <= .65 ? 'Caution' : 'Risky';
  }
  final LoanInput i;
  late final double emi, total, interest;
  late final String endDate, status;
  late final List<Factor> factors;
  late final int risk;
  double get cost => interest + i.fees;
  double get incomeShare => i.income > 0 ? emi / i.income : 0;

  /// (year, principal, interest, balance, months[(n, principal, interest, balance)])
  List<(int, double, double, double, List<(int, double, double, double)>)> schedule() {
    final out = <(int, double, double, double, List<(int, double, double, double)>)>[];
    var bal = i.amount;
    final r = i.rate / 1200;
    for (var y = 1; (y - 1) * 12 < i.months; y++) {
      var pp = 0.0, ip = 0.0;
      final ms = <(int, double, double, double)>[];
      for (var k = 0; k < 12 && (y - 1) * 12 + k < i.months; k++) {
        final it = bal * r;
        final pr = math.min(bal, emi - it);
        bal = math.max(0.0, bal - pr);
        pp += pr;
        ip += it;
        ms.add(((y - 1) * 12 + k + 1, pr, it, bal));
      }
      out.add((y, pp, ip, bal, ms));
    }
    return out;
  }
}

String _monthYear(String d) => fmtMonth(d.substring(0, 7));
Color _statusColor(Palette p, String st) => st == 'Safe' ? p.pos : st == 'Caution' ? p.warn : p.neg;

/// Number field with an (i) help bubble — like the web Loan Analyzer.
class _NumField extends StatelessWidget {
  const _NumField({required this.ctl, required this.label, required this.icon, this.help, this.onChanged});
  final TextEditingController ctl;
  final String label;
  final IconData icon;
  final String? help;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctl,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: help == null ? null : Tooltip(message: help!, triggerMode: TooltipTriggerMode.tap, showDuration: const Duration(seconds: 4), child: const Icon(Icons.info_outline_rounded, size: 19)),
          ),
        ),
      );
}

Widget _typeChips(Palette p, String? type, ValueChanged<String> on) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [for (final t in kLoanTypes) ChoiceChip(label: Text(t), selected: type == t, onSelected: (_) => on(t))]),
      if (type != null && kTypicalRates[type] != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: p.pos.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: p.pos),
            const SizedBox(width: 6),
            Text('Typical rates: ${kTypicalRates[type]!.$1.toStringAsFixed(0)}% - ${kTypicalRates[type]!.$2.toStringAsFixed(0)}% per year', style: TextStyle(color: p.pos, fontSize: 12.5)),
          ]),
        ),
    ]);

Widget _secLabel(Palette p, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(children: [Container(width: 3, height: 14, color: p.accent), const SizedBox(width: 8), Text(t, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 13))]),
    );

// ======================================================================= wizard
class LoanAnalyzerScreen extends StatefulWidget {
  const LoanAnalyzerScreen({super.key});
  @override
  State<LoanAnalyzerScreen> createState() => _LoanAnalyzerScreenState();
}

class _LoanAnalyzerScreenState extends State<LoanAnalyzerScreen> {
  int step = 0;
  String? type;
  bool years = false;
  final amount = TextEditingController(), term = TextEditingController(), rate = TextEditingController(), inst = TextEditingController();
  final income = TextEditingController(), oblig = TextEditingController(), fees = TextEditingController();
  String? err;

  @override
  void dispose() {
    for (final c in [amount, term, rate, inst, income, oblig, fees]) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) => parseAmount(c.text) ?? 0;
  int get _months => (years ? _v(term) * 12 : _v(term)).round();
  double get _rate {
    final r = _v(rate);
    if (r > 0) return r;
    return rateFromEmi(_v(amount), _v(inst), _months);
  }

  LoanInput get _input => LoanInput(type: type ?? 'Other', amount: _v(amount), months: _months, rate: _rate, income: _v(income), obligations: _v(oblig), fees: _v(fees));

  void _next() {
    String? e;
    if (step == 0) {
      if (_v(amount) <= 0) {
        e = 'Enter the loan amount.';
      } else if (_months <= 0) {
        e = 'Enter the loan term.';
      } else if (_v(rate) <= 0 && _v(inst) <= 0) {
        e = 'Enter the interest rate or the monthly installment.';
      } else if (_v(rate) <= 0 && _rate <= 0 && _v(inst) * _months < _v(amount)) {
        e = 'The monthly installment is too small to repay this amount in ${_months} months.';
      }
    }
    if (e != null) return setState(() => err = e);
    FocusScope.of(context).unfocus();
    if (step < 2) {
      HapticFeedback.selectionClick();
      return setState(() {
        step++;
        err = null;
      });
    }
    Navigator.of(context).push(pageRoute(LoanAnalysisScreen(input: _input)));
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    const steps = ['Loan Basics', 'Your Finances', 'Review & Analyze'];
    final body = <Widget>[];
    if (step == 0) {
      body.addAll([
        _secLabel(p, 'Loan Type'),
        _typeChips(p, type, (t) => setState(() => type = t)),
        _secLabel(p, 'Loan Details'),
        _NumField(ctl: amount, label: 'Loan Amount', icon: Icons.account_balance_rounded, help: 'The total amount you are borrowing'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _NumField(ctl: term, label: 'Loan Term (${years ? 'years' : 'months'})', icon: Icons.schedule_rounded, help: 'How long you will be repaying this loan')),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: false, label: Text('Mo')), ButtonSegment(value: true, label: Text('Yr'))],
              selected: {years},
              onSelectionChanged: (v) => setState(() => years = v.first),
            ),
          ),
        ]),
        _NumField(ctl: rate, label: 'Interest Rate (%)', icon: Icons.percent_rounded, help: 'Yearly interest rate offered by the lender', onChanged: (_) => setState(() {})),
        Center(child: Text('OR', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        _NumField(ctl: inst, label: 'Monthly Installment', icon: Icons.receipt_long_rounded, help: 'If you know the fixed monthly payment but not the rate, enter it here. The rate will be back-calculated.', onChanged: (_) => setState(() {})),
        if (_v(rate) <= 0 && _v(inst) > 0 && _rate > 0) Text('Calculated interest rate: ${_rate.toStringAsFixed(2)}% per year', style: TextStyle(color: p.pos, fontSize: 12.5)),
      ]);
    } else if (step == 1) {
      body.addAll([
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.pos.withOpacity(.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [Icon(Icons.info_outline_rounded, color: p.pos, size: 18), const SizedBox(width: 8), Expanded(child: Text('Help us understand your current financial commitments', style: TextStyle(color: p.pos, fontSize: 13)))]),
        ),
        _secLabel(p, 'Your Finances'),
        _NumField(ctl: income, label: 'Your Monthly Income', icon: Icons.payments_outlined, help: 'Your total monthly income before deductions'),
        _NumField(ctl: oblig, label: 'Existing Monthly Obligations - Optional', icon: Icons.receipt_outlined, help: 'Other monthly loan payments, rent, or fixed commitments you already have'),
      ]);
    } else {
      final i = _input;
      final e = emiFor(i.amount, i.rate, i.months);
      body.addAll([
        _secLabel(p, 'Optional Details'),
        _NumField(ctl: fees, label: 'Processing Fees / One-time Charges - Optional', icon: Icons.request_quote_outlined, help: 'Any upfront fees charged by the lender (processing, documentation, insurance)'),
        _secLabel(p, 'Review Summary'),
        GlassCard(
          child: Column(children: [
            for (final r in [
              ('Loan Amount', moneyB(s, i.amount), 0),
              ('Loan Term', '${i.months} Mo', 0),
              ('Interest Rate', '${i.rate.toStringAsFixed(2)}%', 0),
              ('Monthly EMI', moneyB(s, e), -1),
              ('Loan Type', type ?? 'Other', 0),
              if (i.income > 0) ('Your Monthly Income', moneyB(s, i.income), 1),
              if (i.obligations > 0) ('Existing Monthly Obligations', moneyB(s, i.obligations), 1),
              if (i.fees > 0) ('Processing Fees', moneyB(s, i.fees), 2),
            ])
              Row(children: [
                Expanded(child: kvRow(p, r.$1, r.$2)),
                if (r.$3 >= 0) IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.edit_outlined, size: 17, color: p.muted), onPressed: () => setState(() => step = r.$3)),
              ]),
          ]),
        ),
      ]);
    }
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => step--);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Loan Analyzer'), actions: [
          IconButton(tooltip: 'Compare loans', icon: const Icon(Icons.compare_arrows_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const CompareLoansScreen()))),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(children: [
              if (step > 0) ...[Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => step--), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back'))), const SizedBox(width: 12)],
              Expanded(child: FilledButton.icon(onPressed: _next, icon: Icon(step < 2 ? Icons.arrow_forward_rounded : Icons.analytics_outlined), label: Text(step < 2 ? 'Next' : 'Analyze'))),
            ]),
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
          Row(children: [
            for (var k = 0; k < 3; k++) ...[
              if (k > 0) Expanded(child: Container(height: 2, color: k <= step ? p.accent : p.line)),
              Column(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 250), width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: k <= step ? p.accent : Colors.transparent, border: Border.all(color: k <= step ? p.accent : p.muted, width: 2))),
                const SizedBox(height: 4),
                Text(steps[k], style: TextStyle(fontSize: 11, color: k == step ? p.accent : p.muted, fontWeight: k == step ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ],
          ]),
          const SizedBox(height: 6),
          AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: Column(key: ValueKey(step), crossAxisAlignment: CrossAxisAlignment.stretch, children: body)),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: p.neg, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

// ======================================================================= result
class LoanAnalysisScreen extends StatefulWidget {
  const LoanAnalysisScreen({super.key, required this.input});
  final LoanInput input;
  @override
  State<LoanAnalysisScreen> createState() => _LoanAnalysisScreenState();
}

class _LoanAnalysisScreenState extends State<LoanAnalysisScreen> {
  String tab = 'overview';
  bool why = false;
  final open = <int>{};
  final extra = TextEditingController();

  @override
  void dispose() {
    extra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final r = LoanResult(widget.input);
    final i = r.i;
    final sc = _statusColor(p, r.status);
    String B(num v) => moneyB(s, v);
    final yrs = (i.months / 12);
    final yrsTxt = i.months % 12 == 0 ? '${yrs.round()} year${yrs.round() > 1 ? 's' : ''}' : '${i.months} months';
    final pctInt = r.total > 0 ? r.interest / (i.amount + r.interest) * 100 : 0.0;
    final insights = <(bool, String)>[
      (false, 'You will pay ${B(r.interest)} extra as interest.'),
      if (i.income > 0) (false, 'This loan takes up ${(r.incomeShare * 100).toStringAsFixed(1)}% of your monthly income.'),
      (false, 'This loan ends in ${_monthYear(r.endDate)}.'),
      if (i.fees > 0 && i.fees >= i.amount * .02) (true, 'Processing fees of ${B(i.fees)} add significantly to your loan cost.'),
      if (i.income > 0 && (r.emi + i.obligations) / i.income > .5) (true, 'Your loan payments would take more than half of your income. Consider a smaller amount or a longer term.'),
      (
        r.status != 'Safe',
        r.status == 'Safe'
            ? 'This loan is within comfortable limits. Maintain an emergency fund.'
            : r.status == 'Caution'
                ? 'This loan is manageable but leaves less room for savings. Compare other offers first.'
                : 'This loan looks risky for your budget. Try a lower amount, a longer term or a better rate.'
      ),
    ];
    final ex = parseAmount(extra.text) ?? 0;
    int? exMonths;
    var exInterest = 0.0;
    if (ex > 0 && r.emi > 0) {
      var bal = i.amount, m = 0;
      final rr = i.rate / 1200;
      while (bal > .01 && m < 1200) {
        final it = bal * rr;
        exInterest += it;
        bal = bal + it - (r.emi + ex);
        m++;
      }
      exMonths = m;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Analysis')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Column(children: [
            Row(children: [
              Badge2('✓ ${r.status}', color: sc),
              const Spacer(),
              Text('Loan ends ${_monthYear(r.endDate)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ]),
            const SizedBox(height: 10),
            Text('${B(r.emi.round())}/mo', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'overview', label: Text('Overview')), ButtonSegment(value: 'analysis', label: Text('Analysis'))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 12),
        if (tab == 'overview') ...[
          GlassCard(child: Row(children: [Icon(Icons.description_outlined, color: p.pos), const SizedBox(width: 10), Expanded(child: Text('You\'ll pay ${B(r.cost.round())} extra over $yrsTxt, ending in ${_monthYear(r.endDate)}'))])),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Principal vs Interest', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(
                height: 200,
                child: Stack(alignment: Alignment.center, children: [
                  PieDonut(parts: [(i.amount, p.pos), (r.interest, p.neg)]),
                  Column(mainAxisSize: MainAxisSize.min, children: [Text('${pctInt.round()}%', style: TextStyle(color: p.neg, fontSize: 22, fontWeight: FontWeight.w800)), Text('Interest', style: TextStyle(color: p.muted, fontSize: 12))]),
                ]),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.circle, size: 9, color: p.pos),
                Text(' Principal ${B(i.amount)}   ', style: const TextStyle(fontSize: 12)),
                Icon(Icons.circle, size: 9, color: p.neg),
                Text(' Interest ${B(r.interest)}', style: const TextStyle(fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(r.status == 'Safe' ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: sc, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.status.toUpperCase(), style: TextStyle(color: sc, fontWeight: FontWeight.w800)),
                    Text(r.status == 'Safe' ? 'This loan is within comfortable limits.' : r.status == 'Caution' ? 'This loan needs care — check the factors below.' : 'This loan may strain your budget.', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ]),
                ),
                ActionChip(label: Text('Why? ${why ? '▴' : '▾'}'), onPressed: () => setState(() => why = !why)),
              ]),
              if (why) ...[
                const SizedBox(height: 8),
                for (final f in r.factors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.circle, size: 7, color: [p.pos, p.warn, p.neg][f.grade]),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(f.sub, style: TextStyle(color: p.muted, fontSize: 11.5))])),
                      Badge2(['Good', 'Fair', 'Poor'][f.grade], color: [p.pos, p.warn, p.neg][f.grade]),
                    ]),
                  ),
                Text('Risk Score: ${r.risk}/8', style: TextStyle(color: p.muted, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          tileGrid([
            InfoTile(icon: Icons.account_balance_wallet_outlined, label: 'Total Payment', value: B(r.total), color: p.pos, valueColor: p.pos),
            InfoTile(icon: Icons.trending_up_rounded, label: 'Total Interest · ${(i.amount > 0 ? r.interest / i.amount * 100 : 0).toStringAsFixed(1)}% of loan', value: B(r.interest), color: p.neg, valueColor: p.neg),
          ]),
          if (i.income > 0) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Builder(builder: (_) {
                final rem = math.max(0.0, i.income - r.emi - i.obligations);
                final parts = [('This Loan EMI', r.emi, p.neg), ('Other Obligations', i.obligations, p.warn), ('Remaining Income', rem, p.line)];
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Income Breakdown', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(height: 14, child: Row(children: [for (final x in parts) if (x.$2 > 0) Expanded(flex: math.max(1, (x.$2 / i.income * 1000).round()), child: Container(color: x.$3))])),
                  ),
                  const SizedBox(height: 8),
                  for (final x in parts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Container(width: 9, height: 9, color: x.$3),
                        const SizedBox(width: 8),
                        Expanded(child: Text(x.$1, style: const TextStyle(fontSize: 12.5))),
                        Text(B(x.$2.round()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        Text('  ${(x.$2 / i.income * 100).toStringAsFixed(1)}%', style: TextStyle(color: p.muted, fontSize: 11.5)),
                      ]),
                    ),
                ]);
              }),
            ),
          ],
          const SectionTitle('Insights'),
          for (final x in insights)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: x.$1 ? p.warn.withOpacity(.12) : p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: x.$1 ? p.warn.withOpacity(.4) : p.line)),
              child: Row(children: [Icon(x.$1 ? Icons.warning_amber_rounded : Icons.info_outline_rounded, size: 18, color: x.$1 ? p.warn : p.pos), const SizedBox(width: 10), Expanded(child: Text(x.$2, style: const TextStyle(fontSize: 13)))]),
            ),
        ] else ...[
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [Icon(Icons.calendar_month_rounded, size: 20), SizedBox(width: 8), Text('Amortization Schedule', style: TextStyle(fontWeight: FontWeight.w800))]),
              const SizedBox(height: 8),
              Row(children: [
                for (final h in ['Year', 'Principal', 'Interest', 'Balance']) Expanded(child: Text(h, textAlign: h == 'Year' ? TextAlign.left : TextAlign.right, style: TextStyle(color: p.muted, fontSize: 11.5))),
              ]),
              const Divider(),
              for (final y in r.schedule()) ...[
                InkWell(
                  onTap: () => setState(() => open.contains(y.$1) ? open.remove(y.$1) : open.add(y.$1)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text('${open.contains(y.$1) ? '▾' : '▸'} ${y.$1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                      Expanded(child: Text(B(y.$2.round()), textAlign: TextAlign.right, style: TextStyle(color: p.pos, fontSize: 12.5))),
                      Expanded(child: Text(B(y.$3.round()), textAlign: TextAlign.right, style: TextStyle(color: p.neg, fontSize: 12.5))),
                      Expanded(child: Text(B(y.$4.round()), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
                    ]),
                  ),
                ),
                if (open.contains(y.$1))
                  for (final m in y.$5)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text('   Month ${m.$1}', style: TextStyle(color: p.muted, fontSize: 11.5))),
                        Expanded(child: Text(B(m.$2.round()), textAlign: TextAlign.right, style: TextStyle(color: p.muted, fontSize: 11.5))),
                        Expanded(child: Text(B(m.$3.round()), textAlign: TextAlign.right, style: TextStyle(color: p.muted, fontSize: 11.5))),
                        Expanded(child: Text(B(m.$4.round()), textAlign: TextAlign.right, style: TextStyle(color: p.muted, fontSize: 11.5))),
                      ]),
                    ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Pay extra each month', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(controller: extra, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Extra monthly payment', hintText: '0')),
              if (exMonths != null) ...[
                kvRow(p, 'Paid off in', '$exMonths months (${math.max(0, i.months - exMonths)} sooner)'),
                kvRow(p, 'Interest saved', B(math.max(0.0, r.interest - exInterest)), color: p.pos),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

// ======================================================================= compare
class _LoanForm {
  String? type;
  final amount = TextEditingController(), term = TextEditingController(), rate = TextEditingController(), income = TextEditingController(), oblig = TextEditingController(), fees = TextEditingController();
  double _v(TextEditingController c) => parseAmount(c.text) ?? 0;
  bool get ok => _v(amount) > 0 && _v(term) > 0;
  LoanInput get input => LoanInput(type: type ?? 'Other', amount: _v(amount), months: _v(term).round(), rate: _v(rate), income: _v(income), obligations: _v(oblig), fees: _v(fees));
  void dispose() {
    for (final c in [amount, term, rate, income, oblig, fees]) {
      c.dispose();
    }
  }
}

class CompareLoansScreen extends StatefulWidget {
  const CompareLoansScreen({super.key});
  @override
  State<CompareLoansScreen> createState() => _CompareLoansScreenState();
}

class _CompareLoansScreenState extends State<CompareLoansScreen> {
  final f = [_LoanForm(), _LoanForm()];
  int tab = 0;
  bool show = false;

  @override
  void dispose() {
    for (final x in f) {
      x.dispose();
    }
    super.dispose();
  }

  void _compare() {
    FocusScope.of(context).unfocus();
    for (var k = 0; k < 2; k++) {
      if (!f[k].ok) {
        setState(() {
          tab = k;
          show = false;
        });
        return toast(context, 'Enter the amount and term for Loan ${k == 0 ? 'A' : 'B'}');
      }
    }
    setState(() => show = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    String B(num v) => moneyB(s, v);
    final x = f[tab];
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Loans')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: FilledButton(onPressed: _compare, child: const Text('Compare')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 0, label: Text('Loan A')), ButtonSegment(value: 1, label: Text('Loan B'))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        Column(key: ValueKey('form$tab'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _secLabel(p, 'Loan Type'),
          _typeChips(p, x.type, (t) => setState(() => x.type = t)),
          const SizedBox(height: 12),
          _NumField(ctl: x.amount, label: 'Loan Amount', icon: Icons.account_balance_rounded),
          _NumField(ctl: x.term, label: 'Loan Term (months)', icon: Icons.schedule_rounded),
          _NumField(ctl: x.rate, label: 'Interest Rate (%)', icon: Icons.percent_rounded),
          _NumField(ctl: x.income, label: 'Your Monthly Income', icon: Icons.payments_outlined),
          _NumField(ctl: x.oblig, label: 'Existing Monthly Obligations - Optional', icon: Icons.receipt_outlined),
          _NumField(ctl: x.fees, label: 'Processing Fees / One-time Charges - Optional', icon: Icons.attach_money_rounded),
        ]),
        if (show && f[0].ok && f[1].ok)
          Builder(builder: (_) {
            final a = LoanResult(f[0].input), b = LoanResult(f[1].input);
            Widget row(String k, String va, String vb, int better) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text(k, style: TextStyle(color: p.muted, fontSize: 12.5))),
                    Expanded(flex: 3, child: Text(va, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: better == 0 ? p.pos : null))),
                    Expanded(flex: 3, child: Text(vb, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: better == 1 ? p.pos : null))),
                  ]),
                );
            int low(double x, double y) => (x - y).abs() < .005 ? -1 : (x < y ? 0 : 1);
            final ca = a.total + a.i.fees, cb = b.total + b.i.fees;
            final win = low(ca, cb);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Comparison', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  row('', 'Loan A', 'Loan B', -1),
                  const Divider(height: 8),
                  row('Monthly EMI', B(a.emi.round()), B(b.emi.round()), low(a.emi, b.emi)),
                  row('Total interest', B(a.interest.round()), B(b.interest.round()), low(a.interest, b.interest)),
                  row('Fees', B(a.i.fees), B(b.i.fees), low(a.i.fees, b.i.fees)),
                  row('Total cost', B(ca.round()), B(cb.round()), win),
                  row('Interest rate', '${a.i.rate.toStringAsFixed(2)}%', '${b.i.rate.toStringAsFixed(2)}%', low(a.i.rate, b.i.rate)),
                  row('Term', '${a.i.months} mo', '${b.i.months} mo', -1),
                  if (a.i.income > 0 || b.i.income > 0) row('EMI share of income', a.i.income > 0 ? '${(a.incomeShare * 100).toStringAsFixed(1)}%' : '—', b.i.income > 0 ? '${(b.incomeShare * 100).toStringAsFixed(1)}%' : '—', -1),
                  row('Ends', _monthYear(a.endDate), _monthYear(b.endDate), -1),
                  row('Status', a.status, b.status, a.risk == b.risk ? -1 : (a.risk < b.risk ? 0 : 1)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.pos.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      win == -1 ? 'Both loans cost about the same overall.' : 'Loan ${win == 0 ? 'A' : 'B'} costs ${B((ca - cb).abs().round())} less overall.',
                      style: TextStyle(color: p.pos, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).push(pageRoute(LoanAnalysisScreen(input: a.i))), child: const Text('Analyze A'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).push(pageRoute(LoanAnalysisScreen(input: b.i))), child: const Text('Analyze B'))),
                  ]),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}
