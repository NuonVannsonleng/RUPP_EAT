<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Usage: ->middleware('role:admin') or ->middleware('role:store_owner,admin')
 * Also blocks suspended accounts on every protected route.
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Unauthenticated.', 'data' => null], 401);
        }

        if (! $user->isActive()) {
            return response()->json(['success' => false, 'message' => 'Your account is suspended. Please contact RUPP Eat support.', 'data' => null], 403);
        }

        if ($roles && ! $user->hasRole(...$roles)) {
            return response()->json(['success' => false, 'message' => 'You do not have permission to access this resource.', 'data' => null], 403);
        }

        return $next($request);
    }
}
