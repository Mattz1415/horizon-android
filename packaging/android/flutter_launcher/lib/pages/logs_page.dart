import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../launcher.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.app});

  final Launcher app;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  Map<String, dynamic>? _logs;
  String? _error;
  String _which = 'latest';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final l = await widget.app.logs();
      if (!mounted) return;
      setState(() {
        _logs = l;
        if ((l['crash'] as String? ?? '').isNotEmpty && (l['crashModified'] as num? ?? 0) >= (l['latestModified'] as num? ?? 0)) {
          _which = 'crash';
        }
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Log tidak terbaca');
    } on MissingPluginException {
      if (mounted) setState(() => _logs = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = (_logs?[_which] as String?) ?? '';
    final modified = (_logs?['${_which}Modified'] as num?)?.toInt() ?? 0;
    final Widget body;
    if (_error != null) {
      body = StateBlock(
        icon: 'info-box',
        tone: Hz.danger,
        title: 'Log tidak terbaca',
        body: _error!,
        action: Btn(label: 'Coba lagi', icon: 'reload', onTap: _load),
      );
    } else if (_logs == null) {
      body = const LoadingBlock(text: 'Membaca log...');
    } else if (text.isEmpty) {
      body = StateBlock(
        icon: _which == 'crash' ? 'check' : 'notes',
        tone: _which == 'crash' ? Hz.success : Hz.muted,
        title: _which == 'crash' ? 'Tidak ada laporan crash' : 'Log masih kosong',
        body: _which == 'crash'
            ? 'Kalau game keluar sendiri, laporannya muncul di sini.'
            : 'Log dibuat saat game dibuka.',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('Ditulis ${formatAgo(modified)}, ${text.split('\n').length} baris terakhir', style: Hz.label)),
            Btn(
              label: 'Salin',
              icon: 'notes',
              kind: BtnKind.quiet,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) toast(context, 'Log disalin');
              },
            ),
            Btn(label: 'Bagikan', icon: 'external-link', kind: BtnKind.quiet, onTap: () => widget.app.share(text)),
            if (_which == 'crash')
              Btn(
                label: 'Hapus',
                icon: 'trash',
                kind: BtnKind.danger,
                onTap: () async {
                  await widget.app.clearLogs();
                  await _load();
                },
              ),
          ]),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(color: const Color(0xFF0A0910), borderRadius: Hz.r12, border: Border.all(color: Hz.line)),
            child: Scrollbar(
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.all(14),
                child: SelectableText(text, style: Hz.mono.copyWith(fontSize: 11.5)),
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        Stagger(children: [
          PageHeader(
            title: 'Log',
            lead: 'Catatan terakhir dari game. Lampirkan saat melapor masalah.',
            trailing: IconBtn(icon: 'reload', label: 'Muat ulang log', onTap: _load),
          ),
          SizedBox(
            width: 320,
            child: Segmented<String>(
              options: const [('latest', 'Sesi terakhir'), ('crash', 'Crash')],
              value: _which,
              onChanged: (v) => setState(() => _which = v),
            ),
          ),
          body,
        ]),
      ],
    );
  }
}
