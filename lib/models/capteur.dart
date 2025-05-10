import 'dart:convert';

List<Capteur> capteurFromJson(String str) =>
    List<Capteur>.from(json.decode(str).map((x) => Capteur.fromJson(x)));

String capteurToJson(List<Capteur> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Capteur {
  final String id;
  final double sound;
  final double mq2;
  final double temperature;
  final DateTime?
      timestamp; // Make timestamp nullable based on usage in provider

  Capteur({
    required this.id,
    required this.sound,
    required this.mq2,
    required this.temperature,
    this.timestamp, // Make optional
  });

  factory Capteur.fromJson(Map<String, dynamic> json) => Capteur(
        id: json["_id"],
        // Use num?.toDouble() for flexibility and null safety
        sound: (json["sound"] as num?)?.toDouble() ?? 0.0,
        mq2: (json["mq2"] as num?)?.toDouble() ?? 0.0,
        temperature: (json["temperature"] as num?)?.toDouble() ?? 0.0,
        // Handle null timestamp
        timestamp: json["timestamp"] == null
            ? null
            : DateTime.parse(json["timestamp"]),
      );

  Map<String, dynamic> toJson() => {
        "_id": id,
        "sound": sound,
        "mq2": mq2,
        "temperature": temperature,
        "timestamp": timestamp?.toIso8601String(), // Handle null timestamp
      };
}
