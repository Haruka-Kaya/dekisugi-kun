import 'dart:async';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/reminder.dart';
import '../services/reminders.dart';
import '../ui/_material.dart';
import '../ui/adaptive.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';

/// 設定。いまは通知だけ。
///
/// **増やす余地を作らない。** 通知の頻度は1日1通で固定してあり、
/// 画面から変えられるのは「使うかどうか」と「何時か」だけ。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.reminders, this.onOpenPlus});

  final Reminders reminders;
  final Future<void> Function()? onOpenPlus;

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('端末の設定で通知が切られています。')));
        }
        return;
      }
    }
    await widget.reminders.setEnabled(on);
    if (mounted) setState(() => _on = on);
  }

  Future<void> _pickHour() async {
    final picked = await pickHour(
      context,
      initial: _hour,
      helpText: '何時に知らせますか',
    );
    if (picked == null) return;
    await widget.reminders.setHour(picked);
    if (mounted) setState(() => _hour = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _loading
          ? Center(
              child: Semantics(
                label: '設定を読み込んでいます',
                child: const CircularProgressIndicator(),
              ),
            )
          : ReadableWidth(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  const StudioPageIntro(
                    eyebrow: '毎日のペース',
                    title: '思い出すきっかけを、\nそっと一つだけ。',
                    body:
                        'デキすぎ君は、何度も呼び戻しません。'
                        '続きがある日に、1日1回だけ端末から知らせます。',
                  ),
                  const SizedBox(height: 22),
                  _ReminderStudio(
                    on: _on,
                    hour: _hour,
                    onToggle: _toggle,
                    onPickHour: _pickHour,
                  ),
                  if (widget.onOpenPlus case final openPlus?) ...[
                    const SizedBox(height: 24),
                    const StudioSectionHeader(
                      title: '会話の回数',
                      description: '無料の学び方は変えず、必要な人だけ回数を広げられます。',
                    ),
                    const SizedBox(height: 12),
                    StudioActionTile(
                      icon: Icons.forum_outlined,
                      title: 'デキすぎ君 Plus',
                      description: '無料は1日2会話。Plusは会話回数の上限なし',
                      onTap: () => unawaited(openPlus()),
                      warm: true,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.nights_stay_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '静かにしておく日',
                                style: t.textTheme.titleSmall?.jaWeight(
                                  FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'お知らせは1日1回までです。考査が近づいても増えません。\n'
                          '終わった日と、考査の前日・当日には送りません。',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReminderStudio extends StatelessWidget {
  const _ReminderStudio({
    required this.on,
    required this.hour,
    required this.onToggle,
    required this.onPickHour,
  });

  final bool on;
  final int hour;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickHour;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return Material(
      color: c.coolSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.stage),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.onCoolSurface.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Icon(Icons.notifications_none, color: c.onCoolSurface),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '続きの場所を、忘れない。',
                        style: t.textTheme.titleMedium
                            ?.copyWith(color: c.onCoolSurface)
                            .jaWeight(FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '通知の主語は「やり残しがある」という事実だけです。',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: c.onCoolSurface.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // **形が OS の記号になっている**ので合わせる
            SwitchListTile.adaptive(
              value: on,
              onChanged: onToggle,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'まいにち知らせる',
                style: t.textTheme.titleSmall
                    ?.copyWith(color: c.onCoolSurface)
                    .jaWeight(FontWeight.w700),
              ),
              subtitle: Text(
                '1日1回だけ。残っているところをお知らせします。',
                style: t.textTheme.bodySmall?.copyWith(
                  color: c.onCoolSurface.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _TimeNote(enabled: on, hour: hour, onTap: onPickHour),
          ],
        ),
      ),
    );
  }
}

class _TimeNote extends StatelessWidget {
  const _TimeNote({
    required this.enabled,
    required this.hour,
    required this.onTap,
  });

  final bool enabled;
  final int hour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final foreground = enabled
        ? c.onCoolSurface
        : c.onCoolSurface.withValues(alpha: 0.48);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: '知らせる時刻、$hour時',
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: Material(
        color: c.onCoolSurface.withValues(alpha: enabled ? 0.09 : 0.04),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.schedule, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '知らせる時刻',
                    style: t.textTheme.bodyMedium?.copyWith(color: foreground),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$hour:00',
                  style: t.textTheme.titleMedium
                      ?.copyWith(color: foreground)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined, size: 18, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
