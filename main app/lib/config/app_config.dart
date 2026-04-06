class AppConfig {
  static const bool useFirestore = bool.fromEnvironment(
    'USE_FIRESTORE',
    defaultValue: true,
  );
}
