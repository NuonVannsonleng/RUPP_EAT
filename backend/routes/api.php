<?php

use App\Http\Controllers\Api\Admin\AdminCampusController;
use App\Http\Controllers\Api\Admin\AdminDashboardController;
use App\Http\Controllers\Api\Admin\AdminStoreController;
use App\Http\Controllers\Api\Admin\AdminSystemController;
use App\Http\Controllers\Api\Admin\AdminUserController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\Driver\DriverController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\StoreController;
use App\Http\Controllers\Api\StoreOwner\StoreDashboardController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| RUPP Eat REST API  (prefix: /api)
|--------------------------------------------------------------------------
| Auth: Laravel Sanctum bearer tokens.  Roles: customer, driver, store_owner, admin.
| Every response uses { success, message, data, meta? , errors? }.
*/

// ---------- Public ----------
Route::middleware('throttle:10,1')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
    Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
    Route::post('reset-password', [AuthController::class, 'resetPassword']);
    Route::post('store-applications', [AdminStoreController::class, 'apply']);
});
Route::get('settings/public', [CatalogController::class, 'publicSettings']);
Route::get('campus/locations', [CatalogController::class, 'campus']);

// ---------- Any signed-in, active user ----------
Route::middleware(['auth:sanctum', 'role'])->group(function () {
    Route::post('logout', [AuthController::class, 'logout']);
    Route::get('me', [AuthController::class, 'me']);
    Route::post('me', [AuthController::class, 'updateProfile']); // multipart (avatar)
    Route::put('me', [AuthController::class, 'updateProfile']);
    Route::put('me/password', [AuthController::class, 'changePassword']);
    Route::put('me/fcm-token', [AuthController::class, 'updateFcmToken']);

    Route::get('notifications', [CustomerController::class, 'notifications']);
    Route::get('notifications/unread-count', [CustomerController::class, 'unreadCount']);
    Route::post('notifications/read-all', [CustomerController::class, 'markAllRead']);
    Route::post('notifications/{notification}/read', [CustomerController::class, 'markRead']);
    Route::get('announcements', [CatalogController::class, 'announcements']);
    Route::get('support-tickets', [CustomerController::class, 'supportTickets']);
    Route::post('support-tickets', [CustomerController::class, 'createSupportTicket']);

    // Browsing (customers, plus store owners / admins previewing)
    Route::get('categories', [CatalogController::class, 'categories']);
    Route::get('stores', [StoreController::class, 'index']);
    Route::get('stores/{store}', [StoreController::class, 'show']);
    Route::get('stores/{store}/products', [ProductController::class, 'forStore']);
    Route::get('stores/{store}/reviews', [CustomerController::class, 'storeReviews']);
    Route::get('products', [ProductController::class, 'index']);
    Route::get('products/{product}', [ProductController::class, 'show']);
    Route::get('products/{product}/reviews', [CustomerController::class, 'productReviews']);

    // Orders: list/show are role-scoped inside the controller + OrderPolicy.
    Route::get('orders', [OrderController::class, 'index']);
    Route::get('orders/{order}', [OrderController::class, 'show']);
    Route::patch('orders/{order}/status', [OrderController::class, 'updateStatus']);

    // ---------- Customer ----------
    Route::middleware('role:customer')->group(function () {
        Route::get('home', [CatalogController::class, 'home']);

        Route::get('cart', [CartController::class, 'show']);
        Route::post('cart/items', [CartController::class, 'add']);
        Route::patch('cart/items/{item}', [CartController::class, 'update']);
        Route::delete('cart/items/{item}', [CartController::class, 'remove']);
        Route::delete('cart', [CartController::class, 'clear']);

        Route::post('orders', [OrderController::class, 'store'])->middleware('throttle:10,1');
        Route::post('orders/{order}/reorder', [OrderController::class, 'reorder']);
        Route::post('orders/{order}/reviews', [CustomerController::class, 'review']);

        Route::get('favorites', [CustomerController::class, 'favorites']);
        Route::post('favorites/{store}', [CustomerController::class, 'toggleFavorite']);
    });

    // ---------- Driver ----------
    Route::middleware('role:driver')->prefix('driver')->group(function () {
        Route::get('dashboard', [DriverController::class, 'dashboard']);
        Route::post('availability', [DriverController::class, 'availability']);
        Route::get('deliveries', [DriverController::class, 'index']);
        Route::get('deliveries/{delivery}', [DriverController::class, 'show']);
        Route::post('deliveries/{delivery}/accept', [DriverController::class, 'accept']);
        Route::post('deliveries/{delivery}/reject', [DriverController::class, 'reject']);
        Route::post('deliveries/{delivery}/release', [DriverController::class, 'release']);
        Route::patch('deliveries/{delivery}/status', [DriverController::class, 'updateStatus']);
    });

    // ---------- Store owner / staff (admins may also use these) ----------
    Route::middleware('role:store_owner,admin')->group(function () {
        Route::put('stores/{store}', [StoreController::class, 'update']);
        Route::post('stores/{store}', [StoreController::class, 'update']); // multipart with logo/cover

        Route::post('products', [ProductController::class, 'store']);
        Route::put('products/{product}', [ProductController::class, 'update']);
        Route::post('products/{product}', [ProductController::class, 'update']); // multipart with image
        Route::delete('products/{product}', [ProductController::class, 'destroy']);

        Route::post('orders/{order}/request-driver', [OrderController::class, 'requestDriver']);
    });
    Route::middleware('role:store_owner')->prefix('store')->group(function () {
        Route::get('stores', [StoreDashboardController::class, 'myStores']);
        Route::get('dashboard', [StoreDashboardController::class, 'dashboard']);
        Route::get('reports', [StoreDashboardController::class, 'reports']);
    });

    // ---------- Administrator ----------
    Route::middleware('role:admin')->group(function () {
        Route::post('stores', [StoreController::class, 'store']);

        Route::prefix('admin')->group(function () {
            Route::get('dashboard', [AdminDashboardController::class, 'dashboard']);
            Route::get('reports', [AdminDashboardController::class, 'reports']);
            Route::get('reports/export', [AdminDashboardController::class, 'export']);

            Route::get('roles', [AdminUserController::class, 'roles']);
            Route::get('users', [AdminUserController::class, 'index']);
            Route::post('users', [AdminUserController::class, 'store']);
            Route::get('users/{user}', [AdminUserController::class, 'show']);
            Route::put('users/{user}', [AdminUserController::class, 'update']);
            Route::patch('users/{user}/status', [AdminUserController::class, 'updateStatus']);

            Route::patch('drivers/{user}/verification', [AdminUserController::class, 'verifyDriver']);
            Route::patch('drivers/{user}/active', [AdminUserController::class, 'setDriverActive']);
            Route::get('drivers/{user}/deliveries', [AdminUserController::class, 'driverDeliveries']);

            Route::get('stores', [AdminStoreController::class, 'index']);
            Route::patch('stores/{store}/status', [AdminStoreController::class, 'updateStatus']);
            Route::delete('stores/{store}', [AdminStoreController::class, 'destroy']);
            Route::get('store-applications', [AdminStoreController::class, 'applications']);
            Route::post('store-applications/{application}/approve', [AdminStoreController::class, 'approve']);
            Route::post('store-applications/{application}/reject', [AdminStoreController::class, 'reject']);

            Route::get('orders', [OrderController::class, 'index']);

            Route::get('campus', [AdminCampusController::class, 'tree']);
            Route::post('faculties', [AdminCampusController::class, 'storeFaculty']);
            Route::put('faculties/{faculty}', [AdminCampusController::class, 'updateFaculty']);
            Route::delete('faculties/{faculty}', [AdminCampusController::class, 'destroyFaculty']);
            Route::post('buildings', [AdminCampusController::class, 'storeBuilding']);
            Route::put('buildings/{building}', [AdminCampusController::class, 'updateBuilding']);
            Route::delete('buildings/{building}', [AdminCampusController::class, 'destroyBuilding']);
            Route::post('floors', [AdminCampusController::class, 'storeFloor']);
            Route::put('floors/{floor}', [AdminCampusController::class, 'updateFloor']);
            Route::delete('floors/{floor}', [AdminCampusController::class, 'destroyFloor']);
            Route::post('classrooms', [AdminCampusController::class, 'storeClassroom']);
            Route::put('classrooms/{classroom}', [AdminCampusController::class, 'updateClassroom']);
            Route::delete('classrooms/{classroom}', [AdminCampusController::class, 'destroyClassroom']);

            Route::get('categories', [AdminSystemController::class, 'categories']);
            Route::post('categories', [AdminSystemController::class, 'storeCategory']);
            Route::put('categories/{category}', [AdminSystemController::class, 'updateCategory']);
            Route::delete('categories/{category}', [AdminSystemController::class, 'destroyCategory']);

            Route::get('announcements', [AdminSystemController::class, 'announcements']);
            Route::post('announcements', [AdminSystemController::class, 'storeAnnouncement']);
            Route::post('announcements/{announcement}', [AdminSystemController::class, 'updateAnnouncement']);
            Route::delete('announcements/{announcement}', [AdminSystemController::class, 'destroyAnnouncement']);

            Route::get('settings', [AdminSystemController::class, 'settings']);
            Route::put('settings', [AdminSystemController::class, 'updateSettings']);
            Route::get('activity-logs', [AdminSystemController::class, 'activityLogs']);

            Route::get('support-tickets', [AdminSystemController::class, 'tickets']);
            Route::post('support-tickets/{ticket}/resolve', [AdminSystemController::class, 'resolveTicket']);
        });
    });
});
