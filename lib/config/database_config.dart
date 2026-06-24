class DatabaseConfig {
  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  static const local = DatabaseConfig(
    host: String.fromEnvironment('PGHOST', defaultValue: '127.0.0.1'),
    port: int.fromEnvironment('PGPORT', defaultValue: 5432),
    database: String.fromEnvironment(
      'PGDATABASE',
      defaultValue: 'coffee_viet_24h',
    ),
    username: String.fromEnvironment('PGUSER', defaultValue: 'postgres'),
    password: String.fromEnvironment('PGPASSWORD', defaultValue: 'postgres'),
  );

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
}
