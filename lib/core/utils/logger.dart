import 'package:logging/logging.dart';

class AppLogger {
  AppLogger._();

  static final Map<String, Logger> _loggers = {};

  static Logger getLogger(String name) {
    return _loggers.putIfAbsent(name, () => Logger(name));
  }

  static void init() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
      );
    });
  }
}
