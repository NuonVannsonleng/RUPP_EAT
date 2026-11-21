<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Models\ActivityLog;
use App\Models\Announcement;
use App\Models\ProductCategory;
use App\Models\SupportTicket;
use App\Models\SystemSetting;
use App\Services\ActivityLogger;
use App\Services\NotificationService;
use App\Support\Media;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** Categories, announcements, system settings, activity logs, support tickets / disputes. */
class AdminSystemController extends Controller
{
    // ---------- Food categories ----------

    public function categories(): JsonResponse
    {
        return $this->ok(CategoryResource::collection(ProductCategory::withCount('products')->orderBy('sort_order')->get()));
    }

    public function storeCategory(Request $r): JsonResponse
    {
        $data = $r->validate([
            'name' => ['required', 'string', 'max:60', 'unique:product_categories,name'],
            'icon' => ['nullable', 'string', 'max:50'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);
        $category = ProductCategory::create($data + ['slug' => Str::slug($data['name'])]);
        ActivityLogger::log('category.created', "Category {$category->name} created", $category);

        return $this->created(new CategoryResource($category));
    }

    public function updateCategory(Request $r, ProductCategory $category): JsonResponse
    {
        $data = $r->validate([
            'name' => ['sometimes', 'string', 'max:60', Rule::unique('product_categories', 'name')->ignore($category->id)],
            'icon' => ['nullable', 'string', 'max:50'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
        ]);
        if (isset($data['name'])) {
            $data['slug'] = Str::slug($data['name']);
        }
        $category->update($data);

        return $this->ok(new CategoryResource($category), 'Category updated.');
    }

    public function destroyCategory(ProductCategory $category): JsonResponse
    {
        $category->delete(); // products keep existing with category_id = NULL

        return $this->ok(null, 'Category deleted.');
    }

    // ---------- Announcements / promotions ----------

    public function announcements(Request $r): JsonResponse
    {
        $items = Announcement::with('store:id,name')->latest()->paginate($this->perPage(20));
        $items->getCollection()->transform(fn ($a) => $a->setAttribute('image_url', Media::url($a->image_path)));

        return $this->paged($items);
    }

    public function storeAnnouncement(Request $r): JsonResponse
    {
        $data = $this->announcementData($r);
        $data['created_by'] = $r->user()->id;
        if ($r->hasFile('image')) {
            $data['image_path'] = Media::store($r->file('image'), 'announcements');
        }
        $a = Announcement::create($data);
        ActivityLogger::log('announcement.created', "Announcement \"{$a->title}\" published", $a);

        return $this->created($a);
    }

    public function updateAnnouncement(Request $r, Announcement $announcement): JsonResponse
    {
        $data = $this->announcementData($r, true);
        if ($r->hasFile('image')) {
            $data['image_path'] = Media::replace($announcement->image_path, $r->file('image'), 'announcements');
        }
        $announcement->update($data);

        return $this->ok($announcement, 'Announcement updated.');
    }

    public function destroyAnnouncement(Announcement $announcement): JsonResponse
    {
        Media::delete($announcement->image_path);
        $announcement->delete();

        return $this->ok(null, 'Announcement deleted.');
    }

    private function announcementData(Request $r, bool $updating = false): array
    {
        if ($r->has('is_active')) {
            $r->merge(['is_active' => filter_var($r->input('is_active'), FILTER_VALIDATE_BOOLEAN)]);
        }
        $req = $updating ? 'sometimes' : 'required';

        return collect($r->validate([
            'title' => [$req, 'string', 'max:150'],
            'body' => [$req, 'string', 'max:2000'],
            'type' => ['sometimes', 'in:announcement,promotion'],
            'audience' => ['sometimes', 'in:all,customers,drivers,stores'],
            'store_id' => ['nullable', 'uuid', 'exists:stores,id'],
            'is_active' => ['sometimes', 'boolean'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after_or_equal:starts_at'],
            'image' => ['nullable', 'image', 'max:4096'],
        ]))->except('image')->all();
    }

    // ---------- System settings (delivery fees, toggles) ----------

    public function settings(): JsonResponse
    {
        return $this->ok(SystemSetting::orderBy('group')->orderBy('key')->get()->map(fn ($s) => [
            'key' => $s->key, 'value' => $s->typedValue(), 'type' => $s->type, 'group' => $s->group, 'description' => $s->description,
        ]));
    }

    /** PUT /api/admin/settings {settings: {delivery_fee: 0.5, ...}} — only existing keys can be changed. */
    public function updateSettings(Request $r): JsonResponse
    {
        $r->validate(['settings' => ['required', 'array']]);
        $existing = SystemSetting::all()->keyBy('key');

        foreach ($r->input('settings') as $key => $value) {
            $setting = $existing->get($key) ?? throw ValidationException::withMessages(["settings.$key" => "Unknown setting \"$key\"."]);
            $setting->value = match ($setting->type) {
                'number' => is_numeric($value) && $value >= 0 ? (string) $value
                    : throw ValidationException::withMessages(["settings.$key" => "$key must be a positive number."]),
                'boolean' => filter_var($value, FILTER_VALIDATE_BOOLEAN) ? 'true' : 'false',
                'json' => json_encode($value),
                default => (string) $value,
            };
            $setting->save();
        }
        ActivityLogger::log('settings.updated', 'System settings updated', null, $r->input('settings'));

        return $this->settings();
    }

    // ---------- Activity logs ----------

    public function activityLogs(Request $r): JsonResponse
    {
        $logs = ActivityLog::with('user:id,name,email')
            ->when($r->search, fn ($q, $s) => $q->where('description', 'ilike', "%$s%"))
            ->when($r->action, fn ($q, $a) => $q->where('action', 'like', "$a%"))
            ->when($r->date_from, fn ($q, $d) => $q->whereDate('created_at', '>=', $d))
            ->when($r->date_to, fn ($q, $d) => $q->whereDate('created_at', '<=', $d))
            ->latest('created_at')
            ->paginate($this->perPage(30));

        return $this->paged($logs);
    }

    // ---------- Support tickets / order disputes ----------

    public function tickets(Request $r): JsonResponse
    {
        $tickets = SupportTicket::with(['user:id,name,email,phone', 'order:id,order_number,status,total', 'resolver:id,name'])
            ->when($r->status, fn ($q, $s) => $q->where('status', $s))
            ->latest()
            ->paginate($this->perPage(20));

        return $this->paged($tickets);
    }

    public function resolveTicket(Request $r, SupportTicket $ticket, NotificationService $notifications): JsonResponse
    {
        $r->validate(['resolution' => ['required', 'string', 'max:2000']]);
        $ticket->update(['status' => 'resolved', 'resolution' => $r->resolution, 'resolved_by' => $r->user()->id, 'resolved_at' => now()]);
        $notifications->notify($ticket->user_id, 'support_resolved', 'Support request resolved', "\"{$ticket->subject}\": {$r->resolution}",
            ['ticket_id' => $ticket->id, 'order_id' => $ticket->order_id]);
        ActivityLogger::log('support.resolved', "Ticket \"{$ticket->subject}\" resolved", $ticket);

        return $this->ok($ticket->fresh(['user', 'order', 'resolver']), 'Ticket resolved.');
    }
}
