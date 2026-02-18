import 'package:flutter/material.dart';


class Onboarding extends StatelessWidget {
    const Onboarding({super.key});

    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            title: 'Nook',
            home: Scaffold(
                body: Center(
                    child: Text('Hello world',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold
                        )
                    )
                )
            )
        );
    }
}
