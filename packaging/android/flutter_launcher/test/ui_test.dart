import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizon_launcher/main.dart';

const _channel = MethodChannel('com.vasysik.horizon/launcher');

const _registry = '{"schema":1,"projects":['
    '{"id":"compass_bar","kind":"mod","name":"Compass Enhanced","summary":"A compass bar with degrees.","authors":["Isaac"],"downloads":1334,'
    '"versions":[{"version":"0.1.0","file":{"name":"compass_bar-0.1.0.hmod","url":"https://example.invalid/c.hmod","size":47628,"sha256":"bb"}}]},'
    '{"id":"coords_hud","kind":"native-mod","name":"Coordinates HUD","summary":"Your coordinates in a corner.","authors":["Horizon"],"downloads":2077,'
    '"versions":[{"version":"2.0.0","file":{"name":"coords_hud-2.0.0.hnmod","url":"https://example.invalid/h.hnmod","size":9000,"sha256":"cc"}}]}'
    '],"revoked":[]}';

Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Geist', ['Geist-Regular.ttf', 'Geist-Medium.ttf', 'Geist-SemiBold.ttf']),
    ('GeistMono', ['GeistMono-Regular.ttf']),
    ('PixelifySans', ['PixelifySans-SemiBold.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'checkResources':
          return {'isPrepared': true, 'sha256': 'a1b2c3d4e5f6a7b8'};
        case 'getLauncherSettings':
          return '{"account":"Idris"}';
        case 'getAccounts':
          return '["Idris","Steve"]';
        case 'getGameOptions':
          return {'renderDistance': 24, 'simulationDistance': 12, 'maxFps': 120, 'fov': 70, 'lodDistance': 128, 'overlay': 'fps'};
        case 'getMods':
          return [
            {'type': 'mod', 'fileName': 'minimap.hmod', 'name': 'Minimap', 'version': '1.0.0', 'description': 'A map of the terrain around you.', 'size': 120000, 'enabled': true},
            {'type': 'mod', 'fileName': 'zoom.hmod.disabled', 'name': 'Zoom', 'version': '1.0.0', 'description': 'Hold a key to zoom in.', 'size': 90000, 'enabled': false},
            {'type': 'shader', 'fileName': 'golden-hour.hshader', 'name': 'Golden Hour', 'version': '1.0.0', 'description': '', 'size': 2980, 'enabled': true},
            {'type': 'pack', 'fileName': 'programmer-art.zip', 'name': 'programmer-art', 'size': 255, 'enabled': false, 'broken': true},
          ];
        case 'getWorlds':
          return [
            {'name': 'Survival 1', 'modified': DateTime.now().millisecondsSinceEpoch - 3600000, 'size': 48000000},
            {'name': 'Creative test', 'modified': DateTime.now().millisecondsSinceEpoch - 86400000 * 3, 'size': 9000000},
          ];
        case 'getDeviceInfo':
          return {'model': 'Test Phone', 'android': '14', 'sdk': 34, 'abi': 'arm64-v8a', 'cores': 8, 'totalRam': 8e9, 'availRam': 3e9, 'freeStorage': 40e9, 'gameDataSize': 60e6, 'resourcesSize': 790e6};
        case 'fetchRegistry':
          return {'json': _registry, 'cached': false, 'fetched': DateTime.now().millisecondsSinceEpoch};
        case 'getScreenshots':
          return <Map>[];
        case 'notificationsAllowed':
          return true;
        case 'requestNotifications':
          return true;
        case 'openUrl':
          return true;
        case 'getLogs':
          return {'latest': '[main/INFO] Horizon start\n[main/INFO] World loaded', 'latestModified': DateTime.now().millisecondsSinceEpoch, 'crash': '', 'crashModified': 0};
      }
      return null;
    });
  });

  for (final size in const [Size(800, 360), Size(1280, 600)]) {
    for (final (i, name) in const [(0, 'play'), (1, 'addons'), (2, 'worlds'), (3, 'profile'), (4, 'settings'), (5, 'logs')]) {
      testWidgets('$name at ${size.width.toInt()}x${size.height.toInt()} has no overflow', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const HorizonApp());
        await tester.pump(const Duration(milliseconds: 100));
        if (i > 0) {
          await tester.tap(find.byKey(ValueKey('nav-$i')));
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        if (Platform.environment['SHOTS'] == '1') {
          await expectLater(find.byType(HorizonApp), matchesGoldenFile('shots/${name}_${size.width.toInt()}.png'));
        }
      });
    }
  }

  testWidgets('reduced motion still shows every page', (tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(size: Size(800, 360), disableAnimations: true),
      child: HorizonApp(),
    ));
    await tester.pump();
    expect(find.text('Idris'), findsWidgets);
    for (var i = 1; i < 6; i++) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('registry tab marks native mods as desktop only', (tester) async {
    tester.view.physicalSize = const Size(2560, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HorizonApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Katalog Horizon'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Compass Enhanced'), findsOneWidget);
    expect(find.text('Hanya desktop'), findsOneWidget);
    expect(find.text('Pasang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme button cycles without errors', (tester) async {
    tester.view.physicalSize = const Size(2560, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HorizonApp());
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Tema')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('play console shows device performance facts and account details', (tester) async {
    tester.view.physicalSize = const Size(2560, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HorizonApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Idris'), findsWidgets);
    expect(find.text('Vulkan'), findsWidgets);
    expect(find.textContaining('Inti CPU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
