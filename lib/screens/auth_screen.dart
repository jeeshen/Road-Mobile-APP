import 'package:flutter/cupertino.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../models/user.dart';
import 'home_screen.dart';
import 'friends_screen.dart';

class AuthScreen extends StatefulWidget {
  final ValueChanged<User>? onAuthSuccess;

  const AuthScreen({super.key, this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter name and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? user;
      if (_isLogin) {
        user = await _authService.login(name, password);
      } else {
        user = await _authService.register(name, password);
      }

      if (user != null && mounted) {
        final authenticatedUser = user;
        setState(() {
          _isLoading = false;
        });
        await _sessionService.saveUser(authenticatedUser);
        if (widget.onAuthSuccess != null) {
          widget.onAuthSuccess!(authenticatedUser);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => FriendsScreen(currentUser: authenticatedUser),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _skipAuth() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.person_circle,
                  size: 80,
                  color: CupertinoColors.systemBlue,
                ),
                const SizedBox(height: 32),
                Text(
                  _isLogin ? 'Login' : 'Register',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Name',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Password',
                  obscureText: true,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isLoading ? null : _handleAuth,
                    child: _isLoading
                        ? const CupertinoActivityIndicator()
                        : Text(_isLogin ? 'Login' : 'Register'),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Don\'t have an account? Register'
                        : 'Already have an account? Login',
                    style: const TextStyle(
                      color: CupertinoColors.systemBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CupertinoButton(
                  onPressed: _skipAuth,
                  child: const Text(
                    'Skip - Continue as Guest',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

