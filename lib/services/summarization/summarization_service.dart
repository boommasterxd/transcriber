import 'summary_result.dart';

/// Turns a transcript into a structured result through a cloud provider.
abstract interface class SummarizationService {
  Future<SummaryResult> summarize(String transcript, {required bool german});
}
