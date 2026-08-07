import '../models/reminder.dart';
import '../services/reminders.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';

/// 設定。いまは通知だけ。
///
/// **増やす余地を作らない。** 通知の頻度は1日1通で固定してあり、
/// 画面から変えられるのは「使うかどうか」と「何時か」だけ。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.reminders});

  final Reminders reminders;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _on = false;
  int _hour = kDefaultReminderHour;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await widget.reminders.isEnabled();
    final h = await widget.reminders.hour();
    if (!mounted) return;
    setState(() {
      _on = on;
      _hour = h;
      _loading = false;
    });
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      // **押した時点で聞く。** 断られたら入にしない
      final ok = await widget.reminders.requestPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('端末の設定で通知が切られています。'),
          ));
        }
        return;
      }
    }
    await widget.reminders.setEnabled(on);
    if (mounted) setState(() => _on = on);
  }

  Future<void> _pickHour() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: 0),
      helpText: '何時に知らせますか',
    );
    if (picked == null) return;
    await widget.reminders.setHour(picked.hour);
    if (mounted) setState(() => _hour = picked.hour);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ReadableWidth(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    0, 8, 0, 8 + MediaQuery.paddingOf(context).bottom),
                children: [
                  SwitchListTile(
                    value: _on,
                    onChanged: _toggle,
                    title: const Text('まいにち知らせる'),
                    subtitle: const Text('1日1回だけ。残っているところをお知らせします。'),
                  ),
                  ListTile(
                    enabled: _on,
                    minTileHeight: 48,
                    leading: const Icon(Icons.schedule),
                    title: const Text('知らせる時刻'),
                    trailing: Text('$_hour:00', style: t.textTheme.titleMedium),
                    onTap: _on ? _pickHour : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'お知らせは1日1回までです。考査が近づいても増えません。\n'
                      '終わった日と、考査の前日・当日には送りません。',
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
