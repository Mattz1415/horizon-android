import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

class WorldsPage extends StatelessWidget {
  const WorldsPage({super.key, required this.app});

  final Launcher app;

  @override
  Widget build(BuildContext context) {
    final worlds = app.worlds;
    final Widget body;
    if (app.worldsError != null) {
      body = StateBlock(
        icon: 'info-box',
        tone: Hz.danger,
        title: 'Folder dunia tidak terbaca',
        body: app.worldsError!,
        action: Btn(label: 'Muat ulang', icon: 'reload', onTap: app.loadWorlds),
      );
    } else if (worlds == null) {
      body = const LoadingBlock(text: 'Membaca folder saves...');
    } else if (worlds.isEmpty) {
      body = const StateBlock(
        icon: 'globe',
        title: 'Belum ada dunia',
        body: 'Buka game lalu pilih Singleplayer untuk membuat dunia pertama. Dunia baru muncul di sini.',
      );
    } else {
      final total = worlds.fold<int>(0, (s, w) => s + w.size);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${worlds.length} dunia, ${formatBytes(total)} total', style: Hz.label),
          const SizedBox(height: 10),
          for (final w in worlds) ...[
            _WorldRow(app: app, world: w),
            const SizedBox(height: 8),
          ],
        ],
      );
    }
    return RefreshIndicator(
      color: Hz.accent,
      backgroundColor: Hz.plate,
      onRefresh: app.loadWorlds,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          Stagger(children: [
            PageHeader(
              title: 'Dunia',
              lead: 'Dunia singleplayer di perangkat ini. Tarik ke bawah untuk memuat ulang.',
              trailing: IconBtn(icon: 'reload', label: 'Muat ulang', onTap: app.loadWorlds),
            ),
            body,
          ]),
        ],
      ),
    );
  }
}

class _WorldRow extends StatelessWidget {
  const _WorldRow({required this.app, required this.world});

  final Launcher app;
  final World world;

  @override
  Widget build(BuildContext context) {
    return Plate(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Hz.plate, borderRadius: Hz.r8),
            child: const Center(child: PixelIcon('globe', size: 20, color: Hz.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(world.name,
                    style: Hz.body.copyWith(color: Hz.ink, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text('Dimainkan ${formatAgo(world.modified)}  ·  ${formatBytes(world.size)}', style: Hz.small),
              ],
            ),
          ),
          IconBtn(
            icon: 'trash',
            label: 'Hapus ${world.name}',
            color: Hz.danger,
            onTap: () async {
              final ok = await confirm(
                context,
                title: 'Hapus dunia "${world.name}"?',
                body: 'Semua bangunan dan inventaris di dunia ini hilang selamanya. Tidak bisa dibatalkan.',
                action: 'Hapus selamanya',
              );
              if (!ok) return;
              final err = await app.deleteWorld(world);
              if (context.mounted) toast(context, err ?? '${world.name} dihapus', error: err != null);
            },
          ),
        ],
      ),
    );
  }
}
