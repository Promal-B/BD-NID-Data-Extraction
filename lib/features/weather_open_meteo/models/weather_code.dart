enum WeatherCode {
  unknown(-1, 'Unknown'),
  clearSky(0, 'Clear sky'),
  mainlyClear(1, 'Mainly clear'),
  partlyCloudy(2, 'Partly cloudy'),
  overcast(3, 'Overcast'),
  fog(45, 'Fog'),
  depositingRimeFog(48, 'Depositing rime fog'),
  lightDrizzle(51, 'Light drizzle'),
  moderateDrizzle(53, 'Moderate drizzle'),
  denseDrizzle(55, 'Dense drizzle'),
  lightFreezingDrizzle(56, 'Light freezing drizzle'),
  denseFreezingDrizzle(57, 'Dense freezing drizzle'),
  slightRain(61, 'Slight rain'),
  moderateRain(63, 'Moderate rain'),
  heavyRain(65, 'Heavy rain'),
  lightFreezingRain(66, 'Light freezing rain'),
  heavyFreezingRain(67, 'Heavy freezing rain'),
  slightSnowfall(71, 'Slight snowfall'),
  moderateSnowfall(73, 'Moderate snowfall'),
  heavySnowfall(75, 'Heavy snowfall'),
  snowGrains(77, 'Snow grains'),
  slightRainShowers(80, 'Slight rain showers'),
  moderateRainShowers(81, 'Moderate rain showers'),
  violentRainShowers(82, 'Violent rain showers'),
  slightSnowShowers(85, 'Slight snow showers'),
  heavySnowShowers(86, 'Heavy snow showers'),
  thunderstorm(95, 'Thunderstorm'),
  thunderstormWithSlightHail(96, 'Thunderstorm with slight hail'),
  heavyThunderstorm(97, 'Heavy thunderstorm'),
  thunderstormWithHeavyHail(99, 'Thunderstorm with heavy hail');

  const WeatherCode(this.code, this.localizationKey);

  final int code;
  final String localizationKey;

  String get image => '${code}_image';

  static WeatherCode fromCode(int code) {
    return WeatherCode.values.firstWhere(
      (weather) => weather.code == code,
      orElse: () => WeatherCode.unknown,
    );
  }
}
