import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/core/audio/audio_input.dart';
import 'src/core/audio/phone_audio_input.dart';
import 'src/core/background_playback.dart';
import 'src/core/sound/sound_player.dart';
import 'src/features/tv/plugin_camera_input.dart';
import 'src/core/nfc/nfc_writer.dart';
import 'src/core/notification_lights_platform.dart';
import 'src/core/photos/photo_picker.dart';
import 'src/core/speech/speaker.dart';
import 'src/core/speech/voice_recordings.dart';
import 'src/core/weather/weather.dart';
import 'src/core/hue/hue_discovery.dart';
import 'src/features/bridge/bridge_controller.dart';
import 'src/features/bridge/credential_store.dart';
import 'src/features/library/preferences_controller.dart';
import 'src/features/shortcuts/app_shortcuts.dart';
import 'src/features/shortcuts/home_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One quick platform call: Android 10+ can also feed Music Sync with
  // what the phone itself plays.
  final phoneAudio = await PhoneAudioInput.ifSupported();
  final discovery = CompositeBridgeDiscovery([
    const MdnsBridgeDiscovery(),
    CloudBridgeDiscovery(),
  ]);
  final bridge = BridgeController(
    store: SecureCredentialStore(),
    discovery: discovery,
  )..initialize();
  final preferences = PreferencesController(store: SharedPreferencesStore())
    ..load();
  runApp(
    LumiFxApp(
      bridge: bridge,
      discovery: discovery,
      preferences: preferences,
      audioInput: MicrophoneAudioInput(),
      phoneAudioInput: phoneAudio,
      shortcuts: const QuickActionsShortcuts(),
      widgets: const ChannelHomeWidgets(),
      background: ChannelBackgroundPlayback(),
      sound: AudioplayersSoundPlayer(),
      camera: PluginCameraInput(),
      speaker: TtsSpeaker(),
      photos: PluginPhotoPicker(),
      weather: OpenMeteoWeather(),
      voices: FileVoiceRecordings(),
      voiceRecorder: PluginVoiceRecorder(),
      voicePlayer: AudioplayersVoicePlayer(),
      nfc: ChannelNfcWriter(),
      notificationLights: ChannelNotificationLights(),
    ),
  );
}
