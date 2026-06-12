import 'package:equatable/equatable.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';

sealed class ShareCardState extends Equatable {
  const ShareCardState();

  @override
  List<Object?> get props => [];
}

class ShareCardInitial extends ShareCardState {
  const ShareCardInitial();
}

class ShareCardLoading extends ShareCardState {
  const ShareCardLoading();
}

class ShareCardReady extends ShareCardState {
  final CrawlShareCardData data;

  const ShareCardReady(this.data);

  @override
  List<Object?> get props => [data];
}

class ShareCardCapturing extends ShareCardState {
  const ShareCardCapturing();
}

class ShareCardShared extends ShareCardState {
  const ShareCardShared();
}

class ShareCardError extends ShareCardState {
  final String message;

  const ShareCardError(this.message);

  @override
  List<Object?> get props => [message];
}
