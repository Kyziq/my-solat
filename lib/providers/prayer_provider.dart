import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Prayer {
  final String name;
  final DateTime time;
  // TODO: Add solat tracking feature
  // bool isDone;

  Prayer({required this.name, required this.time});
}

class PrayerProvider extends ChangeNotifier {
  List<Prayer> _prayers = [];
  bool _isLoading = false;
  String? _error;

  List<Prayer> get prayers => _prayers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPrayers({double? lat, double? long}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with actual coordinates from GPS, access location permission
      // HARDCODED Coordinates for Kolej Matrik Arau, Perlis
      final latitude = lat ?? 6.441610299323962;
      final longitude = long ?? 100.27640065090574;

      // Get zone information
      final zoneData = await _fetchZoneData(latitude, longitude);
      if (zoneData == null) throw Exception('Unable to determine zone');

      // Get prayer times
      final prayerData = await _fetchPrayerTimes(zoneData['zone']);
      if (prayerData == null) throw Exception('Failed to fetch prayer times');

      _prayers = _createPrayersList(prayerData);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _fetchZoneData(double lat, double long) async {
    final response = await http.get(
        Uri.parse('https://api.waktusolat.app/zones/gps?lat=$lat&long=$long'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchPrayerTimes(String zone) async {
    // Format today's date (yyyy-mm-dd)
    // https://gist.github.com/lomotech/b25cde7118adf5e7a1fea4ce6cfce259
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final response = await http.post(
      Uri.parse(
          'https://www.e-solat.gov.my/index.php?r=esolatApi/takwimsolat&period=duration&zone=$zone'),
      body: {
        'datestart': dateStr,
        'dateend': dateStr,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['prayerTime'][0];
    }
    return null;
  }

  List<Prayer> _createPrayersList(Map<String, dynamic> prayerData) {
    final prayerNames = {
      'fajr': 'Subuh',
      'dhuhr': 'Zohor',
      'asr': 'Asar',
      'maghrib': 'Maghrib',
      'isha': 'Isyak',
    };

    return prayerNames.entries.map((entry) {
      return Prayer(
        name: entry.value,
        time: _parseTime(prayerData[entry.key]),
      );
    }).toList();
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  String formatPrayerTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
