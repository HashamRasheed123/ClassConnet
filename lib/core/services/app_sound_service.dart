import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays bundled ultra-low-latency button tap SFX and notification SFX
/// via the native Android [SoundPool] / [MediaPlayer] bridge.
class AppSoundService {
  AppSoundService._();
  static final AppSoundService instance = AppSoundService._();

  static const MethodChannel _channel = MethodChannel('classconnect/alarm_power');
  static const String _prefTapEnabledKey = 'kzynovex_tap_sound_enabled_v1';

  bool tapSoundEnabled = true;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      tapSoundEnabled = prefs.getBool(_prefTapEnabledKey) ?? true;
    } catch (_) {}
  }

  Future<void> setTapSoundEnabled(bool enabled) async {
    tapSoundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTapEnabledKey, enabled);
    } catch (_) {}
  }

  /// Plays the soft tap sound effect (mixkit-message-pop-alert) when enabled.
  /// Safe no-op in widget tests or non-Android environments.
  Future<void> playTapSound({bool ignoreSetting = false}) async {
    if (!ignoreSetting && !tapSoundEnabled) return;
    final now = DateTime.now();
    if (now.difference(_lastTapAt).inMilliseconds < 70) return;
    _lastTapAt = now;
    try {
      await _channel.invokeMethod('playTapSound');
    } catch (_) {}
  }

  /// Plays a single preview of a bundled or system notification sound preset.
  Future<void> previewNotificationSound(String presetId) async {
    try {
      await _channel.invokeMethod('playNotificationSound', {
        'soundPreset': presetId,
      });
    } catch (_) {}
  }
}

/// Transparent root pointer listener that plays the soft button tap sound
/// whenever a user taps any interactive button, chip, tab, switch, or card.
class GlobalButtonSoundLayer extends StatefulWidget {
  final Widget child;

  const GlobalButtonSoundLayer({super.key, required this.child});

  @override
  State<GlobalButtonSoundLayer> createState() => _GlobalButtonSoundLayerState();
}

class _GlobalButtonSoundLayerState extends State<GlobalButtonSoundLayer> {
  int? _activePointer;
  Offset? _downPosition;
  DateTime? _downTime;

  void _onPointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _downPosition = event.position;
    _downTime = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    final startPos = _downPosition;
    final startTime = _downTime;
    _activePointer = null;
    _downPosition = null;
    _downTime = null;

    if (startPos == null || startTime == null) return;
    if ((event.position - startPos).distance > 18.0) return;
    if (DateTime.now().difference(startTime).inMilliseconds > 450) return;
    if (!AppSoundService.instance.tapSoundEnabled) return;

    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);

    bool hasEditable = false;
    bool hasInteractiveControl = false;

    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderEditable) {
        hasEditable = true;
        break;
      }
      if (target is RenderSemanticsGestureHandler && target.onTap != null) {
        hasInteractiveControl = true;
      } else if (target is RenderSemanticsAnnotations &&
          (target.properties.button == true || target.properties.onTap != null)) {
        hasInteractiveControl = true;
      }
    }

    if (!hasEditable && hasInteractiveControl) {
      AppSoundService.instance.playTapSound();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer == event.pointer) {
      _activePointer = null;
      _downPosition = null;
      _downTime = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
