import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/game_activity/game_icon_ai.dart';

void main() {
  test('parses valid picks and drops unknown icons or bad numbers', () {
    const reply =
        '```json\n{"games":[{"n":1,"icon":"Racing"},{"n":2,"icon":"banana"},'
        '{"n":9,"icon":"rpg"},{"n":"3","icon":"puzzle"}]}\n```';
    expect(parseGameIconResponse(reply, 3), {1: 'racing', 3: 'puzzle'});
  });

  test('returns empty for non-JSON replies', () {
    expect(parseGameIconResponse('sorry', 2), isEmpty);
  });
}
