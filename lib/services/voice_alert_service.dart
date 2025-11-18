import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'navigation_service.dart';

class VoiceAlertService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isEnabled = true;
  final Set<String> _announcedRisks = {};
  DateTime? _lastAnnouncement;
  static const Duration _minTimeBetweenAnnouncements = Duration(seconds: 10);

  VoiceAlertService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.55); // Optimized for clear navigation instructions
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05); // Slightly higher pitch for better clarity

    // iOS specific settings for high-quality voice
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.duckOthers, // Lower other audio during navigation
      ],
      IosTextToSpeechAudioMode.voicePrompt, // Optimized for navigation prompts
    );
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  bool get isEnabled => _isEnabled;

  Future<void> announceNavigationStart(String destination, String duration) async {
    if (!_isEnabled) return;
    await _speak('Starting navigation to $destination. Estimated arrival time, $duration. Drive safely.');
  }

  Future<void> announceInstruction(String instruction, double distanceMeters) async {
    if (!_isEnabled) return;
    
    String distanceText;
    if (distanceMeters < 50) {
      distanceText = 'Now';
    } else if (distanceMeters < 100) {
      distanceText = 'In ${distanceMeters.toInt()} meters';
    } else if (distanceMeters < 1000) {
      final roundedMeters = (distanceMeters / 50).round() * 50;
      distanceText = 'In ${roundedMeters} meters';
    } else {
      final km = (distanceMeters / 1000).toStringAsFixed(1);
      distanceText = 'In $km kilometers';
    }

    await _speak('$distanceText, $instruction');
  }

  Future<void> announceRiskPoint(RiskPoint risk, double distanceMeters) async {
    if (!_isEnabled) return;
    
    // Prevent duplicate announcements
    final riskKey = '${risk.location.latitude}_${risk.location.longitude}_${risk.type}';
    if (_announcedRisks.contains(riskKey)) return;

    // Rate limit announcements
    if (_lastAnnouncement != null) {
      final timeSinceLastAnnouncement = DateTime.now().difference(_lastAnnouncement!);
      if (timeSinceLastAnnouncement < _minTimeBetweenAnnouncements) return;
    }

    String message;
    if (distanceMeters < 500) {
      message = _getRiskAlertMessage(risk, 'ahead');
    } else if (distanceMeters < 1000) {
      message = _getRiskAlertMessage(risk, 'coming up');
    } else {
      return; // Too far to announce
    }

    await _speak(message);
    _announcedRisks.add(riskKey);
    _lastAnnouncement = DateTime.now();
  }

  String _getRiskAlertMessage(RiskPoint risk, String proximity) {
    String severity;
    switch (risk.level) {
      case NavRiskLevel.critical:
        severity = 'Danger';
        break;
      case NavRiskLevel.high:
        severity = 'Caution';
        break;
      case NavRiskLevel.medium:
        severity = 'Advisory';
        break;
      case NavRiskLevel.low:
        severity = 'Notice';
        break;
    }

    String hazardType;
    switch (risk.type) {
      case 'accident':
        hazardType = 'accident reported';
        break;
      case 'damage':
        hazardType = 'road damage reported';
        break;
      case 'weather':
        hazardType = 'weather hazard reported';
        break;
      case 'traffic':
        hazardType = 'heavy traffic reported';
        break;
      default:
        hazardType = 'hazard reported';
    }

    return '$severity. $hazardType $proximity. Please drive carefully.';
  }

  Future<void> announceOffRoute() async {
    if (!_isEnabled) return;
    await _speak('Off route. Recalculating new route.');
  }

  Future<void> announceRerouting() async {
    if (!_isEnabled) return;
    await _speak('New route calculated. Continue as directed.');
  }

  Future<void> announceArrival() async {
    if (!_isEnabled) return;
    await _speak('You have arrived at your destination. Navigation complete.');
  }

  Future<void> announceApproachingTurn(String direction, double distanceMeters) async {
    if (!_isEnabled) return;
    
    if (distanceMeters < 100) {
      await _speak('Prepare to turn $direction now');
    } else if (distanceMeters < 300) {
      final meters = distanceMeters.toInt();
      await _speak('In $meters meters, turn $direction');
    }
  }

  Future<void> announceSpeedWarning(double currentSpeed, double speedLimit) async {
    if (!_isEnabled) return;
    await _speak('Speeding alert. Please slow down to ${speedLimit.toInt()} kilometers per hour');
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void clearAnnouncedRisks() {
    _announcedRisks.clear();
  }

  void dispose() {
    _flutterTts.stop();
  }
}

