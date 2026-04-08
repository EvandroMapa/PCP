/// Ambiente injetado em build-time via --dart-define=APP_ENV=...
/// Valores possíveis: 'dev' | 'prod'
/// Em produção (main): APP_ENV=prod — badge some do drawer.
/// Em preview (desenvolvimento): APP_ENV=dev — badge laranja aparece.
const String kAppEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
bool get kIsDev => kAppEnv != 'prod';
