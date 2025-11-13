import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import 'password_reset_screen.dart'; // パスワードリセット画面のインポートを追加

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emergency,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '災害報告アプリ',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'メールアドレスを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'パスワードを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      // 日本語エラーメッセージに変換
                      String? jpError;
                      if (authProvider.errorMessage != null) {
                        switch (authProvider.errorMessage) {
                          case 'Invalid email or password':
                            jpError = 'メールアドレスまたはパスワードが正しくありません';
                            break;
                          case 'User not found':
                            jpError = 'ユーザーが見つかりません';
                            break;
                          case 'Email already in use':
                            jpError = 'このメールアドレスは既に使用されています';
                            break;
                          case 'Network error':
                            jpError = 'ネットワークエラーが発生しました';
                            break;
                          case 'Password should be at least 6 characters':
                            jpError = 'パスワードは6文字以上で入力してください';
                            break;
                          case 'The email address is badly formatted.':
                            jpError = 'メールアドレスの形式が正しくありません';
                            break;
                          case 'Too many requests. Try again later.':
                            jpError = 'リクエストが多すぎます。しばらくしてから再度お試しください';
                            break;
                          case 'User disabled':
                            jpError = 'このユーザーは無効化されています';
                            break;
                          case 'Operation not allowed':
                            jpError = 'この操作は許可されていません';
                            break;
                          case 'Account exists with different credential':
                            jpError = '異なる認証情報で既にアカウントが存在します';
                            break;
                          case 'Invalid credential':
                            jpError = '認証情報が正しくありません';
                            break;
                          default:
                            jpError = authProvider.errorMessage; // その他はそのまま表示
                        }
                      }
                      return Column(
                        children: [
                          if (jpError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                jpError,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
                                        if (_isLogin) {
                                          await authProvider.signInWithEmailAndPassword(
                                            _emailController.text,
                                            _passwordController.text,
                                          );
                                        } else {
                                          await authProvider.signUp(
                                            _emailController.text,
                                            _passwordController.text,
                                          );
                                        }
                                        if (authProvider.isAuthenticated && context.mounted) {
                                          context.go('/home');
                                        }
                                      }
                                    },
                              child: authProvider.isLoading
                                  ? const CircularProgressIndicator()
                                  : Text(_isLogin ? 'ログイン' : '新規登録'),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? 'アカウントをお持ちでない方はこちら（新規登録）'
                                  : 'すでにアカウントをお持ちの方はこちら（ログイン）',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PasswordResetScreen(),
                                ),
                              );
                            },
                            child: const Text('パスワードをお忘れですか？'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}