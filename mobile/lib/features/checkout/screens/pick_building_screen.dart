import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/maps/campus_map_data.dart';
import '../../../core/maps/campus_map_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

/// Tap a RUPP Campus I building on the map to choose it as the delivery destination.
/// Pops with the selected building id.
class PickBuildingScreen extends StatefulWidget {
  const PickBuildingScreen({super.key, this.initialBuildingId});
  final String? initialBuildingId;

  @override
  State<PickBuildingScreen> createState() => _PickBuildingScreenState();
}

class _PickBuildingScreenState extends State<PickBuildingScreen> {
  late Future<CampusMap> _future;
  CampusBuilding? _selected;

  @override
  void initState() {
    super.initState();
    _future = context.read<CampusMapRepository>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your building')),
      body: FutureBuilder<CampusMap>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final campus = snap.data!;
          _selected ??= campus.building(widget.initialBuildingId);
          final deliverable = campus.buildings.where((b) => b.floorCount > 0).toList();

          return Column(children: [
            Container(
              width: double.infinity,
              color: AppColors.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Text('Tap the building where you are. You will choose the floor and room next.',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: CampusMapView(
                campus: campus,
                selectedBuildingId: _selected?.id,
                onBuildingTap: (b) => setState(() => _selected = b),
                pins: [
                  if (_selected != null)
                    CampusPin(id: 'sel', position: _selected!.position, title: _selected!.name, kind: PinKind.destination),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final b in deliverable)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(b.code),
                        selected: _selected?.id == b.id,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _selected = b),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_selected != null) ...[
                    Text(_selected!.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      [
                        _selected!.zone,
                        if (_selected!.officialMapNo != null) 'No. ${_selected!.officialMapNo} on the RUPP map',
                        '${_selected!.floorCount} floor${_selected!.floorCount == 1 ? '' : 's'}',
                      ].whereType<String>().join(' · '),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                  ],
                  GradientButton(
                    label: _selected == null ? 'Tap a building on the map' : 'Deliver to ${_selected!.code}',
                    icon: Icons.check_rounded,
                    onPressed: _selected == null || _selected!.floorCount == 0 ? null : () => Navigator.pop(context, _selected!.id),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
