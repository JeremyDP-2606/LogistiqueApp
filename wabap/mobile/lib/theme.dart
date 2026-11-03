// Flutter 3.44+ moved CupertinoPageTransitionsBuilder from material to
// cupertino; importing both keeps this file compiling on every version.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wabap/colors.dart';

final ThemeData lightTheme = ThemeData(
  primaryColor: C.primary,
  brightness: Brightness.light,
  primarySwatch: C.app,
  textTheme: GoogleFonts.nunitoTextTheme(ThemeData().textTheme.copyWith(
      bodySmall: ThemeData().textTheme.bodySmall!.copyWith(color: C.text),
      bodyMedium: ThemeData().textTheme.bodyMedium!.copyWith(color: C.text),
      bodyLarge: ThemeData().textTheme.bodyLarge!.copyWith(color: C.text))),
  appBarTheme: AppBarTheme(
    backgroundColor: C.primary,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: GoogleFonts.nunito(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: C.primary,
      foregroundColor: Colors.white,
      textStyle: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: C.primary,
      textStyle: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
  }),
);

final ThemeData darkTheme = ThemeData(
  primaryColor: C.secondary,
  brightness: Brightness.dark,
  // Autres propriétés spécifiques au thème sombre...
);
