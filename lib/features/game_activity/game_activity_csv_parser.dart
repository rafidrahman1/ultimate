import 'game_activity_session.dart';

List<GameActivitySession> parseGameActivityCsv(String content) {
  final cleaned = content.replaceFirst('\uFEFF', '');
  final lines = cleaned
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.isEmpty) return [];

  final header = lines.first.split(';').map((cell) => cell.trim().toLowerCase()).toList();
  final nameCol = header.indexOf('name');
  final dateCol = header.indexOf('date session');
  final timeCol = header.indexOf('time played');

  if (nameCol < 0 || dateCol < 0 || timeCol < 0) {
    throw FormatException(
      'Expected columns "Name", "Date session", and "Time Played".',
    );
  }

  final sessions = <GameActivitySession>[];
  for (var i = 1; i < lines.length; i++) {
    final row = lines[i].split(';');
    if (row.isEmpty || _rowIsBlank(row)) continue;

    final session = _parseRow(row, nameCol, dateCol, timeCol);
    if (session != null) sessions.add(session);
  }
  return sessions;
}

GameActivitySession? _parseRow(
  List<String> row,
  int nameCol,
  int dateCol,
  int timeCol,
) {
  String cell(int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  final name = cell(nameCol);
  if (name.isEmpty) return null;

  final dateRaw = cell(dateCol);
  if (dateRaw.isEmpty) return null;

  final sessionDate = DateTime.tryParse(dateRaw.replaceFirst('.000', ''));
  if (sessionDate == null) return null;

  final timePlayed = _parseDuration(cell(timeCol));
  if (timePlayed == null) return null;

  return GameActivitySession(
    name: name,
    sessionDate: sessionDate,
    timePlayed: timePlayed,
  );
}

Duration? _parseDuration(String raw) {
  final parts = raw.split(':');
  if (parts.length != 3) return null;

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = int.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) return null;

  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

bool _rowIsBlank(List<String> row) {
  return row.every((cell) => cell.trim().isEmpty);
}
