// Создание / редактирование позиции меню вручную.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tech_card.dart';
import '../provider/menu_provider.dart';
import 'card_photo.dart';
import 'l10n.dart';
import 'theme.dart';

class CardEditPage extends StatefulWidget {
  final TechCard? card;

  /// Техкарта для новой позиции (при редактировании берётся из [card]).
  final String? bookId;
  const CardEditPage({super.key, this.card, this.bookId}) : assert(card != null || bookId != null);

  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  late final _name = TextEditingController(text: widget.card?.name ?? '');
  late final _category = TextEditingController(text: widget.card?.category ?? '');
  late List<CardVariant> _variants =
      widget.card?.variants.toList() ?? [const CardVariant(title: 'Основной')];
  late List<String> _photos = widget.card?.photos.toList() ?? [];
  final List<String> _addedPhotos = [];

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    if (res.isEmpty || !mounted) return;
    final storage = context.read<MenuProvider>().storage;
    final bytes = await res.first.xFile.readAsBytes();
    final path = await storage.savePhoto(bytes, (res.first.extension ?? 'png').replaceFirst('.', ''));
    if (!mounted) return;
    setState(() {
      _photos = [..._photos, path];
      _addedPhotos.add(path);
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Введите название'))));
      return;
    }
    final menu = context.read<MenuProvider>();
    final removed = widget.card?.photos.where((p) => !_photos.contains(p)) ?? const <String>[];
    final card = TechCard(
      id: widget.card?.id ?? menu.newId(),
      bookId: widget.card?.bookId ?? widget.bookId!,
      name: _name.text.trim(),
      category: _category.text.trim().isEmpty ? 'Без категории' : _category.text.trim(),
      variants: _variants,
      photos: _photos,
      source: widget.card?.source ?? '',
      updatedAt: DateTime.now(),
    );
    await menu.upsert(card);
    for (final p in removed) {
      await menu.storage.deletePhoto(p);
    }
    if (mounted) Navigator.pop(context);
  }

  void _setVariant(int i, CardVariant v) => setState(() => _variants = [..._variants]..[i] = v);

  @override
  Widget build(BuildContext context) {
    final categories = context.read<MenuProvider>().categoriesOf(widget.card?.bookId ?? widget.bookId!);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? tr('Новая позиция') : tr('Редактирование')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18)),
              onPressed: _save,
              child: Text(tr('Сохранить')),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: tr('Название'))),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: _category.value,
                optionsBuilder: (v) =>
                    categories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (v) => _category.text = v,
                fieldViewBuilder: (context, ctrl, focus, _) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    onChanged: (v) => _category.text = v,
                    decoration: InputDecoration(labelText: tr('Категория')),
                  );
                },
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('Фото')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _photos)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(width: 96, height: 96, child: CardPhoto(path: p)),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton.filledTonal(
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _photos = _photos.where((e) => e != p).toList()),
                      ),
                    ),
                  ]),
                SizedBox(
                  width: 96,
                  height: 96,
                  child: OutlinedButton(onPressed: _addPhoto, child: const Icon(Icons.add_a_photo_outlined)),
                ),
              ]),
              for (var i = 0; i < _variants.length; i++)
                _VariantEditor(
                  // Ключ меняется только при добавлении/удалении — поля не теряют фокус при вводе.
                  key: ValueKey('v$i-${_variants.length}'),
                  variant: _variants[i],
                  onChanged: (v) => _setVariant(i, v),
                  onDelete: _variants.length > 1
                      ? () => setState(() => _variants = [..._variants]..removeAt(i))
                      : null,
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _variants = [
                      ..._variants,
                      CardVariant(title: _variants.any((v) => v.title == 'С собой') ? 'Вариант' : 'С собой'),
                    ]),
                icon: const Icon(Icons.add),
                label: Text(tr('Добавить вариант (например, «С собой»)')),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantEditor extends StatelessWidget {
  final CardVariant variant;
  final ValueChanged<CardVariant> onChanged;
  final VoidCallback? onDelete;

  const _VariantEditor({super.key, required this.variant, required this.onChanged, this.onDelete});

  static const _units = ['гр', 'мл', 'шт', 'кг', 'л'];

  void _setIngredient(int i, Ingredient v) =>
      onChanged(variant.copyWith(ingredients: [...variant.ingredients]..[i] = v));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: variant.title,
                  decoration: InputDecoration(labelText: tr('Вариант')),
                  onChanged: (v) => onChanged(variant.copyWith(title: v)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: variant.yieldText,
                  decoration: InputDecoration(labelText: tr('Выход'), hintText: trData('415 гр')),
                  onChanged: (v) => onChanged(variant.copyWith(yieldText: v)),
                ),
              ),
              if (onDelete != null)
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: tr('Удалить вариант')),
            ]),
            const SizedBox(height: 8),
            for (var i = 0; i < variant.ingredients.length; i++)
              Row(key: ValueKey('$i-${variant.ingredients.length}'), children: [
                Expanded(
                  child: TextFormField(
                    initialValue: variant.ingredients[i].name,
                    decoration: InputDecoration(hintText: tr('Ингредиент'), isDense: true),
                    onChanged: (v) => _setIngredient(i, variant.ingredients[i].copyWith(name: v)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: formatAmount(variant.ingredients[i].amount),
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => _setIngredient(
                        i, variant.ingredients[i].copyWith(amount: double.tryParse(v.replaceAll(',', '.')) ?? 0)),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _units.contains(variant.ingredients[i].unit) ? variant.ingredients[i].unit : 'гр',
                  items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(trData(u)))],
                  onChanged: (u) => _setIngredient(i, variant.ingredients[i].copyWith(unit: u)),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onChanged(variant.copyWith(ingredients: [...variant.ingredients]..removeAt(i))),
                ),
              ]),
            TextButton.icon(
              onPressed: () => onChanged(variant.copyWith(
                  ingredients: [...variant.ingredients, const Ingredient(name: '', unit: 'гр', amount: 0)])),
              icon: const Icon(Icons.add),
              label: Text(tr('Ингредиент')),
            ),
            TextFormField(
              initialValue: variant.notes.join('\n'),
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(labelText: tr('Примечания (каждое с новой строки)')),
              onChanged: (v) => onChanged(variant.copyWith(
                  notes: v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList())),
            ),
          ],
        ),
      ),
    );
  }
}
