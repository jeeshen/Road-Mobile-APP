class CharacterAction {
  final String name;
  final String assetPath;
  final int frameCount;

  CharacterAction({
    required this.name,
    required this.assetPath,
    required this.frameCount,
  });
}

class Character {
  final String id; // e.g., "blue_warrior"
  final String name; // e.g., "Warrior"
  final String color; // e.g., "Blue"
  final List<CharacterAction> actions; // All available actions

  Character({
    required this.id,
    required this.name,
    required this.color,
    required this.actions,
  });

  CharacterAction get idleAction => actions.first;

  // ═══════════════════════════════════════════════════════════════════════════
  // FRAME CONFIGURATION - Adjust frame counts here to match your sprite sheets
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, Map<String, int>> frameConfigs = {
    // WARRIOR FRAMES
    'warrior': {
      'idle': 8, // Warrior_Idle.png
      'attack1': 4, // Warrior_Attack1.png
      'attack2': 4, // Warrior_Attack2.png
      'guard': 2, // Warrior_Guard.png
      'run': 6, // Warrior_Run.png
    },

    // ARCHER FRAMES
    'archer': {
      'idle': 6, // Archer_Idle.png
      'run': 4, // Archer_Run.png
      'shoot': 8, // Archer_Shoot.png
    },

    // MONK FRAMES
    'monk': {
      'idle': 6, // Idle.png
      'run': 4, // Run.png
      'heal': 11, // Heal.png
    },

    // LANCER FRAMES
    'lancer': {
      'idle': 12, // Lancer_Idle.png
      'run': 6, // Lancer_Run.png
      'right_attack': 3, // Lancer_Right_Attack.png
      'right_defence': 6, // Lancer_Right_Defence.png
      'down_attack': 3, // Lancer_Down_Attack.png (optional)
      'down_defence': 6, // Lancer_Down_Defence.png (optional)
    },
  };

  static List<Character> getAllCharacters() {
    final colors = ['Black', 'Blue', 'Red', 'Yellow'];
    List<Character> characters = [];

    for (var color in colors) {
      // WARRIOR
      characters.add(
        Character(
          id: '${color.toLowerCase()}_warrior',
          name: 'Warrior',
          color: color,
          actions: [
            CharacterAction(
              name: 'idle',
              assetPath:
                  'assets/characters/$color Units/Warrior/Warrior_Idle.png',
              frameCount: frameConfigs['warrior']!['idle']!,
            ),
            CharacterAction(
              name: 'attack1',
              assetPath:
                  'assets/characters/$color Units/Warrior/Warrior_Attack1.png',
              frameCount: frameConfigs['warrior']!['attack1']!,
            ),
            CharacterAction(
              name: 'attack2',
              assetPath:
                  'assets/characters/$color Units/Warrior/Warrior_Attack2.png',
              frameCount: frameConfigs['warrior']!['attack2']!,
            ),
            CharacterAction(
              name: 'guard',
              assetPath:
                  'assets/characters/$color Units/Warrior/Warrior_Guard.png',
              frameCount: frameConfigs['warrior']!['guard']!,
            ),
            CharacterAction(
              name: 'run',
              assetPath:
                  'assets/characters/$color Units/Warrior/Warrior_Run.png',
              frameCount: frameConfigs['warrior']!['run']!,
            ),
          ],
        ),
      );

      // ARCHER
      characters.add(
        Character(
          id: '${color.toLowerCase()}_archer',
          name: 'Archer',
          color: color,
          actions: [
            CharacterAction(
              name: 'idle',
              assetPath:
                  'assets/characters/$color Units/Archer/Archer_Idle.png',
              frameCount: frameConfigs['archer']!['idle']!,
            ),
            CharacterAction(
              name: 'run',
              assetPath: 'assets/characters/$color Units/Archer/Archer_Run.png',
              frameCount: frameConfigs['archer']!['run']!,
            ),
            CharacterAction(
              name: 'shoot',
              assetPath:
                  'assets/characters/$color Units/Archer/Archer_Shoot.png',
              frameCount: frameConfigs['archer']!['shoot']!,
            ),
          ],
        ),
      );

      // MONK
      characters.add(
        Character(
          id: '${color.toLowerCase()}_monk',
          name: 'Monk',
          color: color,
          actions: [
            CharacterAction(
              name: 'idle',
              assetPath: 'assets/characters/$color Units/Monk/Idle.png',
              frameCount: frameConfigs['monk']!['idle']!,
            ),
            CharacterAction(
              name: 'run',
              assetPath: 'assets/characters/$color Units/Monk/Run.png',
              frameCount: frameConfigs['monk']!['run']!,
            ),
            CharacterAction(
              name: 'heal',
              assetPath: 'assets/characters/$color Units/Monk/Heal.png',
              frameCount: frameConfigs['monk']!['heal']!,
            ),
          ],
        ),
      );

      // LANCER
      characters.add(
        Character(
          id: '${color.toLowerCase()}_lancer',
          name: 'Lancer',
          color: color,
          actions: [
            CharacterAction(
              name: 'idle',
              assetPath:
                  'assets/characters/$color Units/Lancer/Lancer_Idle.png',
              frameCount: frameConfigs['lancer']!['idle']!,
            ),
            CharacterAction(
              name: 'run',
              assetPath: 'assets/characters/$color Units/Lancer/Lancer_Run.png',
              frameCount: frameConfigs['lancer']!['run']!,
            ),
            CharacterAction(
              name: 'right_attack',
              assetPath:
                  'assets/characters/$color Units/Lancer/Lancer_Right_Attack.png',
              frameCount: frameConfigs['lancer']!['right_attack']!,
            ),
            CharacterAction(
              name: 'right_defence',
              assetPath:
                  'assets/characters/$color Units/Lancer/Lancer_Right_Defence.png',
              frameCount: frameConfigs['lancer']!['right_defence']!,
            ),
            // Add more lancer actions here if needed:
            // CharacterAction(
            //   name: 'down_attack',
            //   assetPath: 'assets/characters/$color Units/Lancer/Lancer_Down_Attack.png',
            //   frameCount: frameConfigs['lancer']!['down_attack']!,
            // ),
          ],
        ),
      );
    }
    return characters;
  }
}
