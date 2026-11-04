import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wabap/colors.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD SplashScreen");
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              C.primary,
              C.secondary,
            ],
          ),
        ),
        child: Center(
            child: Column(
          children: [
            const Spacer(),
            SizedBox(width: 120, child: Image.asset('assets/images/logo.png')),
            const SizedBox(
              height: 30,
            ),
            const CircularProgressIndicator(
              color: C.white,
            ),
            const Spacer(),
          ],
        )),
      ),
    );
  }
}
