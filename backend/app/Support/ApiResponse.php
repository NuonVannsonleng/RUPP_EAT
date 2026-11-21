<?php

namespace App\Support;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Pagination\AbstractPaginator;

/**
 * Consistent JSON envelope for every API response:
 * { "success": bool, "message": string|null, "data": mixed, "meta": {pagination}|absent, "errors": {}|absent }
 */
trait ApiResponse
{
    protected function ok(mixed $data = null, ?string $message = null, int $status = 200): JsonResponse
    {
        $payload = ['success' => true, 'message' => $message];

        if ($data instanceof AnonymousResourceCollection && $data->resource instanceof AbstractPaginator) {
            $paginator = $data->resource;
            $payload['data'] = $data->collection->map(fn ($r) => $r->resolve(request()))->all();
            $payload['meta'] = [
                'current_page' => $paginator->currentPage(),
                'last_page' => method_exists($paginator, 'lastPage') ? $paginator->lastPage() : null,
                'per_page' => $paginator->perPage(),
                'total' => method_exists($paginator, 'total') ? $paginator->total() : null,
            ];
        } elseif ($data instanceof JsonResource) {
            $payload['data'] = $data->resolve(request());
        } else {
            $payload['data'] = $data;
        }

        return response()->json($payload, $status);
    }

    /** Paginated response for plain arrays/models (no API resource). */
    protected function paged(\Illuminate\Contracts\Pagination\LengthAwarePaginator $paginator, array $extraMeta = []): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => null,
            'data' => array_values($paginator->items()),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ] + $extraMeta,
        ]);
    }

    protected function created(mixed $data = null, ?string $message = 'Created successfully.'): JsonResponse
    {
        return $this->ok($data, $message, 201);
    }

    protected function fail(string $message, int $status = 400, array $errors = []): JsonResponse
    {
        $payload = ['success' => false, 'message' => $message, 'data' => null];
        if ($errors) {
            $payload['errors'] = $errors;
        }

        return response()->json($payload, $status);
    }

    protected function perPage(int $default = 15): int
    {
        return min(max((int) request('per_page', $default), 1), 100);
    }
}
