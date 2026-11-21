<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Models\Building;
use App\Models\Order;
use App\Models\Store;
use App\Models\SystemSetting;
use App\Support\Media;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * RUPP Campus I map data (coordinates are WGS84, the same as Google Maps).
 * Building positions/footprints come from OpenStreetMap (ODbL).
 */
class MapController extends Controller
{
    /** GET /api/campus/map — campus outline, buildings with rooms, and store pins. */
    public function campus(): JsonResponse
    {
        $buildings = Building::where('is_active', true)
            ->whereNotNull('latitude')
            ->with(['faculty', 'floors.classrooms' => fn ($q) => $q->where('is_deliverable', true)])
            ->orderBy('name')
            ->get();

        $stores = Store::active()->with('building')->get()
            ->map(fn (Store $s) => ($c = $s->coordinates()) ? [
                'id' => $s->id,
                'name' => $s->name,
                'latitude' => $c['lat'],
                'longitude' => $c['lng'],
                'building' => $s->building?->name,
                'location_note' => $s->location_note,
                'logo_url' => Media::url($s->logo_path),
                'is_open_now' => $s->isAcceptingOrders(),
                'rating_avg' => round((float) $s->rating_avg, 1),
            ] : null)
            ->filter()->values();

        return $this->ok([
            'campus' => SystemSetting::get('campus_map'),
            'buildings' => $buildings->map(fn (Building $b) => [
                'id' => $b->id,
                'code' => $b->code,
                'name' => $b->name,
                'official_map_no' => $b->official_map_no,
                'zone' => $b->faculty?->name,
                'zone_id' => $b->faculty_id,
                'latitude' => $b->latitude,
                'longitude' => $b->longitude,
                'polygon' => $b->polygon,
                'floors' => $b->floors->map(fn ($f) => [
                    'id' => $f->id,
                    'number' => $f->number,
                    'label' => $f->label ?? 'Floor '.$f->number,
                    'classrooms' => $f->classrooms->map(fn ($c) => ['id' => $c->id, 'name' => $c->name, 'type' => $c->type])->values(),
                ])->filter(fn ($f) => $f['classrooms']->isNotEmpty())->values(),
            ])->values(),
            'stores' => $stores,
        ]);
    }

    /**
     * GET /api/orders/{order}/tracking — map data for one order.
     * The driver's live position is only shared while the order is on its way
     * (driver assigned / on the way) and only with people allowed to view the order.
     */
    public function tracking(Order $order): JsonResponse
    {
        $this->authorize('view', $order);
        $order->loadMissing(['store.building', 'driver.driverProfile']);

        $storePin = $order->store->coordinates();
        $dest = $order->delivery_location;

        $driver = null;
        $live = in_array($order->status, [OrderStatus::DriverAssigned, OrderStatus::OnTheWay], true)
            || ($order->driver_id && in_array($order->status, [OrderStatus::Accepted, OrderStatus::Preparing, OrderStatus::Ready], true));
        $profile = $order->driver?->driverProfile;
        if ($live && $profile && $profile->current_latitude !== null) {
            $driver = [
                'name' => $order->driver->name,
                'phone' => $order->driver->phone,
                'vehicle_type' => $profile->vehicle_type,
                'latitude' => $profile->current_latitude,
                'longitude' => $profile->current_longitude,
                'heading' => $profile->current_heading,
                'updated_at' => $profile->location_updated_at,
            ];
        }

        return $this->ok([
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'status_label' => $order->status->label(),
            'fulfillment_method' => $order->fulfillment_method->value,
            'delivery_status' => $order->delivery?->status->value,
            'store' => [
                'name' => $order->store->name,
                'location' => trim(($order->store->building?->name ?? '').' · '.($order->store->location_note ?? ''), ' ·'),
                'latitude' => $storePin['lat'] ?? null,
                'longitude' => $storePin['lng'] ?? null,
            ],
            'destination' => $order->isDelivery() && $dest ? [
                'building' => $dest['building'] ?? null,
                'room' => $dest['room'] ?? null,
                'floor' => $dest['floor_label'] ?? null,
                'latitude' => $dest['latitude'] ?? null,
                'longitude' => $dest['longitude'] ?? null,
            ] : null,
            'driver' => $driver,
        ]);
    }

    /** POST /api/driver/location — the driver app reports GPS while online. */
    public function updateDriverLocation(Request $request): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'heading' => ['nullable', 'numeric', 'between:0,360'],
        ]);

        $profile = $request->user()->driverProfile;
        if (! $profile?->is_online) {
            throw ValidationException::withMessages(['driver' => 'Go online to share your location.']);
        }

        $profile->update([
            'current_latitude' => $data['latitude'],
            'current_longitude' => $data['longitude'],
            'current_heading' => $data['heading'] ?? null,
            'location_updated_at' => now(),
        ]);

        return $this->ok(['updated_at' => $profile->location_updated_at]);
    }
}
