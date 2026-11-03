import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/colors.dart';

class WidgetWeek extends ConsumerWidget {
  final List<bool>? week;

  const WidgetWeek({super.key, required this.week});

  static const daysOfWeek = ["L", "M", "M", "J", "V", "S", "D"];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (week != null) {
      int length = week!.length;
      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Row(
            children: List.generate(length + length - 1, (i) {
          int index = (i ~/ 2) % length;
          bool day = week![index];
          if (i % 2 == 1) {
            return const SizedBox(width: 5);
          }
          return Expanded(
            child: CircleAvatar(
              radius: 15.0,
              backgroundColor: day ? C.primary_verylight : C.disable,
              child: Text(
                daysOfWeek[index],
                style: TextStyle(
                  color: day ? C.primary : C.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList()),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}
