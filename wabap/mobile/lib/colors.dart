// ignore_for_file: constant_identifier_names

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';

class C {
  static const MaterialColor app = MaterialColor(
    _appPrimaryValue,
    <int, Color>{
      50: Color(0xffffc573),
      100: Color(0xffffbf66),
      200: Color(0xffffb54d),
      300: Color(0xffffaa33),
      400: Color(0xffffa019),
      500: Color(_appPrimaryValue),
      600: Color(0xffe58600),
      700: Color(0xffcc7700),
      800: Color(0xffb26800),
      900: Color(0xff995900),
    },
  );
  static const int _appPrimaryValue = 0xffff9500;

  static const primary = Color(0xffff9500);
  static const secondary = Color(0xfff26f00);
  static const pin_static_start = Color(0xFF40AD48);
  static const primary_light = Color(0xFFFDCC87);
  static const primary_verylight = Color(0xFFFFE5CB);
  static const primary_highlight = Color.fromARGB(29, 255, 149, 0);

  static const route = Color(0xFFFDCC87);
  static const route_border = Color(0xfff26f00);
  static const route_done = Color.fromARGB(75, 253, 204, 135);
  static const route_done_border = Color.fromARGB(75, 242, 113, 0);
  static const white = Colors.white;
  static const black = Colors.black;
  static const transparent = Colors.transparent;
  static const overlay = Color.fromARGB(170, 0, 0, 0);
  static const white09 = Color.fromRGBO(255, 255, 255, 0.9);
  static const white05 = Color.fromRGBO(255, 255, 255, 0.5);
  static const disable = Color.fromARGB(255, 214, 214, 214);
  static const textColor = Color(0xff707070);
  static const labelColor = Color(0xff707070);
  static const text = Color(0xFF3C3C3C);
  static const error = Color(0xfffa3a00);
  static const nok = Color(0xffdba0a0);
  static const ok = Color(0xFF608B32);
  static const blue = Color(0xFF2196F3);

  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.r.round(), g = color.g.round(), b = color.b.round();

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      final s = (strength * 1000).round();
      final c = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
      swatch[s] = c;
      safePrint("$s: Color($c),");
    }
    return MaterialColor(color.toARGB32(), swatch);
  }
}
