import 'package:flutter/cupertino.dart';
import '../models/character.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../widgets/animated_character_marker.dart';

class ShopScreen extends StatefulWidget {
  final User currentUser;
  final Function(User) onCharacterSelected;

  const ShopScreen({
    super.key,
    required this.currentUser,
    required this.onCharacterSelected,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<Character> _characters = Character.getAllCharacters();
  String? _selectedCharacterId;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedCharacterId = widget.currentUser.selectedCharacter;
  }

  Color _getColorForCharacter(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'black':
        return const Color(0xFF2C2C2C);
      case 'blue':
        return CupertinoColors.systemBlue;
      case 'red':
        return CupertinoColors.systemRed;
      case 'yellow':
        return CupertinoColors.systemYellow;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  Future<void> _selectCharacter(Character character) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedUser = widget.currentUser.copyWith(
        selectedCharacter: character.id,
      );
      
      await _firebaseService.updateUser(updatedUser);
      
      setState(() {
        _selectedCharacterId = character.id;
        _isUpdating = false;
      });
      
      widget.onCharacterSelected(updatedUser);
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to select character: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Character Shop'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: _isUpdating
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Your Character',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Choose a character to represent you on the map',
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final character = _characters[index];
                          final isSelected =
                              character.id == _selectedCharacterId;

                          return GestureDetector(
                            onTap: () => _selectCharacter(character),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? CupertinoColors.systemBlue
                                      : CupertinoColors.separator.withValues(alpha: 0.3),
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: CupertinoColors.systemBlue
                                              .withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                          spreadRadius: 0,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: CupertinoColors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      // Character animation area
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                            left: 8,
                                            right: 8,
                                          ),
                                          child: Center(
                                            child: AnimatedCharacterMarker(
                                              key: ValueKey(character.id),
                                              actions: character.actions,
                                              userName: '',
                                              showName: false,
                                              enableClick: false,
                                              scale: character.name.toLowerCase() == 'lancer' 
                                                  ? 1.4 
                                                  : 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Info section
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? CupertinoColors.systemBlue
                                                  .withValues(alpha: 0.1)
                                              : CupertinoColors.systemGrey6
                                                  .withValues(alpha: 0.5),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(14),
                                            bottomRight: Radius.circular(14),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              character.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? CupertinoColors.systemBlue
                                                    : CupertinoColors.label,
                                                letterSpacing: -0.3,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getColorForCharacter(
                                                  character.color,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                character.color,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: CupertinoColors.white,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Selected indicator
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: CupertinoColors.systemGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.checkmark,
                                          color: CupertinoColors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _characters.length,
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
      ),
    );
  }
}

