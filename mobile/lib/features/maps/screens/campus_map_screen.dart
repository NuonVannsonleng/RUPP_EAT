import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/maps/campus_map_data.dart';
import '../../../core/maps/campus_map_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../stores/screens/store_detail_screen.dart';

/// Map of RUPP Campus I with every campus store pinned. Tap a pin (or a card) to open the menu.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  late Future<CampusMap> _future;
  final _mapKey = GlobalKey<CampusMapViewState>();
  String? _selectedStore;

  @override
  void initState() {
    super.initState();
    _future = context.read<CampusMapRepository>().load();
  }

  void _openStore(String id) => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: id)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus food map')),
      body: FutureBuilder<CampusMap>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading RUPP Campus I…');
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString(), onRetry: () => setState(() => _future = context.read<CampusMapRepository>().load(refresh: true)));
          }
          final campus = snap.data!;
          final storeBuildings = {
            for (final s in campus.stores)
              for (final b in campus.buildings)
                if (b.name == s.building) b.id,
          };

          return Column(children: [
            Expanded(
              child: CampusMapView(
                key: _mapKey,
                campus: campus,
                highlightBuildingIds: storeBuildings,
                pins: [
                  for (final s in campus.stores)
                    CampusPin(
                      id: s.id,
                      position: s.position,
                      title: s.name,
                      subtitle: '${s.isOpenNow ? 'Open now' : 'Closed'} · ${s.building ?? ''} · tap to order',
                      onTap: () => _openStore(s.id),
                    ),
                ],
              ),
            ),
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
              child: SizedBox(
                height: 92,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: campus.stores.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final s = campus.stores[i];
                    final selected = s.id == _selectedStore;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() => _selectedStore = s.id);
                        _mapKey.currentState?.focus(s.position);
                      },
                      onDoubleTap: () => _openStore(s.id),
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
                        ),
                        child: Row(children: [
                          AppNetworkImage(s.logoUrl, width: 52, height: 52, radius: 12, icon: Icons.storefront_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(s.building ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text(s.isOpenNow ? 'Open now' : 'Closed',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.isOpenNow ? AppColors.success : AppColors.danger)),
                            ]),
                          ),
                          IconButton(onPressed: () => _openStore(s.id), icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
