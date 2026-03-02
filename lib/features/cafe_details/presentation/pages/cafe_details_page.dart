import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';

import 'package:nook/features/cafe_details/data/datasources/cafe_details_remote_data_source.dart';
import 'package:nook/features/cafe_details/data/repository/cafe_details_repository_impl.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';

import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_app_bar.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_hours_title.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_tags_list.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class CafeDetailsPage extends StatelessWidget {
  const CafeDetailsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final menuCardWidth = ((screenWidth - 44) / 2) - 6;

    final supabase = Supabase.instance.client;
    final dataSource = CafeDetailsRemoteDataSource(supabase);
    final repository = CafeDetailsRepositoryImpl(dataSource);
    final useCase = GetCafeDetailsUseCase(repository);

    return BlocProvider(
      create: (context) =>
          CafeDetailsBloc(getCafeDetailsUseCase: useCase)
            ..add(LoadCafeDetailsRequested(cafeId: cafeId)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const CafeDetailsAppBar(),
        extendBodyBehindAppBar: true,
        body: BlocBuilder<CafeDetailsBloc, CafeDetailsState>(
          builder: (context, state) {
            final isLoading =
                state is CafeDetailsInitial || state is CafeDetailsLoading;

            if (state is CafeDetailsError) {
              return Center(
                child: Text(
                  'Error loading cafes: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Skeletonizer(
              enabled: isLoading,
              effect: const PulseEffect(),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Hero Image
                    Container(
                      height: 350,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: isLoading
                          ? null
                          : Image.network(
                              state is CafeDetailsLoaded
                                  ? (state.data.cafeDetails.featuredImageUrl ??
                                        '')
                                  : '',
                              fit: BoxFit.cover,
                            ),
                    ),

                    const SizedBox(height: 24),

                    /// Header
                    CafeInfoHeader(
                      cafe: state is CafeDetailsLoaded ? state.data : null,
                    ),

                    const SizedBox(height: 24),

                    /// Tags
                    const CafeTagsList(),

                    const SizedBox(height: 24),

                    /// Description
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        state is CafeDetailsLoaded
                            ? state.data.cafeDetails.description
                            : '',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// Hours
                    CafeHoursTile(
                      cafe: state is CafeDetailsLoaded ? state.data : null,
                    ),

                    const Padding(
                      padding: EdgeInsets.only(left: 66, right: 22),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE0E0E0),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// Menu
                    MenuHighlights(
                      width: menuCardWidth,
                      cafe: state is CafeDetailsLoaded ? state.data : null,
                    ),

                    const SizedBox(height: 24),

                    /// Info
                    CafeInfo(
                      cafe: state is CafeDetailsLoaded ? state.data : null,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
