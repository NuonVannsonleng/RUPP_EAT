<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Map support: building footprints, store pins and the driver's live position.
 * Coordinates are WGS84 (the same as Google Maps).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('buildings', function (Blueprint $table) {
            $table->jsonb('polygon')->nullable()->after('longitude');        // [[lat, lng], ...] footprint
            $table->unsignedSmallInteger('official_map_no')->nullable()->after('polygon'); // number on the official RUPP map
        });

        Schema::table('stores', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable()->after('location_note');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
        });

        Schema::table('driver_profiles', function (Blueprint $table) {
            $table->decimal('current_latitude', 10, 7)->nullable()->after('is_online');
            $table->decimal('current_longitude', 10, 7)->nullable()->after('current_latitude');
            $table->float('current_heading')->nullable()->after('current_longitude');
            $table->timestamp('location_updated_at')->nullable()->after('current_heading');
        });
    }

    public function down(): void
    {
        Schema::table('driver_profiles', fn (Blueprint $t) => $t->dropColumn(['current_latitude', 'current_longitude', 'current_heading', 'location_updated_at']));
        Schema::table('stores', fn (Blueprint $t) => $t->dropColumn(['latitude', 'longitude']));
        Schema::table('buildings', fn (Blueprint $t) => $t->dropColumn(['polygon', 'official_map_no']));
    }
};
