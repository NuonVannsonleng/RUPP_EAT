<?php

use App\Http\Middleware\EnsureRole;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias(['role' => EnsureRole::class]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $json = function (string $message, int $status, array $errors = []) {
            $payload = ['success' => false, 'message' => $message, 'data' => null];
            if ($errors) {
                $payload['errors'] = $errors;
            }

            return response()->json($payload, $status);
        };

        $exceptions->render(function (ValidationException $e, Request $request) use ($json) {
            if ($request->is('api/*')) {
                return $json($e->validator->errors()->first() ?: 'The given data was invalid.', 422, $e->errors());
            }
        });
        $exceptions->render(function (AuthenticationException $e, Request $request) use ($json) {
            if ($request->is('api/*')) {
                return $json('Unauthenticated. Please log in again.', 401);
            }
        });
        $exceptions->render(function (AuthorizationException|AccessDeniedHttpException $e, Request $request) use ($json) {
            if ($request->is('api/*')) {
                return $json($e->getMessage() && $e->getMessage() !== 'This action is unauthorized.'
                    ? $e->getMessage() : 'You are not allowed to perform this action.', 403);
            }
        });
        $exceptions->render(function (ModelNotFoundException|NotFoundHttpException $e, Request $request) use ($json) {
            if ($request->is('api/*')) {
                return $json('The requested resource was not found.', 404);
            }
        });
        $exceptions->render(function (HttpExceptionInterface $e, Request $request) use ($json) {
            if ($request->is('api/*')) {
                return $json($e->getMessage() ?: 'Request failed.', $e->getStatusCode());
            }
        });
    })->create();
