<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
echo "<pre>Running Laravel maintenance commands...\n";

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);

$commands = [
    'config:clear',
    'cache:clear',
    'route:clear',
    'view:clear',
    'config:cache',
];

foreach ($commands as $cmd) {
    echo "\n> php artisan {$cmd}\n";
    $kernel->call($cmd);
    echo $kernel->output();
}

echo "\n✅ Done.\n</pre>";
