import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_language.dart';

/// 設定画面の言語切り替え。
///
/// 日本語 ⇄ English を選ぶと、表示言語・同梱教材カタログ・
/// サーバへの `?lang=` がまとめて切り替わる。選択は再起動を跨いで残る。
class AppLanguageTile extends StatelessWidget {
  const AppLanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppLanguageController?>();
    if (controller == null) return const SizedBox.shrink();
    // Providerの値はControllerの実体で変わらないので、
    // 切替通知はこのListenableBuilderが拾う。
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.translate_rounded),
        title: Text(t('表示言語', 'Language')),
        trailing: SegmentedButton<AppLanguage>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: AppLanguage.ja,
              label: Text(t('日本語', 'Japanese')),
            ),
            const ButtonSegment(value: AppLanguage.en, label: Text('EN')),
          ],
          selected: {controller.language},
          onSelectionChanged: (selection) {
            controller.setLanguage(selection.first);
          },
        ),
      ),
    );
  }
}
