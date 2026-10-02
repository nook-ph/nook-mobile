import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/update_crawl_title_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/edit_crawl_title_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/injection_container.dart';

/// Renames a crawl. Pops with the updated [Crawl] once the server accepts
/// the title; stops and their order are fixed and not editable here.
class EditCrawlTitleSheet extends StatefulWidget {
  const EditCrawlTitleSheet({super.key, required this.crawl});

  final Crawl crawl;

  static Future<Crawl?> show(BuildContext context, Crawl crawl) {
    return CrawlSheet.show<Crawl>(
      context,
      builder: (_) => BlocProvider(
        create: (_) => EditCrawlTitleCubit(
          updateCrawlTitleUseCase: sl<UpdateCrawlTitleUseCase>(),
        ),
        child: EditCrawlTitleSheet(crawl: crawl),
      ),
    );
  }

  @override
  State<EditCrawlTitleSheet> createState() => _EditCrawlTitleSheetState();
}

class _EditCrawlTitleSheetState extends State<EditCrawlTitleSheet> {
  static const _min = CreateCrawlUseCase.minTitleLength;
  static const _max = CreateCrawlUseCase.maxTitleLength;

  late final TextEditingController _controller = TextEditingController(
    text: widget.crawl.title,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    context.read<EditCrawlTitleCubit>().save(widget.crawl.id, _controller.text);
  }

  static const _lengthError = 'Title must be $_min–$_max characters.';

  /// The red line under the field. A title that has been edited down below
  /// the minimum says so at once, without waiting for Save.
  String? _errorText(EditCrawlTitleState state, String text) {
    if (state.problem == EditTitleProblem.length) return _lengthError;
    if (state.problem == EditTitleProblem.rejected) {
      return 'Please pick a different title.';
    }
    final error = state.error;
    if (error != null) {
      final info = AppErrorCopy.fromException(error);
      return '${info.title}. ${info.subtitle}';
    }
    final edited = text.trim() != widget.crawl.title.trim();
    if (edited && !EditCrawlTitleCubit.isValidLength(text)) return _lengthError;
    return null;
  }

  /// The muted line under the field when nothing is wrong.
  static String _helperText(String text) => EditCrawlTitleCubit.atLimit(text)
      ? 'That is the limit. The field stops taking characters at $_max.'
      : '$_min–$_max characters. Stops and order cannot be changed.';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditCrawlTitleCubit, EditCrawlTitleState>(
      listenWhen: (previous, current) =>
          previous.saved != current.saved && current.saved != null,
      listener: (context, state) => Navigator.of(context).pop(state.saved),
      builder: (context, state) {
        return CrawlSheet(
          title: 'Edit title',
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final canSave = EditCrawlTitleCubit.canSave(
                original: widget.crawl.title,
                current: value.text,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Figma: 4 + a 4 spacer + 4 under the header.
                  const SizedBox(height: 8),
                  CrawlTextField(
                    controller: _controller,
                    label: 'Crawl title',
                    maxLength: _max,
                    // A 60-character title runs to a second line.
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    errorText: _errorText(state, value.text),
                    helperText: _helperText(value.text),
                    onChanged: (_) =>
                        context.read<EditCrawlTitleCubit>().edited(),
                    onSubmitted: (_) {
                      if (canSave) _save();
                    },
                  ),
                  // Figma: 4 + a 12 spacer + 4.
                  const SizedBox(height: 20),
                  CrawlPrimaryButton(
                    label: 'Save',
                    busy: state.saving,
                    onTap: canSave ? _save : null,
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
