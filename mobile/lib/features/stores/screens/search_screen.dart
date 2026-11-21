import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/catalog_repository.dart';
import '../models/catalog_models.dart';
import '../widgets/store_widgets.dart';
import 'store_detail_screen.dart';

/// Search food, drinks and stores, with category filter chips.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Category> _categories = [];
  String? _category;
  List<Product> _products = [];
  List<Store> _stores = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<CatalogRepository>().categories().then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((_) {});
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final repo = context.read<CatalogRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _query.text.trim();
      final results = await Future.wait([
        repo.products(search: q, category: _category, sort: 'popular'),
        q.isEmpty ? Future.value(Paged<Store>([], 1, 1)) : repo.stores(search: q),
      ]);
      if (!mounted) return;
      setState(() {
        _products = (results[0] as Paged<Product>).items;
        _stores = (results[1] as Paged<Store>).items;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search food, drinks or stores',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () {
                    _query.clear();
                    _search();
                  }),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: [
              _chip('All', null),
              for (final c in _categories) _chip(c.name, c.slug),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2, color: AppColors.accent),
        Expanded(
          child: _error != null
              ? ErrorView(message: _error!, onRetry: _search)
              : (_products.isEmpty && _stores.isEmpty && !_loading)
                  ? const EmptyView(icon: Icons.search_off_rounded, title: 'Nothing found', message: 'Try a different word, like "coffee" or "rice".')
                  : ListView(children: [
                      if (_stores.isNotEmpty) ...[
                        const SectionHeader('Stores'),
                        for (final s in _stores)
                          ListTile(
                            leading: AppNetworkImage(s.logoUrl, width: 46, height: 46, radius: 12, icon: Icons.storefront_rounded),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(s.location, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: RatingBadge(rating: s.rating),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: s.id))),
                          ),
                      ],
                      if (_products.isNotEmpty) ...[
                        const SectionHeader('Food & drinks'),
                        for (final p in _products) ...[
                          ProductTile(
                            product: p,
                            storeOpen: p.storeOpen,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: p.storeId))),
                          ),
                          if (p.storeName != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text('from ${p.storeName}${p.storeOpen ? '' : ' (closed now)'}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                          const Divider(indent: 16, endIndent: 16),
                        ],
                      ],
                    ]),
        ),
      ]),
    );
  }

  Widget _chip(String label, String? slug) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _category == slug,
          showCheckmark: false,
          onSelected: (_) {
            setState(() => _category = slug);
            _search();
          },
        ),
      );
}
