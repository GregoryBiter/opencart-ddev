<?php
/**
 * Пересборка OCMOD-модификаций из CLI (аналог кнопки «Обновить» в Модификациях админки).
 * Запускается внутри web-контейнера DDEV: ddev oc-ocmod
 *
 * Аргументы: <корень сайта> <папка админки>
 */

$root      = rtrim($argv[1] ?? '/var/www/html', '/');
$admin_dir = $argv[2] ?? 'admin';

$admin_config = $root . '/' . $admin_dir . '/config.php';
if (!is_file($admin_config)) {
    fwrite(STDERR, "Не найден {$admin_config}. Сначала выполните: make config\n");
    exit(1);
}

chdir($root . '/' . $admin_dir);

$_SERVER['REMOTE_ADDR']     = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
$_SERVER['HTTPS']           = $_SERVER['HTTPS'] ?? false;
$_SERVER['SERVER_PORT']     = $_SERVER['SERVER_PORT'] ?? 443;
$_SERVER['HTTP_HOST']       = $_SERVER['HTTP_HOST'] ?? 'localhost';
$_SERVER['REQUEST_METHOD']  = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// VERSION обычно объявляется в admin/index.php — берём оттуда же
if (!defined('VERSION')) {
    $index = @file_get_contents($root . '/' . $admin_dir . '/index.php');
    if ($index && preg_match("/define\\(\\s*'VERSION'\\s*,\\s*'([^']+)'/", $index, $m)) {
        define('VERSION', $m[1]);
    }
}

require_once $admin_config;
require_once DIR_SYSTEM . 'startup.php';

$registry = new Registry();

$config = new Config();
$config->load('default');
$config->load('admin');
$registry->set('config', $config);

$event = new Event($registry);
$registry->set('event', $event);

$loader = new Loader($registry);
$registry->set('load', $loader);

$request = new Request();
$registry->set('request', $request);

$response = new Response();
$registry->set('response', $response);

$db = new DB($config->get('db_engine'), $config->get('db_hostname'), $config->get('db_username'), $config->get('db_password'), $config->get('db_database'), $config->get('db_port'));
$registry->set('db', $db);

// Настройки магазина (config_limit_admin, config_language и т.д.) — как в admin/controller/startup/setting.php
$query = $db->query("SELECT * FROM `" . DB_PREFIX . "setting` WHERE `store_id` = '0'");
foreach ($query->rows as $setting) {
    $config->set($setting['key'], $setting['serialized'] ? json_decode($setting['value'], true) : $setting['value']);
}
if (!$config->get('config_limit_admin')) {
    $config->set('config_limit_admin', 20);
}

$session = new Session($config->get('session_engine'), $registry);
$registry->set('session', $session);
$session->start();

$token = token(32);
$session->data['user_token'] = $token;
$request->get['user_token']  = $token;

// Пользователь с правом modify на модификации
$user_query = $db->query("SELECT u.`user_id` FROM `" . DB_PREFIX . "user` u
    LEFT JOIN `" . DB_PREFIX . "user_group` ug ON (u.`user_group_id` = ug.`user_group_id`)
    WHERE u.`status` = '1' AND ug.`permission` LIKE '%modification%'
    ORDER BY u.`user_id` ASC LIMIT 1");
if (!$user_query->num_rows) {
    fwrite(STDERR, "Не найден активный администратор с правами на модификации.\n");
    exit(1);
}
$session->data['user_id'] = (int)$user_query->row['user_id'];

$registry->set('cache', new Cache($config->get('cache_engine'), $config->get('cache_expire')));
$registry->set('url', new Url(HTTP_SERVER, HTTPS_SERVER));

$lang_code = $config->get('config_admin_language') ?: ($config->get('language_directory') ?: 'en-gb');
$language = new Language($lang_code);
$language->load($lang_code);
$registry->set('language', $language);

$registry->set('document', new Document());
$registry->set('user', new Cart\User($registry));

foreach (['config_autoload' => 'config', 'language_autoload' => 'language', 'library_autoload' => 'library', 'model_autoload' => 'model'] as $key => $method) {
    if ($config->has($key)) {
        foreach ($config->get($key) as $value) {
            $loader->$method($value);
        }
    }
}

$route = is_file(DIR_APPLICATION . 'controller/marketplace/modification.php')
    ? 'marketplace/modification/refresh'
    : 'extension/modification/refresh';

// refresh() в конце делает redirect() с exit — фиксируем результат в shutdown
register_shutdown_function(function () use ($root) {
    $dir = $root . '/system/storage/modification';
    $count = 0;
    if (is_dir($dir)) {
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $file) {
            if ($file->isFile() && $file->getFilename() !== 'index.html') {
                $count++;
            }
        }
    }
    $err = error_get_last();
    if ($err && in_array($err['type'], [E_ERROR, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR], true)) {
        fwrite(STDERR, "Ошибка: {$err['message']} ({$err['file']}:{$err['line']})\n");
    }
    echo "✓ Модификации пересобраны: файлов в system/storage/modification — {$count}\n";
    echo "  Лог: system/storage/logs/ocmod.log\n";
});

$action = new Action($route);
$result = $action->execute($registry);

if ($result instanceof Exception) {
    fwrite(STDERR, $result->getMessage() . "\n");
    exit(1);
}
