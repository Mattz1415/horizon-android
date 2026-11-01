import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final o = app.options;
    final d = app.device;
    final cores = (d?['cores'] as num?)?.toInt() ?? 8;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Stagger(children: [
          const PageHeader(
            title: 'Pengaturan',
            lead: 'Disimpan langsung ke options.txt dan horizon-graphics.txt, jadi menu di dalam game ikut berubah.',
          ),
          LayoutBuilder(builder: (context, c) {
            final two = c.maxWidth >= 820;
            final look = _group('Tampilan launcher', [
              Text('Tema', style: Hz.body.copyWith(color: Hz.ink)),
              const SizedBox(height: 4),
              Text('Otomatis memakai Siang dari jam 06.00 sampai 18.00, Malam di luar itu.', style: Hz.small),
              const SizedBox(height: 8),
              Segmented<String>(
                options: const [('auto', 'Otomatis'), ('malam', 'Malam'), ('siang', 'Siang'), ('samudra', 'Samudra')],
                value: app.theme,
                onChanged: app.setTheme,
              ),
            ]);
            final view = _group('Tampilan dunia', [
              SliderRow(
                label: 'Jarak render',
                hint: 'Chunk yang dimuat penuh di sekitar pemain.',
                value: o.renderDistance.toDouble(),
                min: 2,
                max: 64,
                divisions: 62,
                format: (v) => '${v.round()} chunk',
                onChanged: (v) => app.updateOptions((o) => o.renderDistance = v.round()),
              ),
              SliderRow(
                label: 'Jarak simulasi',
                hint: 'Sejauh mana mob dan tanaman tetap bergerak. Tidak bisa melebihi jarak render.',
                value: o.simulationDistance.toDouble(),
                min: 2,
                max: 32,
                divisions: 30,
                format: (v) => '${v.round()} chunk',
                onChanged: (v) => app.updateOptions((o) => o.simulationDistance = v.round().clamp(2, o.renderDistance.clamp(2, 32))),
              ),
              SliderRow(
                label: 'Jarak LOD',
                hint: 'Medan jauh versi sederhana di luar jarak render. 0 berarti mati.',
                value: o.lodDistance.toDouble(),
                min: 0,
                max: 1024,
                divisions: 64,
                format: (v) => v == 0 ? 'Mati' : '${v.round()} chunk',
                onChanged: (v) => app.updateOptions((o) => o.lodDistance = v.round()),
              ),
              SliderRow(
                label: 'Bidang pandang',
                value: o.fov.toDouble(),
                min: 30,
                max: 110,
                divisions: 80,
                format: (v) => v.round() == 70 ? 'Normal (70)' : '${v.round()}°',
                onChanged: (v) => app.updateOptions((o) => o.fov = v.round()),
              ),
            ]);
            final perf = _group('Performa', [
              SliderRow(
                label: 'FPS maksimum',
                value: o.maxFps.toDouble(),
                min: 10,
                max: 260,
                divisions: 25,
                format: (v) => v >= 260 ? 'Tanpa batas' : '${v.round()}',
                onChanged: (v) => app.updateOptions((o) => o.maxFps = v.round()),
              ),
              SliderRow(
                label: 'Skala GUI',
                value: o.guiScale.toDouble(),
                min: 0,
                max: 6,
                divisions: 6,
                format: (v) => v == 0 ? 'Otomatis' : '${v.round()}x',
                onChanged: (v) => app.updateOptions((o) => o.guiScale = v.round()),
              ),
              Text('Info performa di layar', style: Hz.body.copyWith(color: Hz.ink)),
              const SizedBox(height: 8),
              Segmented<String>(
                options: const [('off', 'Mati'), ('fps', 'Angka FPS'), ('graph', 'Grafik')],
                value: o.overlay,
                onChanged: (v) => app.updateOptions((o) => o.overlay = v),
              ),
              const SizedBox(height: 16),
              SliderRow(
                label: 'Thread pekerja',
                hint: 'Thread untuk membangun chunk. Perangkat ini punya $cores inti.',
                value: app.workerThreads.toDouble().clamp(1, cores.toDouble()),
                min: 1,
                max: cores.toDouble().clamp(2, 16),
                divisions: (cores.clamp(2, 16) - 1),
                onChanged: (v) => app.setThreads(v.round()),
              ),
            ]);
            final controls = _group('Grafis dan kontrol', [
              Text('API grafis', style: Hz.body.copyWith(color: Hz.ink)),
              const SizedBox(height: 4),
              Text('Pilih OpenGL ES kalau game keluar sendiri atau layar hitam di Vulkan.', style: Hz.small),
              const SizedBox(height: 8),
              Segmented<String>(
                options: const [('vulkan', 'Vulkan'), ('opengl', 'OpenGL ES')],
                value: app.backend,
                onChanged: app.setBackend,
              ),
              const SizedBox(height: 18),
              Text('Skema sentuh', style: Hz.body.copyWith(color: Hz.ink)),
              const SizedBox(height: 8),
              for (final (i, label) in const [
                (0, 'Joystick, bidik dengan crosshair'),
                (1, 'Joystick, ketuk untuk berinteraksi'),
                (2, 'D-Pad, ketuk untuk berinteraksi'),
                (3, 'D-Pad, bidik dengan crosshair'),
              ])
                _Radio(label: label, selected: app.touchScheme == i, onTap: () => app.setTouch(i)),
              const SizedBox(height: 4),
              Text('Tata letak tombol bisa digeser dari menu sentuh di dalam game.', style: Hz.small),
            ]);
            final device = _group('Perangkat', [
              if (d == null)
                Text('Memuat info perangkat...', style: Hz.small)
              else
                Wrap(spacing: 28, runSpacing: 14, children: [
                  Fact(label: 'Model', value: '${d['model']}'),
                  Fact(label: 'Android', value: '${d['android']} (API ${d['sdk']})'),
                  Fact(label: 'ABI', value: '${d['abi']}'),
                  Fact(label: 'Inti CPU', value: '${d['cores']}'),
                  Fact(label: 'RAM', value: '${formatBytes((d['availRam'] as num?) ?? 0)} bebas dari ${formatBytes((d['totalRam'] as num?) ?? 0)}'),
                  Fact(label: 'Penyimpanan bebas', value: formatBytes((d['freeStorage'] as num?) ?? 0)),
                  Fact(label: 'File game', value: formatBytes((d['resourcesSize'] as num?) ?? 0)),
                  Fact(label: 'Data pemain', value: formatBytes((d['gameDataSize'] as num?) ?? 0)),
                ]),
            ]);
            if (!two) {
              return Column(children: [look, const SizedBox(height: 12), view, const SizedBox(height: 12), perf, const SizedBox(height: 12), controls, const SizedBox(height: 12), device]);
            }
            return Column(children: [
              look,
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: view),
                const SizedBox(width: 12),
                Expanded(child: perf),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: controls),
                const SizedBox(width: 12),
                Expanded(child: device),
              ]),
            ]);
          }),
        ]),
      ],
    );
  }

  Widget _group(String title, List<Widget> children) => Plate(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Hz.title.copyWith(fontSize: 15)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: Hz.r10,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(children: [
            AnimatedContainer(
              duration: Hz.quick,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Hz.accent : Hz.muted, width: 2),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: Hz.quick,
                  width: selected ? 10 : 0,
                  height: selected ? 10 : 0,
                  decoration: BoxDecoration(color: Hz.accent, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Hz.body.copyWith(color: selected ? Hz.ink : Hz.inkSoft))),
          ]),
        ),
      ),
    );
  }
}
