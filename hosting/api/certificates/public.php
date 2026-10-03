<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function certificate_error(string $message, int $status): never {
    http_response_code($status);
    echo json_encode(['error' => $message], JSON_UNESCAPED_SLASHES);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') certificate_error('method_not_allowed', 405);
$id = trim((string) ($_GET['certificate_id'] ?? ''));
if (preg_match('/^[A-Za-z0-9._-]{1,128}$/', $id) !== 1) certificate_error('invalid_certificate_id', 400);
$config = require dirname(__DIR__, 2) . '/config.php';
$endpoint = (string) ($config['scarlet_api'] ?? '');
$parts = parse_url($endpoint);
if (!is_array($parts) || ($parts['scheme'] ?? '') !== 'https' || ($parts['host'] ?? '') !== 'api.nekoo.eu.org' || isset($parts['user']) || isset($parts['pass'])) {
    certificate_error('provider_not_configured', 503);
}
if (!function_exists('curl_init')) certificate_error('curl_unavailable', 503);
$url = $endpoint . (str_contains($endpoint, '?') ? '&' : '?') . http_build_query(['certificate_id' => $id]);
$body = '';
$tooLarge = false;
$curl = curl_init($url);
curl_setopt_array($curl, [
    CURLOPT_CONNECTTIMEOUT => 5, CURLOPT_TIMEOUT => 20,
    CURLOPT_FOLLOWLOCATION => false, CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
    CURLOPT_SSL_VERIFYPEER => true, CURLOPT_SSL_VERIFYHOST => 2,
    CURLOPT_HTTPHEADER => ['Accept: application/json'],
    CURLOPT_WRITEFUNCTION => static function ($handle, string $chunk) use (&$body, &$tooLarge): int {
        if (strlen($body) + strlen($chunk) > 10 * 1024 * 1024) { $tooLarge = true; return 0; }
        $body .= $chunk;
        return strlen($chunk);
    },
]);
$ok = curl_exec($curl);
$status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
curl_close($curl);
if ($status === 404) certificate_error('certificate_not_found', 404);
if ($ok === false || $tooLarge || $status < 200 || $status >= 300) certificate_error('provider_unavailable', 502);
$payload = json_decode($body, true);
if (!is_array($payload)) certificate_error('invalid_provider_response', 502);
echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
