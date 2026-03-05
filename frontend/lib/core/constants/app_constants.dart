class AppConstants {
  AppConstants._();

  static const String appName = 'ChatApp';
  static const int messagePageSize = 30;
  static const int searchResultLimit = 20;
  static const Duration wsReconnectBaseDelay = Duration(seconds: 1);
  static const int wsMaxReconnectAttempts = 5;
}
