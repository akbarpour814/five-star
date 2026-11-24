import '../../../../core/utils/id_generator.dart';
import '../../../panel/domain/device_model.dart';
import '../../../panel/domain/panel_commands.dart';
import '../../../panel/domain/panel_response_parser.dart';
import '../entities/device_message.dart';
import '../repositories/device_repository.dart';

/// Parses a device reply (received automatically or pasted) and folds it into local state.
class ProcessDeviceReply {
  ProcessDeviceReply({required this._repository, this._parser = const PanelResponseParser()});

  final DeviceRepository _repository;
  final PanelResponseParser _parser;

  /// [model] and [config] (programmed message texts) decide how the reply is read.
  ParsedResponse preview(
    String text, {
    DeviceModel model = DeviceModel.fallback,
    Map<String, Object?> config = const {},
  }) => _parser.parse(text, model: model, config: config);

  Future<ParsedResponse> call(String deviceId, String text, {DateTime? at}) async {
    final device = await _repository.getDevice(deviceId);
    final config = await _repository.getConfig(deviceId);
    var parsed = _parser.parse(text, model: device?.type ?? DeviceModel.fallback, config: config);
    final time = at ?? DateTime.now();
    final output = parsed.output;
    if (output != null && config[ConfigKeys.outputMode(output)] == 'momentary') parsed = parsed.asMomentary();

    // Replies can be processed out of order (inbox sync, queued while closed, pasted): every field
    // keeps the value of the newest SMS that reported it, so the latest SMS always defines the state.
    if (parsed.patch != null) {
      final status = await _repository.getStatus(deviceId);
      final next = status.applyAt(parsed.patch!, time);
      if (next != status) await _repository.saveStatus(deviceId, next);
    }
    await _repository.mergeConfig(deviceId, parsed.config, at: time);
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
