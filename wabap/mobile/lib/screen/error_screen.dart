import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ErrorScreen extends ConsumerWidget {
  final String error;
  const ErrorScreen(this.error, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD ErrorScreen");

    return Scaffold(
      body: Center(
          child: Column(
        children: [
          const Spacer(),
          SizedBox(width: 150, child: Image.asset('assets/images/404.png')),
          const SizedBox(
            height: 30,
          ),
          const Text(
            "Erreur !\nImpossible de charger la page...",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Row(
            children: [
              InkWell(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text(
                            "ERREUR :",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: SingleChildScrollView(child: Text(error)),
                        );
                      });
                },
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Image.asset(width: 20, "assets/images/info.png"),
                ),
              ),
            ],
          )
        ],
      )),
    );
  }
}
