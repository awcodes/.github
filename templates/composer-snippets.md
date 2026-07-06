# Canonical `composer.json` snippets

Merge these into each package. **Do not** change the runtime `require` block
(`"php": "^8.2"`, `filament/filament`, etc.) — Laravel 11 support stays; only CI drops it.

## `require-dev` (normalized dev-tool versions)

```json
"require-dev": {
    "larastan/larastan": "^3.0",
    "laravel/pint": "^1.0",
    "nunomaduro/collision": "^8.0",
    "orchestra/testbench": "^9.0|^10.0|^11.0",
    "pestphp/pest": "^4.0",
    "pestphp/pest-plugin-arch": "^4.0",
    "pestphp/pest-plugin-laravel": "^4.0",
    "pestphp/pest-plugin-livewire": "^4.0",
    "rector/rector": "^2.0",
    "spatie/laravel-ray": "^1.26"
}
```

Keep any package-specific dev deps already present. Drop `pest-plugin-livewire` if the
package has no Livewire tests.

## `scripts`

```json
"scripts": {
    "post-autoload-dump": "@php ./vendor/bin/testbench package:discover --ansi",
    "lint": "pint",
    "refactor": "rector",
    "test:lint": "pint --test",
    "test:refactor": "rector --dry-run",
    "test:types": "phpstan analyse",
    "test:unit": "pest",
    "test": [
        "@test:refactor",
        "@test:lint",
        "@test:types",
        "@test:unit"
    ]
}
```

## `config.allow-plugins`

Ensure Pest's plugin is allowed:

```json
"config": {
    "allow-plugins": {
        "pestphp/pest-plugin": true,
        "phpstan/extension-installer": true
    }
}
```
