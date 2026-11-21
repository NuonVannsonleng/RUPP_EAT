<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Campus location hierarchy: faculty -> building -> floor -> classroom.
 * Classrooms (any room type) are the delivery destinations.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('faculties', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name')->unique();
            $table->string('code', 20)->unique();
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('buildings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('faculty_id')->nullable()->constrained('faculties')->nullOnDelete();
            $table->string('name');
            $table->string('code', 20)->unique();
            $table->string('description')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->index('faculty_id');
        });

        Schema::create('floors', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('building_id')->constrained('buildings')->cascadeOnDelete();
            $table->smallInteger('number');
            $table->string('label', 50)->nullable(); // e.g. "Ground floor"
            $table->timestamps();

            $table->unique(['building_id', 'number']);
        });

        Schema::create('classrooms', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('floor_id')->constrained('floors')->cascadeOnDelete();
            $table->string('name', 50);                       // e.g. "Room 305"
            $table->string('type', 20)->default('classroom'); // classroom, lab, office, hall, other
            $table->boolean('is_deliverable')->default(true);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['floor_id', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('classrooms');
        Schema::dropIfExists('floors');
        Schema::dropIfExists('buildings');
        Schema::dropIfExists('faculties');
    }
};
