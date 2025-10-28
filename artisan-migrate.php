<?php
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
    echo "<pre>Running migrate:fresh...\n";

    // Avoid hitting database sessions during migration
    putenv('SESSION_DRIVER=file');
    $_ENV['SESSION_DRIVER'] = 'file';
    $_SERVER['SESSION_DRIVER'] = 'file';

    require __DIR__.'/vendor/autoload.php';
    $app = require_once __DIR__.'/bootstrap/app.php';
    $kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);

    // Drop all tables and re-run all migrations
    $kernel->call('migrate:fresh --force');
    echo $kernel->output();

    echo "\n✅ Fresh migration completed.\n</pre>";