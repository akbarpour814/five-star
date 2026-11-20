import '../../../../core/utils/id_generator.dart';
import '../../../gsa212/domain/gsa212_response_parser.dart';
import '../entities/device_message.dart';
import '../repositories/device_repository.dart';

/// Parses a device reply (received automatically or pasted) and folds it into local state.
class ProcessDeviceReply {
  ProcessDeviceReply({required this._repository, this._parser = const Gsa212ResponseParser()});

  final DeviceRepository _repository;
  final Gsa212ResponseParser _parser;

  ParsedResponse preview(String text) => _parser.parse(text);

  Future<ParsedResponse> call(String deviceId, String text, {DateTime? at}) async {
    final parsed = _parser.parse(text);
    final time = at ?? DateTime.now();

    if (parsed.patch != null) {
      final status = await _repository.getStatus(deviceId);
      await _repository.saveStatus(deviceId, parsed.patch!(status).copyWith(updatedAt: time));
    }
    await _repository.mergeConfig(deviceId, parsed.config);
    await _repository.addMessage(
      deviceId,
      DeviceMessage(
        id: IdGenerator.next(),
        direction: MessageDirection.incoming,
        title: parsed.title,
        body: text.trim(),
        detail: parsed.detail,
        severity: parsed.severity,
        at: time,
      ),
    );
    return parsed;
  }
}
