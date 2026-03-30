import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmailEntryScreen extends StatelessWidget {
  const EmailEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Log In'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text('Email input and OAuth buttons will go here.'),
        ),
      ),
    );
  }
}
