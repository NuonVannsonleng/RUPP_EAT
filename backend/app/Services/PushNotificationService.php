<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging (HTTP v1). Disabled until FCM_PROJECT_ID and
 * FCM_CREDENTIALS_PATH (service-account JSON) are set in .env.
 * In-app notifications are always stored in the database regardless.
 */
class PushNotificationService
{
    public function enabled(): bool
    {
        $path = config('services.fcm.credentials');

        return config('services.fcm.project_id') && $path && is_file($path);
    }

    public function send(?string $token, string $title, string $body, array $data = []): void
    {
        if (! $token || ! $this->enabled()) {
            return;
        }

        try {
            Http::withToken($this->accessToken())
                ->timeout(5)
                ->post('https://fcm.googleapis.com/v1/projects/'.config('services.fcm.project_id').'/messages:send', [
                    'message' => [
                        'token' => $token,
                        'notification' => ['title' => $title, 'body' => $body],
                        'data' => array_map('strval', $data),
                        'android' => ['priority' => 'high'],
                    ],
                ])->throw();
        } catch (\Throwable $e) {
            Log::warning('FCM push failed: '.$e->getMessage());
        }
    }

    /** OAuth2 access token from the service account (JWT bearer grant), cached ~55 min. */
    private function accessToken(): string
    {
        return Cache::remember('fcm_access_token', 3300, function () {
            $sa = json_decode(file_get_contents(config('services.fcm.credentials')), true);
            $now = time();
            $b64 = fn ($v) => rtrim(strtr(base64_encode($v), '+/', '-_'), '=');
            $header = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = $b64(json_encode([
                'iss' => $sa['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));
            openssl_sign("$header.$claims", $signature, $sa['private_key'], 'sha256WithRSAEncryption');
            $jwt = "$header.$claims.".$b64($signature);

            return Http::asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ])->throw()->json('access_token');
        });
    }
}
