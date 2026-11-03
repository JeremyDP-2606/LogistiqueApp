import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/screen/users_screen.dart';

class UserItem extends ConsumerWidget {
  final User? user;

  const UserItem({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var curreentUserId = ref.read(authProvider.notifier).myId;

    const p = 15.0;
    if (user != null) {
      return InkWell(
        onTap: () {
          ref.read(authProvider.notifier).myId = user!.sub;
          ref.read(authProvider.notifier).name = user!.givenName;
          ref.read(authProvider.notifier).clientName = user!.clientName;
          Navigator.of(context).pop();
        },
        child: Container(
          color: curreentUserId == user!.sub ? C.primary_highlight : null,
          child: Padding(
            padding: const EdgeInsets.only(left: p, top: p / 2, right: p, bottom: p / 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(width: 15, "assets/images/user.png"),
                          const SizedBox(width: 3),
                          Text(
                            user!.name(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          )
                        ],
                      ),
                      Text(
                        user!.sub,
                        style: const TextStyle(fontSize: 12, color: C.textColor),
                      ),
                    ],
                  ),
                ),
                if (curreentUserId == user!.sub)
                  Padding(
                      padding: const EdgeInsets.all(10), child: Image.asset(width: 30, "assets/images/check_on.png"))
              ],
            ),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}
