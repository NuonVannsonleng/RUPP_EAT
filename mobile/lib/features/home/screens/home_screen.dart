import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../../stores/data/catalog_repository.dart';
import '../../stores/models/catalog_models.dart';
import '../../stores/screens/search_screen.dart';
import '../../stores/screens/store_list_screen.dart';
import '../../stores/widgets/store_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<CatalogRepository>().home();
  }

  Future<void> _refresh() async {
    final f = context.read<CatalogRepository>().home();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final unread = context.watch<NotificationProvider>().unread;

    return Scaffold(
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<HomeData>(
            future: _future,
            builder: (context, snap) {
              return CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _header(user.firstName, unread)),
                if (snap.connectionState != ConnectionState.done)
                  const SliverFillRemaining(child: LoadingView())
                else if (snap.hasError)
                  SliverFillRemaining(child: ErrorView(message: snap.error.toString(), onRetry: _refresh))
                else
                  ..._content(snap.data!),
              ]);
            },
          ),
      ),
    );
  }

  Widget _header(String name, int unread) => CampusHeader(
        trailing: IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.gold,
            textColor: AppColors.text,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.white),
          ),
        ),
        bottom: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(
            text: TextSpan(style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white), children: [
              const TextSpan(text: 'Welcome back, '),
              TextSpan(text: name, style: const TextStyle(color: AppColors.gold)),
            ]),
          ),
          const SizedBox(height: 2),
          const Text('What would you like to eat today?', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.only(right: 8), child: _searchBar()),
        ]),
      );

  Widget _searchBar() => Padding(
        padding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: const Row(children: [
              Icon(Icons.search_rounded, color: AppColors.textMuted),
              SizedBox(width: 10),
              Text('Search food, drinks or stores', style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
        ),
      );

  List<Widget> _content(HomeData d) => [
        if (d.activeOrders.isNotEmpty) SliverToBoxAdapter(child: _activeOrders(d)),
        if (d.announcements.isNotEmpty) SliverToBoxAdapter(child: _announcements(d.announcements)),
        SliverToBoxAdapter(child: _categories(d.categories)),
        if (d.recentProducts.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('Order again')),
          SliverToBoxAdapter(child: _productRow(d.recentProducts)),
        ],
        if (d.popularProducts.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('Popular on campus')),
          SliverToBoxAdapter(child: _productRow(d.popularProducts)),
        ],
        SliverToBoxAdapter(
          child: SectionHeader('Featured stores',
              action: 'See all', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreListScreen()))),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList.separated(
            itemCount: d.featuredStores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => StoreCard(store: d.featuredStores[i]),
          ),
        ),
      ];

  Widget _activeOrders(HomeData d) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          children: d.activeOrders.map((o) {
            final style = StatusStyle.of(o.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))).then((_) => _refresh()),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: Colors.white, child: Icon(style.icon, color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.statusLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('${o.storeName} · ${o.number}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ]),
                      ),
                      const Text('Track', style: TextStyle(color: AppColors.accentYellow, fontWeight: FontWeight.w800)),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.accentYellow),
                    ]),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _announcements(List<Announcement> items) => SizedBox(
        height: 150,
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.9),
          padEnds: false,
          itemCount: items.length,
          itemBuilder: (_, i) {
            final a = items[i];
            return Padding(
              padding: EdgeInsets.fromLTRB(i == 0 ? 20 : 6, 16, 6, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(fit: StackFit.expand, children: [
                  AppNetworkImage(a.imageUrl, radius: 0, icon: Icons.campaign_rounded),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primaryDark.withValues(alpha: 0.92), AppColors.primary.withValues(alpha: 0.35)]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accentYellow, borderRadius: BorderRadius.circular(6)),
                        child: Text(a.isPromotion ? 'PROMO' : 'NEWS', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 6),
                      Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      );

  Widget _categories(List<Category> cats) => SizedBox(
        height: 92,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final c = cats[i];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreListScreen(category: c))),
              child: SizedBox(
                width: 66,
                child: Column(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(16)),
                    child: Icon(categoryIcon(c.icon), color: AppColors.accent),
                  ),
                  const SizedBox(height: 6),
                  Text(c.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      );

  Widget _productRow(List<Product> products) => SizedBox(
        height: 200,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ProductCard(product: products[i]),
        ),
      );
}
