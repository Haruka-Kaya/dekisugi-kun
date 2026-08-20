import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/qr_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('カメラを開始できない時は用途を限定せず前画面への文字入力を案内する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: QrScanScreen(
          scannerBuilder: (context, onScanned) => const Center(
            child: Text(QrScanScreen.cameraUnavailableMessage),
          ),
        ),
      ),
    );
    expect(find.text(QrScanScreen.cameraUnavailableMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('qr-scan-cancel')), findsOneWidget);
  });

  testWidgets('QRを一度だけ返し、読み取り自体では次の操作をしない', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<String>(
                MaterialPageRoute<String>(
                  builder: (_) => QrScanScreen(
                    scannerBuilder: (context, onScanned) => Center(
                      child: FilledButton(
                        key: const ValueKey('fake-qr-result'),
                        onPressed: () => onScanned(' DKS1.example '),
                        child: const Text('読み取る'),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: const Text('開く'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.text('QRを読み取る'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fake-qr-result')));
    await tester.pumpAndSettle();

    expect(result, 'DKS1.example');
    expect(find.text('開く'), findsOneWidget);
  });
}
