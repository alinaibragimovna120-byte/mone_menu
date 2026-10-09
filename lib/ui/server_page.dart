// «Сервер»: вход в Mone (пароль как в приложении Mone) и синхронизация меню —
// отправить техкарты на сервер или загрузить их оттуда (с фото).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/menu_sync.dart';
import 'l10n.dart';
import 'theme.dart';

Future<void> openServerPage(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerPage()));

class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  late final _url = TextEditingController(text: context.read<MenuSync>().serverUrl);
  final _password = TextEditingController();
  bool _showUrl = false;

  @override
  void dispose() {
    _url.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _guard(Future<void> Function() job) async {
    try {
      await job();
    } on MenuSyncException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _login(MenuSync sync) => _guard(() async {
        await sync.login(_url.text, _password.text);
        _password.clear();
        if (mounted) _toast(tr('Вы вошли как {name}', {'name': sync.userName}));
        // Сразу подтянуть техкарты с сервера (или отправить свои).
        await sync.autoSync();
      });

  Future<void> _push(MenuSync sync, {bool force = false}) => _guard(() async {
        try {
          final n = await sync.push(force: force);
          if (mounted) _toast(tr('Отправлено на сервер: {n}', {'n': n}));
        } on MenuConflict {
          if (!mounted) return;
          final choice = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr('На сервере есть другие изменения')),
              content: Text(tr(
                  'После вашей последней синхронизации меню на сервере изменили с другого устройства. Что оставить?')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Отмена'))),
                TextButton(onPressed: () => Navigator.pop(c, 'pull'), child: Text(tr('Загрузить с сервера'))),
                FilledButton(onPressed: () => Navigator.pop(c, 'force'), child: Text(tr('Заменить моими'))),
              ],
            ),
          );
          if (choice == 'force') await _push(sync, force: true);
          if (choice == 'pull') await _pull(sync, confirm: false);
        }
      });

  Future<void> _pull(MenuSync sync, {bool confirm = true}) => _guard(() async {
        if (confirm) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr('Загрузить с сервера?')),
              content: Text(tr('Техкарты на этом устройстве будут заменены версией с сервера.')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Отмена'))),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Загрузить'))),
              ],
            ),
          );
          if (ok != true) return;
        }
        final n = await sync.pull();
        if (mounted) _toast(tr('Загружено с сервера: {n}', {'n': n}));
      });

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<MenuSync>();
    final synced = sync.lastSync?.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: Text(tr('Сервер'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (sync.busy) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              if (!sync.loggedIn) ...[
                Text(tr('Войдите тем же паролем, что и в приложении Mone, чтобы хранить техкарты на сервере и открывать их на других устройствах.'),
                    style: const TextStyle(color: AppColors.muted, height: 1.4)),
                const SizedBox(height: 18),
                TextField(
                  controller: _password,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('Пароль')),
                  onSubmitted: (_) => _login(sync),
                ),
                const SizedBox(height: 10),
                if (_showUrl)
                  TextField(controller: _url, decoration: InputDecoration(labelText: tr('Адрес сервера')))
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: () => setState(() => _showUrl = true), child: Text(tr('Другой сервер'))),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: sync.busy ? null : () => _login(sync),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(tr('Войти')),
                ),
                const SizedBox(height: 10),
                // Смотреть меню можно без входа.
                OutlinedButton.icon(
                  onPressed: sync.busy ? null : () => _pull(sync),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(tr('Загрузить с сервера')),
                ),
              ] else ...[
                SoftCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.cloud_done_outlined, color: AppColors.espresso),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(sync.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(sync.serverUrl, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        Text(
                          synced == null
                              ? tr('Ещё не синхронизировано')
                              : tr('Синхронизировано {date}', {
                                  'date': '${two(synced.day)}.${two(synced.month)} ${two(synced.hour)}:${two(synced.minute)}'
                                }),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        if (sync.conflict)
                          Text(tr('На сервере есть другие изменения'),
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))
                        else if (sync.dirty)
                          Text(tr('Есть изменения, ещё не отправленные на сервер'),
                              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                    TextButton(onPressed: sync.busy ? null : sync.logout, child: Text(tr('Выйти'))),
                  ]),
                ),
                const SizedBox(height: 18),
                if (sync.canEdit) ...[
                  FilledButton.icon(
                    onPressed: sync.busy ? null : () => _push(sync),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(tr('Отправить на сервер')),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('Все техкарты с этого устройства (и скрытые) вместе с фото сохранятся на сервере.'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(tr('Отправлять техкарты на сервер могут админ и шеф. Вам доступна загрузка.'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 16),
                ],
                OutlinedButton.icon(
                  onPressed: sync.busy ? null : () => _pull(sync),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(tr('Загрузить с сервера')),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: Text(tr('Версия {v}', {'v': appVersion}),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
