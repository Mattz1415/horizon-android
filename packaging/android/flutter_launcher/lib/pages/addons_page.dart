import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

const _release = 'https://github.com/Mattz1415/horizon-android/releases/latest/download';

class CatalogItem {
  const CatalogItem(this.type, this.file, this.name, this.blurb);

  final String type;
  final String file;
  final String name;
  final String blurb;

  String get url => '$_release/$file';
}

/// Only things built from this repository: the official mods in mods/official and the
/// shader packs in the release. Descriptions are shortened from each manifest.
const catalog = [
  CatalogItem('mod', 'fps-overlay.hmod', 'FPS Counter',
      'Frame per detik di pojok layar, bisa ditambah frame paling lambat dan 1% low.'),
  CatalogItem('mod', 'minimap.hmod', 'Minimap',
      'Peta medan di sekitar kamu di pojok layar, kotak atau bulat.'),
  CatalogItem('mod', 'zoom.hmod', 'Zoom', 'Tahan tombol untuk memperbesar pandangan.'),
  CatalogItem('mod', 'keystrokes.hmod', 'Keystrokes',
      'Tombol gerak dan klik yang sedang ditekan, dengan klik per detik.'),
  CatalogItem('mod', 'far-view.hmod', 'Far View',
      'Medan jauh di luar jarak render digambar sederhana, tanpa memuat chunk tambahan.'),
  CatalogItem('mod', 'recipes.hmod', 'Recipes',
      'Daftar semua item di samping inventaris, dengan pencarian resep dan kegunaan.'),
  CatalogItem('shader', 'golden-hour.hshader', 'Golden Hour',
      'Cahaya hangat saat matahari terbit dan terbenam, dengan pendar lembut.'),
  CatalogItem('shader', 'glow-1.0.0.hshader', 'Soft Glow', 'Satu pass warna di atas dunia, saturasi bisa diatur.'),
];

class AddonsPage extends StatefulWidget {
  const AddonsPage({super.key, required this.app});

  final Launcher app;

  @override
  State<AddonsPage> createState() => _AddonsPageState();
}

class _AddonsPageState extends State<AddonsPage> {
  String _tab = 'installed';
  String _filter = 'all';

  Launcher get app => widget.app;

  Future<void> _import() async {
    try {
      final name = await app.importAddon();
      if (name != null && mounted) toast(context, '$name dipasang');
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        Stagger(children: [
          PageHeader(
            title: 'Add-on',
            lead: 'Mod, shader dan resource pack. Perubahan berlaku saat game dibuka lagi.',
            trailing: Btn(label: 'Impor file', icon: 'folder', onTap: _import),
          ),
          Row(children: [
            SizedBox(
              width: 280,
              child: Segmented<String>(
                options: const [('installed', 'Terpasang'), ('catalog', 'Katalog')],
                value: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
            const SizedBox(width: 12),
            if (_tab == 'installed')
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 360,
                    child: Segmented<String>(
                      options: const [('all', 'Semua'), ('mod', 'Mod'), ('shader', 'Shader'), ('pack', 'Pack')],
                      value: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                ),
              ),
          ]),
          AnimatedSwitcher(
            duration: Hz.calm(context) ? Duration.zero : Hz.move,
            child: _tab == 'installed'
                ? _Installed(key: const ValueKey('i'), app: app, filter: _filter, onImport: _import, onCatalog: () => setState(() => _tab = 'catalog'))
                : _Catalog(key: const ValueKey('c'), app: app),
          ),
        ]),
      ],
    );
  }
}

String _typeLabel(String t) => switch (t) { 'shader' => 'Shader', 'pack' => 'Resource pack', _ => 'Mod' };

String _typeIcon(String t) => switch (t) { 'shader' => 'image', 'pack' => 'archive', _ => 'package' };

class _Installed extends StatelessWidget {
  const _Installed({super.key, required this.app, required this.filter, required this.onImport, required this.onCatalog});

  final Launcher app;
  final String filter;
  final VoidCallback onImport;
  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    if (app.addonsError != null) {
      return StateBlock(
        icon: 'info-box',
        tone: Hz.danger,
        title: 'Daftar add-on tidak terbaca',
        body: app.addonsError!,
        action: Btn(label: 'Muat ulang', icon: 'reload', onTap: app.loadAddons),
      );
    }
    final all = app.addons;
    if (all == null) return const LoadingBlock(text: 'Membaca folder add-on...');
    final list = filter == 'all' ? all : all.where((a) => a.type == filter).toList();
    if (list.isEmpty) {
      return StateBlock(
        icon: 'package',
        title: filter == 'all' ? 'Belum ada add-on' : 'Belum ada ${_typeLabel(filter).toLowerCase()}',
        body: 'Ambil dari katalog, atau impor file .hmod, .hshader atau .zip dari penyimpanan.',
        action: Wrap(spacing: 8, children: [
          Btn(label: 'Buka katalog', kind: BtnKind.primary, onTap: onCatalog),
          Btn(label: 'Impor', onTap: onImport),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in list) ...[
          _AddonRow(app: app, addon: a),
          const SizedBox(height: 8),
        ],
        if (all.any((a) => a.type == 'shader'))
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Hanya satu shader yang bisa aktif. Memilih yang lain mematikan yang lama.', style: Hz.small),
          ),
      ],
    );
  }
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({required this.app, required this.addon});

  final Launcher app;
  final Addon addon;

  @override
  Widget build(BuildContext context) {
    final a = addon;
    return AnimatedContainer(
      duration: Hz.move,
      decoration: BoxDecoration(
        color: a.enabled ? Hz.plate : Hz.plateSoft,
        borderRadius: Hz.r12,
        border: Border.all(color: a.enabled ? Hz.accent.withOpacity(0.45) : Hz.line.withOpacity(0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          PixelIcon(_typeIcon(a.type), size: 22, color: a.enabled ? Hz.accent : Hz.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(a.name,
                        style: Hz.body.copyWith(color: Hz.ink, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (a.version.isNotEmpty) ...[const SizedBox(width: 8), Text(a.version, style: Hz.label)],
                  const SizedBox(width: 8),
                  Tag(_typeLabel(a.type)),
                  if (a.broken) ...[const SizedBox(width: 6), const Tag('Kosong', color: Hz.warn)],
                ]),
                const SizedBox(height: 2),
                Text(
                  a.broken
                      ? 'File ini tidak berisi kode atau aset yang bisa dipakai game.'
                      : (a.description.isNotEmpty ? a.description : '${a.fileName}  ${formatBytes(a.size)}'),
                  style: Hz.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: a.enabled,
            onChanged: (_) async {
              final err = await app.toggle(a);
              if (err != null && context.mounted) toast(context, err, error: true);
            },
            activeColor: Colors.white,
            activeTrackColor: Hz.face,
            inactiveThumbColor: Hz.muted,
            inactiveTrackColor: Hz.surface,
            trackOutlineColor: WidgetStateProperty.all(Hz.line),
          ),
          IconBtn(
            icon: 'trash',
            label: 'Hapus ${a.name}',
            onTap: () async {
              final ok = await confirm(
                context,
                title: 'Hapus ${a.name}?',
                body: 'File ${a.fileName} dihapus dari perangkat. Bisa dipasang lagi dari katalog atau file.',
                action: 'Hapus',
              );
              if (!ok) return;
              final err = await app.deleteAddon(a);
              if (context.mounted) toast(context, err ?? '${a.name} dihapus', error: err != null);
            },
          ),
        ],
      ),
    );
  }
}

class _Catalog extends StatelessWidget {
  const _Catalog({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    final installed = {for (final a in app.addons ?? <Addon>[]) a.fileName.replaceAll('.disabled', '')};
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in catalog)
                SizedBox(width: w, child: _CatalogCard(app: app, item: item, installed: installed.contains(item.file))),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Diunduh dari rilis terbaru di github.com/Mattz1415/horizon-android.', style: Hz.small),
        ],
      );
    });
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.app, required this.item, required this.installed});

  final Launcher app;
  final CatalogItem item;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final busy = app.installing.contains(item.file);
    return Plate(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PixelIcon(_typeIcon(item.type), size: 20, color: Hz.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(item.name, style: Hz.title.copyWith(fontSize: 15))),
            Tag(_typeLabel(item.type)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Text(item.blurb, style: Hz.small, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 10),
          Btn(
            label: installed ? 'Pasang ulang' : 'Pasang',
            icon: installed ? 'reload' : 'download',
            kind: installed ? BtnKind.secondary : BtnKind.primary,
            busy: busy,
            expand: true,
            onTap: () async {
              final err = await app.install(item.url, item.type, item.file);
              if (context.mounted) {
                toast(context, err == null ? '${item.name} terpasang' : 'Gagal memasang ${item.name}: $err', error: err != null);
              }
            },
          ),
        ],
      ),
    );
  }
}
