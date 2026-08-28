import '../remote/remote_api_client.dart';
import 'summarization_service.dart';
import 'summary_prompt.dart';
import 'summary_result.dart';

/// [SummarizationService] backed by a cloud provider chat endpoint.
class RemoteSummarizationService implements SummarizationService {
  RemoteSummarizationService({
    required this.client,
    required this.apiModelId,
    required this.fallbackTitle,
  });

  final SummaryProviderClient client;
  final String apiModelId;
  final String fallbackTitle;

  @override
  Future<SummaryResult> summarize(
    String transcript, {
    required bool german,
  }) async {
    final raw = await client.summarize(
      systemPrompt: SummaryPrompt.system(german),
      userPrompt: SummaryPrompt.user(transcript, german: german),
      modelId: apiModelId,
    );
    return SummaryPrompt.parse(raw, fallbackTitle: fallbackTitle);
  }
}
