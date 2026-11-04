import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:wabap/v2/screens/signup_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wabap/colors.dart';
import 'package:wabap/provider/auth_provider.dart';

final obscurePasswordProvider = StateProvider<bool>((ref) => true);
final controllerUsername = TextEditingController();
final controllerPassword = TextEditingController();

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD LoginScreen");
    final GlobalKey<FormState> formKey = GlobalKey();
    final FocusNode focusNodePassword = FocusNode();
    final obscurePassword = ref.watch(obscurePasswordProvider);
    final auth = ref.watch(authProvider);

    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
          body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                C.primary,
                C.secondary,
              ],
              tileMode: TileMode.mirror,
            ),
          ),
          child: SafeArea(
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(width: 120, height: 300, child: Image.asset('assets/images/logo.png')),
                      TextFormField(
                        enabled: !auth.isLoading,
                        cursorColor: C.textColor,
                        controller: controllerUsername,
                        keyboardType: TextInputType.name,
                        decoration: InputDecoration(
                            errorStyle: const TextStyle(color: C.error),
                            labelText: "Identifiant",
                            labelStyle: const TextStyle(
                              color: C.labelColor,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: const Icon(Icons.mail),
                            prefixIconColor: const Color(0xffff9500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            fillColor: auth.isLoading ? C.white09 : C.white,
                            filled: true),
                        onEditingComplete: () => focusNodePassword.requestFocus(),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return "Merci de saisir votre identifiant.";
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        enabled: !auth.isLoading,
                        cursorColor: C.textColor,
                        controller: controllerPassword,
                        focusNode: focusNodePassword,
                        obscureText: obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                            labelText: "Mot de passe",
                            errorStyle: const TextStyle(color: C.error),
                            prefixIcon: const Icon(Icons.lock),
                            prefixIconColor: const Color(0xffff9500),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            suffixIcon: IconButton(
                                onPressed: () {
                                  ref.read(obscurePasswordProvider.notifier).state = !obscurePassword;
                                },
                                icon: obscurePassword
                                    ? const Icon(Icons.visibility_off_outlined)
                                    : const Icon(Icons.visibility_outlined)),
                            suffixIconColor: const Color(0xffff9500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            fillColor: auth.isLoading ? C.white09 : C.white,
                            filled: true),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return "Merci de saisir un mot de passe";
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 60),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: C.white,
                          disabledBackgroundColor: C.white09,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  final error = await auth.signInUser(
                                      controllerUsername.value.text, controllerPassword.value.text);
                                  if (error == null) controllerPassword.clear();
                                  if (error == AuthError.confirmSignInWithNewPassword && context.mounted) {
                                    await auth.showPasswordConfirmationDialog(context);
                                  } else if (error == AuthError.resetPassword && context.mounted) {
                                    final errorReset =
                                        await auth.showResetPassword(controllerUsername.value.text, context, ref);
                                    _showError(errorReset);
                                  } else {
                                    _showError(error);
                                  }
                                }
                              },
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: C.primary,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Connecter",
                                style: TextStyle(color: C.primary, fontSize: 18),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                        child: const Text(
                          "Pas encore de compte ? Créer un compte",
                          style: TextStyle(color: C.white, fontSize: 15, decoration: TextDecoration.underline, decorationColor: C.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      )),
    );
  }

  _showError(AuthError? error) {
    if (error == AuthError.userNotFound) {
      _showErrorMessage("Utilisateur inconnu");
    } else if (error == AuthError.networkError) {
      _showErrorMessage("Aucune connexion internet");
    } else if (error == AuthError.passwordIncorrect) {
      _showErrorMessage("Mot de passe incorrect");
    } else if (error == AuthError.unknownError) {
      _showErrorMessage("Erreur inconnue");
    } else if (error == AuthError.codeResetPasswordInvalide) {
      _showErrorMessage("Le code de réinitialisation de mot de passe est invalide");
    } else if (error == AuthError.unknownError) {
      _showErrorMessage("Erreur inconnue");
    }
  }

  _showErrorMessage(String error) {
    scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(backgroundColor: C.error, content: Text(error)));
  }
}
