<?php
declare(strict_types=1);
require __DIR__ . '/bootstrap.php';
$catalogs = [];
foreach (['fakegps.json', 'ipa-plus.json'] as $file) {
    $doc = json_decode((string) file_get_contents(__DIR__ . '/' . $file), true);
    if (is_array($doc) && is_array($doc['apps'] ?? null)) {
        $catalogs[] = ['file' => $file, 'document' => $doc];
    }
}
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>مصادر WolFox</title><link rel="stylesheet" href="/assets/style.css"><link rel="icon" href="/assets/wolfox-mark.png"></head>
<body><header class="site-header"><a class="brand" href="/"><img src="/assets/wolfox-mark.png" alt="WolFox"><strong>WolFox</strong></a></header>
<main class="shell"><h1>مصادر التطبيقات</h1><p>انسخ رابط المصدر وأضفه داخل التطبيق. ملفات التطبيقات تُنزّل من مزوّدها الأصلي.</p>
<?php foreach ($catalogs as $catalog): $doc = $catalog['document']; $url = public_base_url() . '/' . $catalog['file']; ?>
<section><h2><?= e((string) ($doc['name'] ?? 'مصدر')) ?></h2><p><?= count($doc['apps']) ?> تطبيقات</p>
<a class="button primary" href="<?= e($url) ?>">فتح المصدر</a><p dir="ltr"><code><?= e($url) ?></code></p>
<details><summary>عرض التطبيقات</summary><ul>
<?php foreach ($doc['apps'] as $app): ?><li><?= e((string) ($app['name'] ?? '')) ?> — <span dir="ltr"><?= e((string) ($app['versions'][0]['version'] ?? $app['version'] ?? '')) ?></span></li><?php endforeach; ?>
</ul></details></section>
<?php endforeach; ?></main></body></html>
