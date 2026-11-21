<?php

namespace Database\Seeders;

use App\Models\Building;
use App\Models\Faculty;
use App\Models\SystemSetting;
use Illuminate\Database\Seeder;

/**
 * Real RUPP Campus I layout.
 *
 * Positions and footprints: OpenStreetMap (© OpenStreetMap contributors, ODbL).
 * Building names: the official "Map of Royal University of Phnom Penh" (2022).
 * Source file: database/data/rupp_campus_osm.json
 *
 * Floors and room names are sample data; admins can edit them in the dashboard.
 */
class CampusSeeder extends Seeder
{
    public function run(): void
    {
        $data = json_decode(file_get_contents(database_path('data/rupp_campus_osm.json')), true);

        // The campus outline restricts every map in the apps to Campus I.
        $polygon = $data['campus']['polygon'];
        $lats = array_column($polygon, 0);
        $lngs = array_column($polygon, 1);
        SystemSetting::updateOrCreate(['key' => 'campus_map'], [
            'type' => 'json',
            'group' => 'campus',
            'description' => 'RUPP Campus I outline used to limit maps (OpenStreetMap).',
            'value' => json_encode([
                'name' => $data['campus']['name'],
                'center' => $data['campus']['center'],
                'bounds' => ['south' => min($lats), 'west' => min($lngs), 'north' => max($lats), 'east' => max($lngs)],
                'polygon' => $polygon,
                'landmarks' => $data['landmarks'] ?? [],
                'attribution' => $data['license'],
            ]),
        ]);

        $zones = [];
        foreach ($data['zones'] as $code => $name) {
            $zones[$code] = Faculty::updateOrCreate(['code' => $code], [
                'name' => $name,
                'description' => "$name — Royal University of Phnom Penh, Campus I",
            ]);
        }

        foreach ($data['buildings'] as $b) {
            $building = Building::updateOrCreate(['code' => $b['code']], [
                'faculty_id' => $zones[$b['zone']]->id,
                'name' => $b['name'],
                'description' => $b['official_map_no'] ? "No. {$b['official_map_no']} on the official RUPP campus map" : null,
                'latitude' => $b['lat'],
                'longitude' => $b['lng'],
                'polygon' => $b['polygon'],
                'official_map_no' => $b['official_map_no'],
            ]);

            for ($f = 1; $f <= $b['floors']; $f++) {
                $floor = $building->floors()->updateOrCreate(['number' => $f], ['label' => $f === 1 ? 'Ground floor' : "Floor $f"]);

                foreach ($this->roomsFor($b['code'], $f, $b['floors']) as [$roomName, $type]) {
                    $floor->classrooms()->updateOrCreate(['name' => $roomName], ['type' => $type]);
                }
            }
        }
    }

    /** Sample rooms per floor, by building type. */
    private function roomsFor(string $code, int $floor, int $floors): array
    {
        return match ($code) {
            'CAN' => [['Seating area', 'hall'], ['Outdoor tables', 'other']],
            'AUD' => [['Main hall', 'hall'], ['Lobby', 'hall']],
            'LIB', 'HSL', 'FLIB' => [['Reading hall '.$floor, 'library'], ['Study room '.$floor.'01', 'other'], ['Study room '.$floor.'02', 'other']],
            'CKCC', 'CJCC' => [['Lobby', 'hall'], ['Training room '.$floor.'01', 'classroom'], ['Office '.$floor.'02', 'office']],
            default => array_merge(
                array_map(fn ($r) => ['Room '.$floor.sprintf('%02d', $r), $code === 'STEM' && $r >= 5 ? 'lab' : 'classroom'], range(1, 6)),
                [['Lecturer Office '.$floor.'00', 'office']],
            ),
        };
    }
}
