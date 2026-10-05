/// Ambiente injetado em build-time via --dart-define=APP_ENV=...
/// Valores possíveis: 'dev' | 'prod'
/// Em produção (main): APP_ENV=prod — badge some do drawer.
/// Em preview (desenvolvimento): APP_ENV=dev — badge laranja aparece.
const String kAppEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
bool get kIsDev => kAppEnv != 'prod';

/// Hash curto do commit Git (7 chars) — muda a cada push no Vercel.
/// Localmente fica 'local'.
const String kBuildHash =
    String.fromEnvironment('BUILD_HASH', defaultValue: 'local');

/// Data e hora da compilação (dd/MM HH:mm, horário de Brasília) — injetada
/// pelo build.sh (Vercel) e pelo build_local.ps1. Como a versão local não tem
/// commit, é ela que mostra se você está rodando a compilação mais recente.
const String kBuildTime = String.fromEnvironment('BUILD_TIME');

/// Texto exibido no login e no menu: "v1.0.0+425 · 7d723f2 · 05/10 14:32"
String get kVersaoLabel =>
    'v1.0.0+425 · $kBuildHash${kBuildTime.isEmpty ? '' : ' · $kBuildTime'}';
