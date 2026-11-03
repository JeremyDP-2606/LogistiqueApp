import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:wabap/colors.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/widgets/item_user.dart';

class UsersScreen extends HookConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD UsersScreen");

    final clientName = ref.read(authProvider.notifier).clientName;
    final isSuperAdmin = ref.watch(authProvider).isSuperAdmin;

    return Scaffold(
      body: Center(
        child: FutureBuilder<List<User>>(
          future: fetchUsers(clientName, isSuperAdmin),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return UserItem(user: snapshot.data![index]);
                },
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
      appBar: AppBar(
        title: const Text(
          "Choisisez un utilisateur",
          style: TextStyle(color: C.white),
        ),
      ),
    );
  }

  Future<List<User>> fetchUsers(String? clientName, bool isSuperAdmin) async {
    final response = await Amplify.API.get('/users').response;
    if (response.statusCode == 200) {
      List<dynamic> apiResponse = jsonDecode(response.decodeBody());
      List<User> users = apiResponse.map((user) => User.fromJson(user)).toList();
      return users
          .where((user) => user.clientName == clientName || isSuperAdmin)
          .toList(); //TODO : do this in lambda for security
    } else {
      throw Exception('Failed to load users');
    }
  }
}

class User {
  final String sub;
  final String? givenName;
  final String? familyName;
  final String? clientName;

  User({required this.sub, this.givenName, this.familyName, this.clientName});

  name() {
    return "${givenName != null ? ("$givenName ") : ""}${familyName ?? ""} ${clientName != null ? "($clientName)" : ""}";
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      sub: json['sub'],
      givenName: json['given_name'],
      familyName: json['family_name'],
      clientName: json['client_name'],
    );
  }
}
