import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

const _ipKey = 'server_ip';
const _notifyChannel = MethodChannel('com.pocketguard/notifications');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(PocketGuardApp(initialHost: prefs.getString(_ipKey) ?? ''));
}

class PocketGuardApp extends StatelessWidget {
  const PocketGuardApp({super.key, required this.initialHost});

  final String initialHost;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5EEAD4);
    return MaterialApp(
      title: 'PocketGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF12151C),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0D12),
        fontFamily: 'Roboto',
      ),
      home: DashboardPage(initialHost: initialHost),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.initialHost});

  final String initialHost;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _api = PocketGuardApi();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _time = DateFormat('dd MMM, h:mm a');

  late String _host;
  double _dailyTotal = 0;
  List<Expense> _expenses = const [];
  String? _error;
  bool _loading = false;
  bool _listenerEnabled = true;

  @override
  void initState() {
    super.initState();
    _host = widget.initialHost;
    _refreshListenerStatus();
    if (_host.isNotEmpty) {
      _loadExpenses();
    }
  }

  Future<void> _refreshListenerStatus() async {
    try {
      final enabled =
          await _notifyChannel.invokeMethod<bool>('isNotificationAccessEnabled');
      if (!mounted) return;
      setState(() => _listenerEnabled = enabled ?? false);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _listenerEnabled = true);
    }
  }

  Future<void> _loadExpenses() async {
    if (_host.trim().isEmpty) {
      setState(() {
        _error = 'Set your Mac’s local IP in Settings first.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _api.fetchExpenses(_host.trim());
      if (!mounted) return;
      setState(() {
        _dailyTotal = payload.dailyTotal;
        _expenses = payload.expenses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach http://${_host.trim()}:8000';
      });
    }
  }

  Future<void> _openSettings() async {
    final controller = TextEditingController(text: _host);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Server settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the local IPv4 address of the machine running the PocketGuard API. The Android listener posts notifications to this host over Wi-Fi.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(letterSpacing: 0.4),
                decoration: InputDecoration(
                  labelText: 'Mac local IP',
                  hintText: '192.168.1.24',
                  prefixIcon: const Icon(Icons.lan_outlined),
                  filled: true,
                  fillColor: const Color(0xFF101318),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Save IP and sync'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _notifyChannel.invokeMethod(
                      'openNotificationAccessSettings',
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Enable notification access'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (saved == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, saved);
    setState(() => _host = saved);
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF5EEAD4),
          onRefresh: _loadExpenses,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              if (!_listenerEnabled)
                SliverToBoxAdapter(child: _permissionBanner()),
              if (_error != null) SliverToBoxAdapter(child: _errorCard()),
              if (_expenses.isEmpty && _error == null && !_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  sliver: SliverList.separated(
                    itemCount: _expenses.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _TransactionTile(
                        expense: _expenses[index],
                        money: _money,
                        time: _time,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _loadExpenses,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: Text(_loading ? 'Syncing' : 'Sync'),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PocketGuard',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5EEAD4),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Local-first spending',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF143F3A), Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total spent today',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _money.format(_dailyTotal),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _host.isEmpty
                      ? 'No server IP saved'
                      : '$_host · ${_expenses.length} transactions',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _permissionBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: const Color(0xFF3F2A12),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: const Icon(Icons.lock_open),
          title: const Text('Notification access is off'),
          subtitle: const Text('Required for zero-touch capture.'),
          trailing: TextButton(
            onPressed: () {
              _notifyChannel.invokeMethod('openNotificationAccessSettings');
            },
            child: const Text('Enable'),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: const Color(0xFF3B1D27),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: const Icon(Icons.wifi_off_outlined),
          title: Text(_error ?? ''),
          subtitle: const Text('Pull to refresh or tap Sync.'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_moon_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No expenses yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Bank and UPI notifications will appear here after they are parsed on your local server.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.expense,
    required this.money,
    required this.time,
  });

  final Expense expense;
  final NumberFormat money;
  final DateFormat time;

  @override
  Widget build(BuildContext context) {
    final debit = expense.isDebit;
    final badgeColor = debit ? const Color(0xFFF87171) : const Color(0xFF34D399);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141821),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: badgeColor.withValues(alpha: 0.16),
            child: Icon(
              debit ? Icons.arrow_outward : Icons.call_received,
              color: badgeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.vendor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time.format(expense.timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${debit ? '-' : '+'}${money.format(expense.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: debit ? Colors.white : badgeColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  expense.type,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
