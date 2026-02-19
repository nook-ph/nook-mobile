import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
    
      create: (context) => AppBloc()..add(AppStarted()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Nook',
        home: BlocConsumer<AppBloc, AppState>(
          listener: (context, state) {
            if (state is! AppInitial) {
              FlutterNativeSplash.remove();
            }
          },
          
          builder: (context, state) {
            return switch (state) {
              ShowOnboarding() => const OnboardingPage(),
              ShowHome() => const HomePage(),
              AppInitial() => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            };
          },
        ),
      ),
    );
  }
}
