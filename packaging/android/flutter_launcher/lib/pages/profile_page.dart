import 'package:flutter/material.dart';

import '../launcher.dart';
import '../ui/pixel_icon.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.app});

  final Launcher app;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  String? _error;

  Launcher get app => widget.app;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final v = _name.text.trim();
    if (!Launcher.validName(v)) {
      setState(() => _error = 'Pakai 3 sampai 16 huruf, angka atau garis bawah. Tanpa spasi.');
      return;
    }
    if (app.accounts.contains(v)) {
      setState(() => _error = '$v sudah ada di daftar.');
      return;
    }
    setState(() => _error = null);
    _name.clear();
    FocusScope.of(context).unfocus();
    await app.addAccount(v);
    if (mounted) toast(context, 'Main sebagai $v');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        Stagger(spacing: 10, children: [
          const PageHeader(
            title: 'Akun',
            lead: 'Akun offline: nama ini yang terlihat di dunia dan di server LAN.',
          ),
          Plate(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tambah nama', style: Hz.title.copyWith(fontSize: 15)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        maxLength: 16,
                        style: Hz.body.copyWith(color: Hz.ink),
                        cursorColor: Hz.accent,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        decoration: InputDecoration(
                          hintText: 'Contoh: Idris_01',
                          hintStyle: Hz.body.copyWith(color: Hz.muted),
                          counterStyle: Hz.label,
                          errorText: _error,
                          errorStyle: Hz.small.copyWith(color: Hz.danger),
                          filled: true,
                          fillColor: Hz.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: const OutlineInputBorder(borderRadius: Hz.r8, borderSide: BorderSide(color: Hz.line)),
                          enabledBorder:
                              const OutlineInputBorder(borderRadius: Hz.r8, borderSide: BorderSide(color: Hz.line)),
                          focusedBorder: const OutlineInputBorder(
                              borderRadius: Hz.r8, borderSide: BorderSide(color: Hz.accent, width: 2)),
                          errorBorder:
                              const OutlineInputBorder(borderRadius: Hz.r8, borderSide: BorderSide(color: Hz.danger)),
                          focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: Hz.r8, borderSide: BorderSide(color: Hz.danger, width: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Btn(label: 'Tambah', icon: 'plus', kind: BtnKind.primary, onTap: _add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionTitle('Daftar akun', trailing: Text('${app.accounts.length}', style: Hz.label)),
          for (final name in app.accounts) _AccountRow(app: app, name: name),
        ]),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.app, required this.name});

  final Launcher app;
  final String name;

  @override
  Widget build(BuildContext context) {
    final active = app.account == name;
    return Semantics(
      selected: active,
      child: Pressable(
        onTap: active ? null : () => app.selectAccount(name),
        semanticLabel: active ? '$name, akun aktif' : 'Pakai $name',
        child: AnimatedContainer(
          duration: Hz.move,
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: active ? Hz.plate : Hz.plateSoft,
            borderRadius: Hz.r12,
            border: Border.all(color: active ? Hz.accent.withOpacity(0.55) : Hz.line.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: active ? Hz.face : Hz.plate, borderRadius: Hz.r8),
                child: Center(
                  child: Text(name.characters.first.toUpperCase(),
                      style: Hz.pixel.copyWith(fontSize: 18, color: active ? Colors.white : Hz.inkSoft)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(name, style: Hz.body.copyWith(color: Hz.ink, fontWeight: FontWeight.w500)),
              ),
              if (active) ...[
                const PixelIcon('check', size: 16, color: Hz.success),
                const SizedBox(width: 6),
                Text('Aktif', style: Hz.label.copyWith(color: Hz.success)),
                const SizedBox(width: 8),
              ],
              IconBtn(
                icon: 'trash',
                label: 'Hapus $name',
                onTap: app.accounts.length <= 1
                    ? null
                    : () async {
                        final ok = await confirm(
                          context,
                          title: 'Hapus $name dari daftar?',
                          body: 'Dunia dan data pemain tidak ikut terhapus. Nama bisa ditambah lagi kapan saja.',
                          action: 'Hapus',
                        );
                        if (ok) await app.removeAccount(name);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
