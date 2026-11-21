<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/**
 * Image paths are stored relative to the public disk ("products/abc.jpg").
 * Seed data may store absolute https URLs, which are returned unchanged.
 */
class Media
{
    public static function url(?string $path): ?string
    {
        if (! $path) {
            return null;
        }
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }
        // Use the host the client actually called (e.g. 10.0.2.2 from the Android emulator)
        $base = request()?->getSchemeAndHttpHost() ?: rtrim(config('app.url'), '/');

        return $base.'/storage/'.ltrim($path, '/');
    }

    public static function store(UploadedFile $file, string $folder): string
    {
        return $file->store($folder, 'public');
    }

    /** Replace an existing image, deleting the old local file. */
    public static function replace(?string $oldPath, UploadedFile $file, string $folder): string
    {
        static::delete($oldPath);

        return static::store($file, $folder);
    }

    public static function delete(?string $path): void
    {
        if ($path && ! str_starts_with($path, 'http')) {
            Storage::disk('public')->delete($path);
        }
    }
}
