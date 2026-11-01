import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizon_launcher/main.dart';

const _channel = MethodChannel('com.vasysik.horizon/launcher');

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
    expect(find.text('Halo, Idris'), findsOneWidget);
  });
}
