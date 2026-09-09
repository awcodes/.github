<?php

declare(strict_types=1);

use Rector\Config\RectorConfig;

try {
    return RectorConfig::configure()
        ->withPaths([
            __DIR__ . '/src',
            // Dev-only, but hand-written — refactored on the same terms as src.
            // Drop this line if the package has no workbench/: rector hard-errors
            // on a path that does not exist.
            __DIR__ . '/workbench',
            // Shipped code, so refactored on the same terms as src. Listed rather than
            // commented out on purpose: rector hard-errors on a missing path, so a
            // package without one fails loudly on the first run and you delete the line.
            // Pint already covers both (pint.json declares no exclude), so listing them
            // here is what makes all four checks agree on the same tree.
            __DIR__ . '/config',
            __DIR__ . '/database',
        ])
        // Compiled Blade under workbench/storage is gitignored but present locally
        // once the workbench app has been run, and it is not valid standalone PHP.
        // Unlike withPaths(), withSkip() tolerates a path that is not there.
        ->withSkip([
            __DIR__ . '/workbench/storage',
        ])
        ->withPreparedSets(
            deadCode: true,
            codeQuality: true,
            typeDeclarations: true,
            privatization: true,
            earlyReturn: true,
        )
        ->withPhpSets();
} catch (Rector\Exception\Configuration\InvalidConfigurationException $e) {
    echo 'Error: ' . $e->getMessage() . PHP_EOL;
    exit(1);
}
