import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});


  final List<Widget> _pages = const [
    HomePage()
  ];

  

}