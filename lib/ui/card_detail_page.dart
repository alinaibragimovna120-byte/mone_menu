// Просмотр позиции: большое фото, варианты (основной / с собой), состав и заметки.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tech_card.dart';
import '../provider/menu_provider.dart';
import 'card_edit_page.dart';
import 'card_photo.dart';
import 'l10n.dart';
import 'theme.dart';

class CardDetailPage extends StatefulWidget {
  final String cardId;
  const CardDetailPage({super.key, required this.cardId});

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  int _variant = 0;
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final card = context.select<MenuProvider, TechCard?>((m) => m.byId(widget.cardId));
    if (card == null) return Scaffold(body: Center(child: Text(tr('Позиция удалена'))));
    final vi = _variant.clamp(0, card.variants.isEmpty ? 0 : card.variants.length - 1);
    final variant = card.variants.isEmpty ? null : card.variants[vi];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            actions: [
              IconButton(
                tooltip: tr('Редактировать'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardEditPage(card: card))),
              ),
              IconButton(
                tooltip: tr('Удалить'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, card),
              ),
            ],
          ),
          // Фото — скруглённая карточка с отступами, как обложка техкарты.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                height: 320,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (card.photos.length > 1)
                      PageView(
                        onPageChanged: (i) => setState(() => _photo = i),
                        children: [for (final p in card.photos) WholePhoto(path: p)],
                      )
                    else
                      Hero(
                        tag: 'photo-${card.id}',
                        child: WholePhoto(path: card.photos.isEmpty ? null : card.photos.first),
                      ),
                    if (card.photos.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < card.photos.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _photo ? 18 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: i == _photo ? 1 : 0.55),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.category.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.caramel,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (card.variants.length > 1) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < card.variants.length; i++)
                              ChoiceChip(
                                label: Text(trData(card.variants[i].title)),
                                selected: i == vi,
                                onSelected: (_) => setState(() => _variant = i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (variant == null)
                        Text(tr('Нет рецептуры'), style: const TextStyle(color: AppColors.muted))
                      else
                        _VariantBody(variant: variant),
                      if (card.source.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.description_outlined, size: 16, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(card.source, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, TechCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Удалить позицию?')),
        content: Text(card.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Отмена'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3412E)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Удалить')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final menu = context.read<MenuProvider>();
    Navigator.pop(context);
    await menu.delete(card.id);
  }
}

class _VariantBody extends StatelessWidget {
  final CardVariant variant;
  const _VariantBody({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (variant.yieldText.isNotEmpty) ...[
          SoftCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.latte, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.scale_outlined, color: AppColors.espresso),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(tr('Выход'), style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                ),
                Text(trData(variant.yieldText), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
        SectionTitle(tr('Состав')),
        SoftCard(
          child: variant.ingredients.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(tr('Ингредиенты не указаны'), style: const TextStyle(color: AppColors.muted)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < variant.ingredients.length; i++) ...[
                      if (i > 0) const Divider(indent: 18, endIndent: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 7, right: 12),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: AppColors.caramel, shape: BoxShape.circle),
                            ),
                            Expanded(
                              child: Text(
                                variant.ingredients[i].name,
                                style: const TextStyle(fontSize: 15, height: 1.3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatAmount(variant.ingredients[i].amount),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 34,
                              child: Text(
                                trData(variant.ingredients[i].unit),
                                style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        if (variant.notes.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionTitle(tr('Примечания')),
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in variant.notes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 10),
                          child: Icon(Icons.info_outline, size: 16, color: AppColors.caramel),
                        ),
                        Expanded(child: Text(n, style: const TextStyle(height: 1.35))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
