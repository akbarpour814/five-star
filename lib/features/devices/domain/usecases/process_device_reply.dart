import '../../../../core/utils/id_generator.dart';
import '../../../gsa212/domain/gsa212_commands.dart';
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
    var parsed = _parser.parse(text);
    final time = at ?? DateTime.now();
    final output = parsed.output;
    if (output != null) {
      final config = await _repository.getConfig(deviceId);
      if (config[ConfigKeys.outputMode(output)] == 'momentary') parsed = parsed.asMomentary();
    }

    // A reply older than the last applied one (e.g. found later in the inbox) is logged but must not roll state back.
    final status = await _repository.getStatus(deviceId);
    final stale = status.updatedAt != null && time.isBefore(status.updatedAt!);
    if (!stale) {
      if (parsed.patch != null) {
        await _repository.saveStatus(deviceId, parsed.patch!(status).copyWith(updatedAt: time));
      }
      await _repository.mergeConfig(deviceId, parsed.config);
    }
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
