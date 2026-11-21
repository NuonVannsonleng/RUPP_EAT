<?php

namespace Database\Seeders;

use App\Models\Building;
use App\Models\Faculty;
use Illuminate\Database\Seeder;

/** Sample RUPP campus structure. Admins can edit everything from the dashboard. */
class CampusSeeder extends Seeder
{
    public function run(): void
    {
        $campus = [
            ['Faculty of Science', 'FS', [
                ['Building A', 'A', 4, 11.5689, 104.8905],
                ['Science Laboratory Building', 'LAB', 3, 11.5685, 104.8909],
            ]],
            ['Faculty of Engineering', 'FE', [
                ['Engineering Building', 'ENG', 5, 11.5694, 104.8899],
                ['STEM Building', 'STEM', 4, 11.5697, 104.8903],
            ]],
            ['Faculty of Social Sciences and Humanities', 'FSSH', [
                ['Building B', 'B', 4, 11.5683, 104.8899],
                ['Building C', 'C', 3, 11.5680, 104.8903],
            ]],
            ['Faculty of Development Studies', 'FDS', [
                ['Building D', 'D', 3, 11.5687, 104.8913],
            ]],
            ['Faculty of Education', 'FOE', [
                ['Education Building', 'EDU', 3, 11.5691, 104.8915],
            ]],
            ['Institute of Foreign Languages', 'IFL', [
                ['IFL Building', 'IFL', 4, 11.5702, 104.8911],
            ]],
            ['Central Facilities', 'CF', [
                ['Main Library', 'LIB', 2, 11.5692, 104.8907],
                ['Student Center', 'SC', 2, 11.5686, 104.8896],
            ]],
        ];

        foreach ($campus as [$facultyName, $code, $buildings]) {
            $faculty = Faculty::updateOrCreate(['code' => $code], ['name' => $facultyName, 'description' => "$facultyName, Royal University of Phnom Penh"]);

            foreach ($buildings as [$name, $bCode, $floors, $lat, $lng]) {
                $building = Building::updateOrCreate(['code' => $bCode], [
                    'faculty_id' => $faculty->id, 'name' => $name, 'latitude' => $lat, 'longitude' => $lng,
                ]);

                for ($f = 1; $f <= $floors; $f++) {
                    $floor = $building->floors()->updateOrCreate(['number' => $f], ['label' => $f === 1 ? 'Ground floor' : "Floor $f"]);

                    if (in_array($bCode, ['LIB', 'SC'], true)) {
                        $rooms = $bCode === 'LIB'
                            ? [['Reading Hall', 'hall'], ['Study Room '.$f.'01', 'other'], ['Study Room '.$f.'02', 'other']]
                            : [['Lobby', 'hall'], ['Meeting Room '.$f.'01', 'office']];
                    } else {
                        $rooms = [];
                        for ($r = 1; $r <= 6; $r++) {
                            $rooms[] = ['Room '.$f.sprintf('%02d', $r), $r === 6 && $bCode === 'LAB' ? 'lab' : 'classroom'];
                        }
                        $rooms[] = ['Lecturer Office '.$f.'00', 'office'];
                    }

                    foreach ($rooms as [$roomName, $type]) {
                        $floor->classrooms()->updateOrCreate(['name' => $roomName], ['type' => $type]);
                    }
                }
            }
        }
    }
}
