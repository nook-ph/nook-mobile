import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

void main() async{
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

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
              ShowHome() => const MainScreen(),
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
