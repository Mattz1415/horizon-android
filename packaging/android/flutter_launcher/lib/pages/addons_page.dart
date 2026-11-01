import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

const _release = 'https://github.com/Mattz1415/horizon-android/releases/latest/download';

class CatalogItem {
  const CatalogItem(this.type, this.file, this.name, this.blurb, this.sha256);

  final String type;
  final String file;
  final String name;
  final String blurb;
  final String sha256;

  String get url => '$_release/$file';
}

/// Builds from this fork's own release: the official mods and the two shader packs.
const catalog = [
  CatalogItem('mod', 'fps-overlay.hmod', 'FPS Counter',
      'Frame per detik di pojok layar, bisa ditambah frame paling lambat dan 1% low.',
      'f73cdfb5426a7ba34cb092c2c05172ced3c473a366d187e1e229a2626adbece6'),
  CatalogItem('mod', 'minimap.hmod', 'Minimap', 'Peta medan di sekitar kamu di pojok layar, kotak atau bulat.',
      '4e701a1f520468dc1bb60bc1a12b7a86b32da5ea4b0ab21e53268bc9390f8ef8'),
  CatalogItem('mod', 'zoom.hmod', 'Zoom', 'Tahan tombol untuk memperbesar pandangan.',
      'cecd5b45f08fb96c7bc94be35518f4d329a49e094d091d694dd0c8f2258b3f91'),
  CatalogItem('mod', 'keystrokes.hmod', 'Keystrokes', 'Tombol gerak dan klik yang sedang ditekan, dengan klik per detik.',
      'bbf607911be61884b23eee96eb0d89a1c42114ad74a857b0651b245620ece9ce'),
  CatalogItem('mod', 'far-view.hmod', 'Far View',
      'Medan jauh di luar jarak render digambar sederhana, tanpa memuat chunk tambahan.',
      '47062a5203d4b9631961a9f776e8cb1c5ac9174c1cad54f411bc48e77c51b63c'),
  CatalogItem('mod', 'recipes.hmod', 'Recipes', 'Daftar semua item di samping inventaris, dengan pencarian resep.',
      'e5a82031c38e1b3f4ada31dee8bebb079ddb73ddff2d3d3639315e49c00620e2'),
  CatalogItem('shader', 'golden-hour.hshader', 'Golden Hour',
      'Cahaya hangat saat matahari terbit dan terbenam, dengan pendar lembut.',
      '4aed2cd215fe83ecd7a9cc23915cf40596d4814104e39cc62b4f55c4ff1e9755'),
  CatalogItem('shader', 'glow-1.0.0.hshader', 'Soft Glow', 'Satu pass warna di atas dunia, saturasi bisa diatur.',
      '331cfe29a666a0de804e9a9ff3d19d246eebcfbfa70b4f49bba8482d30ad9f02'),
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

  void _setTab(String v) {
    setState(() => _tab = v);
    if (v == 'registry' && app.registry == null && !app.registryLoading) app.loadRegistry();
  }

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Stagger(children: [
          PageHeader(
            title: 'Mod dan add-on',
            lead: 'Mod, shader dan resource pack. Perubahan berlaku saat game dibuka lagi.',
            trailing: Btn(label: 'Impor file', icon: 'folder', onTap: _import),
          ),
          LayoutBuilder(builder: (context, c) {
            final tabs = SizedBox(
              width: c.maxWidth >= 720 ? 440 : c.maxWidth,
              child: Segmented<String>(
                options: const [('installed', 'Terpasang'), ('registry', 'Katalog Horizon'), ('release', 'Rilis Android')],
                value: _tab,
                onChanged: _setTab,
              ),
            );
            if (_tab != 'installed') return Align(alignment: Alignment.centerLeft, child: tabs);
            final filter = SizedBox(
              width: c.maxWidth >= 720 ? 320 : c.maxWidth,
              child: Segmented<String>(
                options: const [('all', 'Semua'), ('mod', 'Mod'), ('shader', 'Shader'), ('pack', 'Pack')],
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            );
            return Wrap(spacing: 12, runSpacing: 10, children: [tabs, filter]);
          }),
          AnimatedSwitcher(
            duration: Hz.calm(context) ? Duration.zero : Hz.move,
            child: switch (_tab) {
              'registry' => _Registry(key: const ValueKey('r'), app: app),
              'release' => _Catalog(key: const ValueKey('c'), app: app),
              _ => _Installed(
                  key: const ValueKey('i'),
                  app: app,
                  filter: _filter,
                  onImport: _import,
                  onCatalog: () => _setTab('registry'),
                ),
            },
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
    Hz.watch(context);
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
        action: Wrap(spacing: 8, runSpacing: 8, children: [
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
          Padding(
            padding: const EdgeInsets.only(top: 4),
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
    Hz.watch(context);
    final a = addon;
    return Plate(
      accent: a.enabled,
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      child: Row(
        children: [
          PixelIcon(_typeIcon(a.type), size: 22, color: a.enabled ? Hz.accent : Hz.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(a.name, style: Hz.strong, overflow: TextOverflow.ellipsis)),
                  if (a.version.isNotEmpty) ...[const SizedBox(width: 8), Text(a.version, style: Hz.figure)],
                  const SizedBox(width: 8),
                  Tag(_typeLabel(a.type)),
                  if (a.broken) ...[const SizedBox(width: 6), Tag('Kosong', color: Hz.warn)],
                ]),
                const SizedBox(height: 2),
                Text(
                  a.broken
                      ? 'File ini tidak berisi kode atau aset yang bisa dipakai game.'
                      : (a.description.isNotEmpty ? a.description : '${a.fileName}, ${formatBytes(a.size)}'),
                  style: Hz.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Semantics(
            label: a.enabled ? 'Matikan ${a.name}' : 'Aktifkan ${a.name}',
            child: HzSwitch(
              value: a.enabled,
              onChanged: (_) async {
                final err = await app.toggle(a);
                if (err != null && context.mounted) toast(context, err, error: true);
              },
            ),
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

/// The Horizon registry, the same list playhorizon.dev/mods shows.
class _Registry extends StatefulWidget {
  const _Registry({super.key, required this.app});

  final Launcher app;

  @override
  State<_Registry> createState() => _RegistryState();
}

class _RegistryState extends State<_Registry> {
  final _q = TextEditingController();
  bool _androidOnly = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final app = widget.app;
    final reg = app.registry;
    if (reg == null) {
      if (app.registryError != null) {
        return StateBlock(
          icon: 'info-box',
          tone: Hz.danger,
          title: 'Katalog tidak bisa dimuat',
          body: '${app.registryError}. Periksa koneksi lalu coba lagi.',
          action: Btn(label: 'Coba lagi', icon: 'reload', onTap: app.loadRegistry),
        );
      }
      return const LoadingBlock(text: 'Mengambil katalog dari playhorizon.dev...');
    }
    final q = _q.text.trim().toLowerCase();
    final list = reg.where((p) {
      if (_androidOnly && !p.runsOnAndroid) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.summary.toLowerCase().contains(q) ||
          p.authors.any((a) => a.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        if (a.runsOnAndroid != b.runsOnAndroid) return a.runsOnAndroid ? -1 : 1;
        return (b.downloads ?? 0).compareTo(a.downloads ?? 0);
      });
    final installed = {for (final a in app.addons ?? <Addon>[]) a.fileName.replaceAll('.disabled', '')};
    final androidCount = reg.where((p) => p.runsOnAndroid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: Hz.body.copyWith(color: Hz.ink),
              decoration: InputDecoration(
                hintText: 'Cari nama, fungsi atau pembuat',
                hintStyle: Hz.body.copyWith(color: Hz.muted),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(13),
                  child: PixelIcon('search', size: 18, color: Hz.muted),
                ),
                filled: true,
                fillColor: Hz.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                enabledBorder: OutlineInputBorder(borderRadius: Hz.r10, borderSide: BorderSide(color: Hz.line)),
                focusedBorder: OutlineInputBorder(borderRadius: Hz.r10, borderSide: BorderSide(color: Hz.accent, width: 2)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('Bisa di Android', style: Hz.small),
          HzSwitch(value: _androidOnly, onChanged: (v) => setState(() => _androidOnly = v)),
          IconBtn(
            icon: 'reload',
            label: 'Muat ulang katalog',
            onTap: app.registryLoading ? null : app.loadRegistry,
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          app.registryCached
              ? 'Offline: memakai salinan dari ${formatAgo(app.registryFetched)}. $androidCount dari ${reg.length} bisa dipasang di Android.'
              : '${reg.length} proyek di katalog, $androidCount bisa dipasang di Android. Sisanya mod native yang dirakit launcher desktop.',
          style: Hz.small.copyWith(color: app.registryCached ? Hz.warn : Hz.muted),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          StateBlock(
            icon: 'search',
            title: 'Tidak ada yang cocok',
            body: q.isEmpty ? 'Katalog kosong untuk saringan ini.' : 'Tidak ada proyek dengan kata "$q".',
          )
        else
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in list)
                  SizedBox(
                    width: w,
                    child: _RegistryCard(
                      app: app,
                      item: p,
                      installed: p.androidVersion != null && installed.contains(p.androidVersion!.fileName),
                    ),
                  ),
              ],
            );
          }),
        const SizedBox(height: 12),
        Text('Sumber: katalog horizon-rust/horizon-mods, sama dengan playhorizon.dev/mods. File dicek sha256 sebelum dipasang.',
            style: Hz.small),
      ],
    );
  }
}

class _RegistryCard extends StatelessWidget {
  const _RegistryCard({required this.app, required this.item, required this.installed});

  final Launcher app;
  final RegistryItem item;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final p = item;
    final v = p.androidVersion ?? p.latest;
    final busy = app.installing.contains(p.id);
    final kindLabel = switch (p.kind) { 'resourcepack' => 'Resource pack', 'native-mod' => 'Mod native', _ => 'Mod' };
    return Plate(
      accent: installed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _Icon(url: p.icon, fallback: p.kind == 'resourcepack' ? 'archive' : 'package'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: Hz.title.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    p.authors.isEmpty ? kindLabel : 'oleh ${p.authors.join(', ')}',
                    style: Hz.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Text(p.summary, style: Hz.small.copyWith(color: Hz.inkSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Tag(kindLabel, color: p.runsOnAndroid ? Hz.accent : Hz.muted),
            if (v != null) Tag('v${v.version}'),
            if (p.downloads != null) Tag('${formatCount(p.downloads!)} unduhan'),
            if (v != null && v.size > 0 && p.runsOnAndroid) Tag(formatBytes(v.size)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: p.runsOnAndroid
                  ? Btn(
                      label: installed ? 'Pasang ulang' : 'Pasang',
                      icon: installed ? 'reload' : 'download',
                      kind: installed ? BtnKind.secondary : BtnKind.primary,
                      busy: busy,
                      expand: true,
                      onTap: () async {
                        final err = await app.installRegistry(p);
                        if (context.mounted) {
                          toast(context, err == null ? '${p.name} terpasang' : 'Gagal memasang ${p.name}: $err',
                              error: err != null);
                        }
                      },
                    )
                  : Tooltip(
                      message: 'Mod native dirakit ke dalam game oleh launcher desktop, belum bisa di Android.',
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: Hz.r10, border: Border.all(color: Hz.line)),
                        child: Text('Hanya desktop', style: Hz.small),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            IconBtn(
              icon: 'external-link',
              label: 'Buka halaman ${p.name}',
              onTap: () async {
                final err = await app.openUrl(p.page);
                if (err != null && context.mounted) toast(context, err, error: true);
              },
            ),
          ]),
        ],
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.url, required this.fallback});

  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
    final box = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: Hz.raised, borderRadius: Hz.r10, border: Border.all(color: Hz.line)),
      child: Center(child: PixelIcon(fallback, size: 20, color: Hz.accent)),
    );
    final u = url;
    if (u == null || !u.startsWith('https://')) return box;
    return ClipRRect(
      borderRadius: Hz.r10,
      child: SizedBox.square(
        dimension: 40,
        child: Image.network(
          u,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          cacheWidth: 80,
          errorBuilder: (_, __, ___) => box,
          loadingBuilder: (_, child, progress) => progress == null ? child : box,
        ),
      ),
    );
  }
}

class _Catalog extends StatelessWidget {
  const _Catalog({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    Hz.watch(context);
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
          Text('Dibuat khusus untuk Android, dari rilis terbaru github.com/Mattz1415/horizon-android.', style: Hz.small),
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
    Hz.watch(context);
    final busy = app.installing.contains(item.file);
    return Plate(
      accent: installed,
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
            child: Text(item.blurb, style: Hz.small.copyWith(color: Hz.inkSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 10),
          Btn(
            label: installed ? 'Pasang ulang' : 'Pasang',
            icon: installed ? 'reload' : 'download',
            kind: installed ? BtnKind.secondary : BtnKind.primary,
            busy: busy,
            expand: true,
            onTap: () async {
              final err = await app.install(item.url, item.type, item.file, sha256: item.sha256, fileName: item.file);
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
