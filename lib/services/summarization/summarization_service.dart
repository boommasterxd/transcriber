import 'summary_result.dart';

/// Turns a transcript into a structured [SummaryResult]. Implemented on-device
/// (Gemma) and via cloud providers.
abstract interface class SummarizationService {
  Future<SummaryResult> summarize(String transcript, {required bool german});
}
