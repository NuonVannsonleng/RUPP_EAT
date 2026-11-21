<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('order_number', 30)->unique();     // RE-20261120-0001
            $table->foreignUuid('customer_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->restrictOnDelete();
            $table->foreignUuid('driver_id')->nullable()->constrained('users')->nullOnDelete();

            $table->string('fulfillment_method', 20);          // delivery, pickup
            $table->string('payment_method', 30);              // cash_on_delivery, cash_on_pickup, khqr
            $table->string('payment_status', 20)->default('unpaid'); // unpaid, pending, paid, failed, refunded
            $table->string('status', 30)->default('pending');
            // pending, accepted, preparing, ready, driver_assigned, on_the_way,
            // delivered, picked_up, rejected, cancelled

            $table->decimal('subtotal', 10, 2);
            $table->decimal('delivery_fee', 10, 2)->default(0);
            $table->decimal('total', 10, 2);

            // Campus delivery destination (delivery orders only)
            $table->foreignUuid('classroom_id')->nullable()->constrained('classrooms')->nullOnDelete();
            $table->jsonb('delivery_location')->nullable();   // snapshot: faculty/building/floor/room names
            $table->text('delivery_instructions')->nullable();

            $table->string('pickup_code', 6);                  // shown to customer, verified by store / driver
            $table->string('customer_note')->nullable();
            $table->string('idempotency_key', 64)->nullable();
            $table->string('cancel_reason')->nullable();
            $table->foreignUuid('cancelled_by')->nullable()->constrained('users')->nullOnDelete();

            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('ready_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();

            $table->unique(['customer_id', 'idempotency_key']);
            $table->index(['store_id', 'status']);
            $table->index(['customer_id', 'created_at']);
            $table->index(['driver_id', 'status']);
            $table->index('status');
            $table->index('created_at');
        });

        DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_fulfillment_check CHECK (fulfillment_method IN ('delivery','pickup'))");
        DB::statement('ALTER TABLE orders ADD CONSTRAINT orders_amounts_check CHECK (subtotal >= 0 AND delivery_fee >= 0 AND total >= 0)');

        Schema::create('order_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->string('product_name');           // snapshot at order time
            $table->decimal('unit_price', 10, 2);     // snapshot at order time
            $table->unsignedSmallInteger('quantity');
            $table->decimal('line_total', 10, 2);
            $table->string('note')->nullable();
            $table->timestamps();

            $table->index('order_id');
            $table->index('product_id');
        });

        Schema::create('order_status_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->constrained('orders')->cascadeOnDelete();
            $table->string('from_status', 30)->nullable();
            $table->string('to_status', 30);
            $table->foreignUuid('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('note')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['order_id', 'created_at']);
        });

        Schema::create('deliveries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->unique()->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('driver_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 20)->default('pending');
            // pending (not yet requested), searching, assigned, picked_up, arriving, delivered, cancelled
            $table->timestamp('requested_at')->nullable();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'driver_id']);
        });

        Schema::create('delivery_declines', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('delivery_id')->constrained('deliveries')->cascadeOnDelete();
            $table->foreignUuid('driver_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['delivery_id', 'driver_id']);
        });

        Schema::create('delivery_status_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('delivery_id')->constrained('deliveries')->cascadeOnDelete();
            $table->string('status', 20);
            $table->foreignUuid('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('note')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['delivery_id', 'created_at']);
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->constrained('orders')->cascadeOnDelete();
            $table->string('method', 30);
            $table->decimal('amount', 10, 2);
            $table->string('currency', 3)->default('USD');
            $table->string('status', 20)->default('pending'); // pending, paid, failed, refunded, cancelled
            $table->string('provider', 30)->nullable();       // cash, bakong
            $table->string('provider_reference')->nullable(); // KHQR md5 / transaction hash
            $table->foreignUuid('collected_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();
            $table->jsonb('meta')->nullable();
            $table->timestamps();

            $table->index(['order_id', 'status']);
            $table->unique(['provider', 'provider_reference']);
        });

        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('products')->cascadeOnDelete();
            $table->unsignedTinyInteger('rating');
            $table->text('comment')->nullable();
            $table->timestamps();

            $table->index(['store_id', 'created_at']);
            $table->index('product_id');
        });

        // One store review (product_id NULL) and one review per product, per order
        DB::statement('CREATE UNIQUE INDEX reviews_unique_store_review ON reviews (user_id, order_id) WHERE product_id IS NULL');
        DB::statement('CREATE UNIQUE INDEX reviews_unique_product_review ON reviews (user_id, order_id, product_id) WHERE product_id IS NOT NULL');
        DB::statement('ALTER TABLE reviews ADD CONSTRAINT reviews_rating_range CHECK (rating BETWEEN 1 AND 5)');
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('delivery_status_logs');
        Schema::dropIfExists('delivery_declines');
        Schema::dropIfExists('deliveries');
        Schema::dropIfExists('order_status_logs');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
    }
};
