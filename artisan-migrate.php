<?php
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
    echo "<pre>Creating sessions table and migrating...\n";

    require __DIR__.'/vendor/autoload.php';
    $app = require_once __DIR__.'/bootstrap/app.php';
    $kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);

    $kernel->call('session:table');
    echo $kernel->output();

    $kernel->call('migrate --force');
    echo $kernel->output();

    echo "\n✅ Sessions table created and migrations done.\n</pre>";