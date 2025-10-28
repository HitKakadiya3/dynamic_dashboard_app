<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
echo "<pre>Running migrations...\n";

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);

$kernel->call('migrate --force');
echo $kernel->output();
echo "\n✅ Migration done.\n</pre>";
