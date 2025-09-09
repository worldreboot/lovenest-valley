enum MoodType {
  happy,
  sad,
  excited,
  calm,
  stressed,
  romantic,
}

enum WeatherType {
  sunny,
  rainy,
  cloudy,
  stormy,
  foggy,
  clearNight,
}

class MoodWeatherMapping {
  static const Map<String, WeatherType> _moodCombinationToWeather = {
    // Both happy
    'happy_happy': WeatherType.sunny,
    'happy_excited': WeatherType.sunny,
    'happy_romantic': WeatherType.clearNight,
    
    // Both sad
    'sad_sad': WeatherType.rainy,
    'sad_stressed': WeatherType.stormy,
    
    // Mixed moods
    'happy_sad': WeatherType.cloudy,
    'excited_calm': WeatherType.sunny,
    'romantic_calm': WeatherType.clearNight,
    'stressed_calm': WeatherType.foggy,
    
    // Default mappings
    'happy_calm': WeatherType.sunny,
    'excited_romantic': WeatherType.clearNight,
    'sad_calm': WeatherType.cloudy,
    'stressed_romantic': WeatherType.foggy,
    'excited_stressed': WeatherType.cloudy,
    'romantic_sad': WeatherType.cloudy,
  };

  static WeatherType getWeatherForMoodCombination(MoodType mood1, MoodType mood2) {
    // Create sorted combination key to ensure consistent mapping
    final moods = [mood1.name, mood2.name]..sort();
    final combinationKey = '${moods[0]}_${moods[1]}';
    
    return _moodCombinationToWeather[combinationKey] ?? WeatherType.sunny;
  }

  static String getMoodDisplayName(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Happy 😊';
      case MoodType.sad:
        return 'Sad 😢';
      case MoodType.excited:
        return 'Excited 🎉';
      case MoodType.calm:
        return 'Calm 😌';
      case MoodType.stressed:
        return 'Stressed 😰';
      case MoodType.romantic:
        return 'Romantic 💕';
    }
  }

  static String getWeatherDisplayName(WeatherType weather) {
    switch (weather) {
      case WeatherType.sunny:
        return 'Sunny ☀️';
      case WeatherType.rainy:
        return 'Rainy 🌧️';
      case WeatherType.cloudy:
        return 'Cloudy ☁️';
      case WeatherType.stormy:
        return 'Stormy ⛈️';
      case WeatherType.foggy:
        return 'Foggy 🌫️';
      case WeatherType.clearNight:
        return 'Clear Night 🌙';
    }
  }

  static String getWeatherDescription(WeatherType weather) {
    switch (weather) {
      case WeatherType.sunny:
        return 'A bright, sunny day perfect for farming!';
      case WeatherType.rainy:
        return 'Gentle rain nourishes the crops.';
      case WeatherType.cloudy:
        return 'Overcast skies provide a peaceful atmosphere.';
      case WeatherType.stormy:
        return 'Dark clouds and thunder create an intense mood.';
      case WeatherType.foggy:
        return 'Mysterious fog blankets the farm.';
      case WeatherType.clearNight:
        return 'A beautiful starry night for romantic farming.';
    }
  }
}

class DailyMoodResponse {
  final String id;
  final String userId;
  final String coupleId;
  final MoodType moodType;
  final DateTime responseDate;
  final DateTime createdAt;

  const DailyMoodResponse({
    required this.id,
    required this.userId,
    required this.coupleId,
    required this.moodType,
    required this.responseDate,
    required this.createdAt,
  });

  factory DailyMoodResponse.fromJson(Map<String, dynamic> json) {
    return DailyMoodResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      coupleId: json['couple_id'] as String,
      moodType: MoodType.values.firstWhere(
        (e) => e.name == json['mood_type'],
        orElse: () => MoodType.happy,
      ),
      responseDate: DateTime.parse(json['response_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'couple_id': coupleId,
    'mood_type': moodType.name,
    'response_date': responseDate.toIso8601String().split('T')[0],
    'created_at': createdAt.toIso8601String(),
  };
}

class WeatherCondition {
  final String id;
  final String coupleId;
  final WeatherType weatherType;
  final String moodCombination;
  final DateTime weatherDate;
  final DateTime createdAt;

  const WeatherCondition({
    required this.id,
    required this.coupleId,
    required this.weatherType,
    required this.moodCombination,
    required this.weatherDate,
    required this.createdAt,
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    return WeatherCondition(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      weatherType: WeatherType.values.firstWhere(
        (e) => e.name == json['weather_type'],
        orElse: () => WeatherType.sunny,
      ),
      moodCombination: json['mood_combination'] as String,
      weatherDate: DateTime.parse(json['weather_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'couple_id': coupleId,
    'weather_type': weatherType.name,
    'mood_combination': moodCombination,
    'weather_date': weatherDate.toIso8601String().split('T')[0],
    'created_at': createdAt.toIso8601String(),
  };
} 
