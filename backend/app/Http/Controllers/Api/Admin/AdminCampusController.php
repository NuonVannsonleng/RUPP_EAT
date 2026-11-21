<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Building;
use App\Models\Classroom;
use App\Models\Faculty;
use App\Models\Floor;
use App\Services\ActivityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** CRUD for the campus delivery hierarchy: faculties → buildings → floors → classrooms. */
class AdminCampusController extends Controller
{
    /** GET /api/admin/campus — full tree including inactive items. */
    public function tree(): JsonResponse
    {
        $faculties = Faculty::with(['buildings.floors.classrooms'])->withCount('buildings')->orderBy('name')->get();
        $unassigned = Building::whereNull('faculty_id')->with('floors.classrooms')->orderBy('name')->get();

        return $this->ok(['faculties' => $faculties, 'unassigned_buildings' => $unassigned]);
    }

    // Faculties
    public function storeFaculty(Request $r): JsonResponse
    {
        $f = Faculty::create($r->validate([
            'name' => ['required', 'string', 'max:150', 'unique:faculties,name'],
            'code' => ['required', 'string', 'max:20', 'unique:faculties,code'],
            'description' => ['nullable', 'string', 'max:500'],
            'is_active' => ['sometimes', 'boolean'],
        ]));
        ActivityLogger::log('campus.faculty_created', "Faculty {$f->name} created", $f);

        return $this->created($f);
    }

    public function updateFaculty(Request $r, Faculty $faculty): JsonResponse
    {
        $faculty->update($r->validate([
            'name' => ['sometimes', 'string', 'max:150', Rule::unique('faculties', 'name')->ignore($faculty->id)],
            'code' => ['sometimes', 'string', 'max:20', Rule::unique('faculties', 'code')->ignore($faculty->id)],
            'description' => ['nullable', 'string', 'max:500'],
            'is_active' => ['sometimes', 'boolean'],
        ]));

        return $this->ok($faculty, 'Faculty updated.');
    }

    public function destroyFaculty(Faculty $faculty): JsonResponse
    {
        $faculty->delete();

        return $this->ok(null, 'Faculty deleted.');
    }

    // Buildings
    public function storeBuilding(Request $r): JsonResponse
    {
        $b = Building::create($r->validate([
            'faculty_id' => ['nullable', 'uuid', 'exists:faculties,id'],
            'name' => ['required', 'string', 'max:150'],
            'code' => ['required', 'string', 'max:20', 'unique:buildings,code'],
            'description' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'is_active' => ['sometimes', 'boolean'],
            'floors' => ['sometimes', 'integer', 'min:1', 'max:20'],
        ]));
        // Optionally create floors 1..N in one go.
        for ($i = 1; $i <= (int) $r->input('floors', 0); $i++) {
            $b->floors()->create(['number' => $i, 'label' => 'Floor '.$i]);
        }
        ActivityLogger::log('campus.building_created', "Building {$b->name} created", $b);

        return $this->created($b->load('floors'));
    }

    public function updateBuilding(Request $r, Building $building): JsonResponse
    {
        $building->update($r->validate([
            'faculty_id' => ['nullable', 'uuid', 'exists:faculties,id'],
            'name' => ['sometimes', 'string', 'max:150'],
            'code' => ['sometimes', 'string', 'max:20', Rule::unique('buildings', 'code')->ignore($building->id)],
            'description' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'is_active' => ['sometimes', 'boolean'],
        ]));

        return $this->ok($building, 'Building updated.');
    }

    public function destroyBuilding(Building $building): JsonResponse
    {
        $building->delete();

        return $this->ok(null, 'Building deleted.');
    }

    // Floors
    public function storeFloor(Request $r): JsonResponse
    {
        $data = $r->validate([
            'building_id' => ['required', 'uuid', 'exists:buildings,id'],
            'number' => ['required', 'integer', 'between:-3,50',
                Rule::unique('floors')->where('building_id', $r->building_id)],
            'label' => ['nullable', 'string', 'max:50'],
        ]);

        return $this->created(Floor::create($data));
    }

    public function updateFloor(Request $r, Floor $floor): JsonResponse
    {
        $floor->update($r->validate([
            'number' => ['sometimes', 'integer', 'between:-3,50',
                Rule::unique('floors')->where('building_id', $floor->building_id)->ignore($floor->id)],
            'label' => ['nullable', 'string', 'max:50'],
        ]));

        return $this->ok($floor, 'Floor updated.');
    }

    public function destroyFloor(Floor $floor): JsonResponse
    {
        $floor->delete();

        return $this->ok(null, 'Floor deleted.');
    }

    // Classrooms (delivery locations)
    public function storeClassroom(Request $r): JsonResponse
    {
        $data = $r->validate([
            'floor_id' => ['required', 'uuid', 'exists:floors,id'],
            'name' => ['required', 'string', 'max:50', Rule::unique('classrooms')->where('floor_id', $r->floor_id)->whereNull('deleted_at')],
            'type' => ['sometimes', 'in:classroom,lab,office,hall,library,other'],
            'is_deliverable' => ['sometimes', 'boolean'],
        ]);

        return $this->created(Classroom::create($data));
    }

    public function updateClassroom(Request $r, Classroom $classroom): JsonResponse
    {
        $classroom->update($r->validate([
            'name' => ['sometimes', 'string', 'max:50',
                Rule::unique('classrooms')->where('floor_id', $classroom->floor_id)->whereNull('deleted_at')->ignore($classroom->id)],
            'type' => ['sometimes', 'in:classroom,lab,office,hall,library,other'],
            'is_deliverable' => ['sometimes', 'boolean'],
        ]));

        return $this->ok($classroom, 'Classroom updated.');
    }

    public function destroyClassroom(Classroom $classroom): JsonResponse
    {
        $classroom->delete();

        return $this->ok(null, 'Classroom deleted.');
    }
}
