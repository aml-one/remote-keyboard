const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);

const String kAppBuildDate = String.fromEnvironment('APP_BUILD_DATE');

String get kAppVersionLabel =>
    kAppBuildDate.isEmpty ? 'v$kAppVersion' : 'v$kAppVersion-$kAppBuildDate';
