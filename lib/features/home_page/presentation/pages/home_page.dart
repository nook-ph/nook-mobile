import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/data/datasources/home_remote_data_source.dart';
import 'package:nook/features/home_page/data/repositories/home_repository_impl.dart';
import 'package:nook/features/home_page/domain/use_cases/get_home_cafes_usecase.dart';
import 'package:nook/features/home_page/presentation/widgets/featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';
import 'package:nook/features/home_page/presentation/widgets/recommended_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth - 44;

    final supabase = Supabase.instance.client;
    final dataSource = HomeRemoteDataSource(supabase);
    final repository = HomeRepositoryImpl(dataSource);
    final useCase = GetHomeCafesUseCase(repository);

    return BlocProvider(
      create: (context) =>
          HomeBloc(getHomeCafesUseCase: useCase)..add(LoadHomeDataEvent()),

      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeInitialState || state is HomeLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.grey),
                );
              }

              if (state is HomeError) {
                return Center(
                  child: Text(
                    'Error loading cafes: ${state.message}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (state is HomeLoadedState) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HomeTopBar(),

                      const SizedBox(height: 24),

                      Padding(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 22),
                        child: Text(
                          "Featured",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 312,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          itemCount: state.featuredCafes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return FeaturedCard(
                              width: cardWidth,
                              cafe: state.featuredCafes[index],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      Padding(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 22),
                        child: Text(
                          "Recommended",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          children: state.recommendedCafes.map((cafe) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: RecommendedCard(cafe: cafe),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }

              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}
