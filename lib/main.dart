import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

// ======================================================
// APP
// ======================================================

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',

      themeMode: isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),

      home: WeatherHomePage(
        isDarkMode: isDarkMode,
        onThemeChanged: toggleTheme,
      ),
    );
  }
}

// ======================================================
// HOME PAGE
// ======================================================

class WeatherHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeChanged;

  const WeatherHomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<WeatherHomePage> createState() =>
      _WeatherHomePageState();
}

class _WeatherHomePageState
    extends State<WeatherHomePage> {

  // ====================================================
  // CURRENT WEATHER VARIABLES
  // ====================================================

  double temperature = 0;
  int humidity = 0;
  double windSpeed = 0;
  int weatherCode = 0;

  String city = "Indore";

  String errorMessage = "";

  bool isLoading = false;
  bool isCelsius = true;

  final TextEditingController cityController =
      TextEditingController();

  // ====================================================
  // FORECAST DATA
  // ====================================================

  List<Map<String, dynamic>> forecast = [];

  List<Map<String, dynamic>> hourlyForecast = [];

  String sunrise = "--:--";
  String sunset = "--:--";

  // ====================================================
  // WEATHER CONDITION
  // ====================================================

  String getWeatherCondition(int code) {
    if (code == 0) {
      return "Clear Sky";
    } else if (code == 1 ||
        code == 2 ||
        code == 3) {
      return "Partly Cloudy";
    } else if (code == 45 ||
        code == 48) {
      return "Foggy";
    } else if (code >= 51 &&
        code <= 57) {
      return "Drizzle";
    } else if (code >= 61 &&
        code <= 67) {
      return "Rain";
    } else if (code >= 71 &&
        code <= 77) {
      return "Snow";
    } else if (code >= 80 &&
        code <= 82) {
      return "Rain Showers";
    } else if (code >= 95 &&
        code <= 99) {
      return "Thunderstorm";
    }

    return "Unknown";
  }

  // ====================================================
  // WEATHER ICON
  // ====================================================

  IconData getWeatherIcon(int code) {
    if (code == 0) {
      return Icons.wb_sunny;
    } else if (code == 1 ||
        code == 2) {
      return Icons.cloud_queue;
    } else if (code == 3) {
      return Icons.cloud;
    } else if (code == 45 ||
        code == 48) {
      return Icons.foggy;
    } else if (code >= 51 &&
        code <= 57) {
      return Icons.grain;
    } else if (code >= 61 &&
        code <= 67) {
      return Icons.water_drop;
    } else if (code >= 71 &&
        code <= 77) {
      return Icons.ac_unit;
    } else if (code >= 80 &&
        code <= 82) {
      return Icons.grain;
    } else if (code >= 95) {
      return Icons.thunderstorm;
    }

    return Icons.cloud;
  }

  // ====================================================
  // TEMPERATURE CONVERSION
  // ====================================================

  double convertTemperature(double celsius) {
    if (isCelsius) {
      return celsius;
    }

    return (celsius * 9 / 5) + 32;
  }

  String temperatureText(double celsius) {
    return "${convertTemperature(celsius).round()}°";
  }

  String temperatureUnit() {
    return isCelsius ? "C" : "F";
  }

  // ====================================================
  // TIME FORMAT
  // ====================================================

  String formatTime(String time) {
    try {
      final DateTime dateTime =
          DateTime.parse(time);

      int hour = dateTime.hour;
      final int minute = dateTime.minute;

      final String period =
          hour >= 12 ? "PM" : "AM";

      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }

      return "$hour:${minute.toString().padLeft(2, '0')} $period";
    } catch (e) {
      return "--:--";
    }
  }

  // ====================================================
  // DATE FORMAT
  // ====================================================

  String formatDate(String date) {
    final DateTime parsedDate =
        DateTime.parse(date);

    const List<String> days = [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun",
    ];

    return days[parsedDate.weekday - 1];
  }

  // ====================================================
  // GET WEATHER
  // ====================================================

  Future<void> getWeather() async {
    if (cityController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final String searchedCity =
          cityController.text.trim();

      // ------------------------------------------------
      // CITY SEARCH
      // ------------------------------------------------

      final Uri geoUrl = Uri.parse(
        "https://geocoding-api.open-meteo.com/v1/search"
        "?name=${Uri.encodeComponent(searchedCity)}"
        "&count=1"
        "&language=en"
        "&format=json",
      );

      final http.Response geoResponse =
          await http.get(geoUrl);

      if (geoResponse.statusCode != 200) {
        throw Exception("City search failed");
      }

      final Map<String, dynamic> geoData =
          jsonDecode(geoResponse.body);

      if (geoData["results"] == null ||
          geoData["results"].isEmpty) {
        throw Exception("City not found");
      }

      final result =
          geoData["results"][0];

      final double latitude =
          (result["latitude"] as num).toDouble();

      final double longitude =
          (result["longitude"] as num).toDouble();

      final String foundCity =
          result["name"] ?? searchedCity;

      // ------------------------------------------------
      // WEATHER API
      // ------------------------------------------------

      final Uri weatherUrl = Uri.parse(
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=$latitude"
        "&longitude=$longitude"
        "&current="
        "temperature_2m,"
        "relative_humidity_2m,"
        "wind_speed_10m,"
        "weather_code"
        "&hourly="
        "temperature_2m,"
        "weather_code,"
        "precipitation_probability"
        "&daily="
        "weather_code,"
        "temperature_2m_max,"
        "temperature_2m_min,"
        "sunrise,"
        "sunset"
        "&timezone=auto",
      );

      final http.Response weatherResponse =
          await http.get(weatherUrl);

      if (weatherResponse.statusCode != 200) {
        throw Exception("Weather data failed");
      }

      final Map<String, dynamic> weatherData =
          jsonDecode(weatherResponse.body);

      // =================================================
      // CURRENT WEATHER
      // =================================================

      final current =
          weatherData["current"];

      final double currentTemperature =
          (current["temperature_2m"] as num)
              .toDouble();

      final int currentHumidity =
          (current["relative_humidity_2m"] as num)
              .toInt();

      final double currentWind =
          (current["wind_speed_10m"] as num)
              .toDouble();

      final int currentWeatherCode =
          (current["weather_code"] as num)
              .toInt();

      // =================================================
      // DAILY FORECAST
      // =================================================

      final daily =
          weatherData["daily"];

      final List dates =
          daily["time"];

      final List weatherCodes =
          daily["weather_code"];

      final List maxTemps =
          daily["temperature_2m_max"];

      final List minTemps =
          daily["temperature_2m_min"];

      final List sunriseTimes =
          daily["sunrise"];

      final List sunsetTimes =
          daily["sunset"];

      List<Map<String, dynamic>>
          newForecast = [];

      for (int i = 0;
          i < dates.length;
          i++) {
        newForecast.add({
          "date": dates[i],
          "weatherCode": weatherCodes[i],
          "maxTemp":
              (maxTemps[i] as num).toDouble(),
          "minTemp":
              (minTemps[i] as num).toDouble(),
        });
      }

      // =================================================
      // HOURLY FORECAST
      // =================================================

      final hourly =
          weatherData["hourly"];

      final List hourlyTimes =
          hourly["time"];

      final List hourlyTemps =
          hourly["temperature_2m"];

      final List hourlyCodes =
          hourly["weather_code"];

      final List rainProbability =
          hourly["precipitation_probability"];

      List<Map<String, dynamic>>
          newHourlyForecast = [];

      // First 24 hours
      for (int i = 0;
          i < 24 &&
              i < hourlyTimes.length;
          i++) {
        newHourlyForecast.add({
          "time": hourlyTimes[i],
          "temperature":
              (hourlyTemps[i] as num)
                  .toDouble(),
          "weatherCode":
              (hourlyCodes[i] as num).toInt(),
          "rain":
              (rainProbability[i] as num).toInt(),
        });
      }

      // =================================================
      // UPDATE UI
      // =================================================

      setState(() {
        city = foundCity;

        temperature =
            currentTemperature;

        humidity =
            currentHumidity;

        windSpeed =
            currentWind;

        weatherCode =
            currentWeatherCode;

        forecast =
            newForecast;

        hourlyForecast =
            newHourlyForecast;

        sunrise =
            formatTime(
              sunriseTimes[0],
            );

        sunset =
            formatTime(
              sunsetTimes[0],
            );

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;

        errorMessage =
            "Unable to find weather. "
            "Please check the city name.";
      });
    }
  }

  // ====================================================
  // INIT STATE
  // ====================================================

  @override
  void initState() {
    super.initState();

    cityController.text =
        "Indore";

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      getWeather();
    });
  }

  // ====================================================
  // DISPOSE
  // ====================================================

  @override
  void dispose() {
    cityController.dispose();

    super.dispose();
  }

  // ====================================================
  // BUILD
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final bool dark =
        widget.isDarkMode;

    return Scaffold(
      backgroundColor: dark
          ? const Color(0xFF101827)
          : const Color(0xFFEAF4FF),

      // ==================================================
      // APP BAR
      // ==================================================

      appBar: AppBar(
        backgroundColor:
            Colors.transparent,

        elevation: 0,

        title: const Text(
          "Weather App",
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        actions: [

          // DARK MODE
          IconButton(
            tooltip: "Dark Mode",
            onPressed:
                widget.onThemeChanged,

            icon: Icon(
              dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),

          // TEMPERATURE UNIT
          Padding(
            padding:
                const EdgeInsets.only(
              right: 12,
            ),

            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isCelsius =
                        !isCelsius;
                  });
                },

                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),

                  decoration:
                      BoxDecoration(
                    color: dark
                        ? Colors.white
                            .withOpacity(
                            0.12,
                          )
                        : Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),

                  child: Text(
                    "°${temperatureUnit()}",

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ==================================================
      // BODY
      // ==================================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
              getWeather,

          child:
              SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),

            padding:
                const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                // ========================================
                // SEARCH
                // ========================================

                Container(
                  decoration:
                      BoxDecoration(
                    color: dark
                        ? const Color(
                            0xFF1C2738,
                          )
                        : Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset:
                            const Offset(
                          0,
                          5,
                        ),
                        color: Colors.black
                            .withOpacity(
                          dark
                              ? 0.15
                              : 0.08,
                        ),
                      ),
                    ],
                  ),

                  child: TextField(
                    controller:
                        cityController,

                    textInputAction:
                        TextInputAction.search,

                    onSubmitted: (_) {
                      getWeather();
                    },

                    decoration:
                        InputDecoration(
                      hintText:
                          "Search city...",

                      prefixIcon:
                          const Icon(
                        Icons.location_on_outlined,
                      ),

                      suffixIcon:
                          IconButton(
                        onPressed:
                            getWeather,

                        icon:
                            const Icon(
                          Icons.search,
                        ),
                      ),

                      border:
                          InputBorder.none,

                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),

                // ========================================
                // ERROR
                // ========================================

                if (errorMessage
                    .isNotEmpty)
                  Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets.all(
                      16,
                    ),

                    margin:
                        const EdgeInsets.only(
                      bottom: 20,
                    ),

                    decoration:
                        BoxDecoration(
                      color: Colors.red
                          .withOpacity(
                        0.1,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),

                    child: Row(
                      children: [

                        const Icon(
                          Icons.error_outline,
                          color:
                              Colors.red,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Text(
                            errorMessage,

                            style:
                                const TextStyle(
                              color:
                                  Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ========================================
                // LOADING
                // ========================================

                if (isLoading)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top: 50,
                      bottom: 50,
                    ),

                    child:
                        Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else ...[

                  // ======================================
                  // CITY
                  // ======================================

                  Text(
                    city,

                    style:
                        const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    "Current Weather",

                    style: TextStyle(
                      fontSize: 15,
                      color: dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ======================================
                  // CURRENT WEATHER
                  // ======================================

                  Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets.all(
                      25,
                    ),

                    decoration:
                        BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.topLeft,

                        end:
                            Alignment.bottomRight,

                        colors: dark
                            ? [
                                const Color(
                                  0xFF263B5A,
                                ),
                                const Color(
                                  0xFF162238,
                                ),
                              ]
                            : [
                                Colors.blue
                                    .shade500,
                                Colors.blue
                                    .shade800,
                              ],
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        28,
                      ),

                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset:
                              const Offset(
                            0,
                            8,
                          ),
                          color: Colors.black
                              .withOpacity(
                            0.15,
                          ),
                        ),
                      ],
                    ),

                    child: Column(
                      children: [

                        Icon(
                          getWeatherIcon(
                            weatherCode,
                          ),

                          size: 85,

                          color:
                              Colors.white,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          temperatureText(
                            temperature,
                          ),

                          style:
                              const TextStyle(
                            fontSize: 62,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.white,
                          ),
                        ),

                        Text(
                          "°${temperatureUnit()}",

                          style:
                              const TextStyle(
                            fontSize: 20,
                            color:
                                Colors.white70,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          getWeatherCondition(
                            weatherCode,
                          ),

                          style:
                              const TextStyle(
                            fontSize: 20,
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ======================================
                  // HUMIDITY + WIND
                  // ======================================

                  Row(
                    children: [

                      Expanded(
                        child:
                            _InfoCard(
                          icon:
                              Icons.water_drop,
                          title:
                              "Humidity",
                          value:
                              "$humidity%",
                          dark:
                              dark,
                        ),
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      Expanded(
                        child:
                            _InfoCard(
                          icon:
                              Icons.air,
                          title:
                              "Wind",
                          value:
                              "${windSpeed.round()} km/h",
                          dark:
                              dark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ======================================
                  // HOURLY FORECAST
                  // ======================================

                  const Text(
                    "Hourly Forecast",

                    style:
                        TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  SizedBox(
                    height: 185,

                    child:
                        ListView.builder(
                      scrollDirection:
                          Axis.horizontal,

                      itemCount:
                          hourlyForecast.length,

                      itemBuilder:
                          (context, index) {

                        final item =
                            hourlyForecast[
                                index];

                        final double temp =
                            item["temperature"];

                        final int code =
                            item["weatherCode"];

                        final int rain =
                            item["rain"];

                        return Container(
                          width: 115,

                          margin:
                              const EdgeInsets.only(
                            right: 12,
                          ),

                          padding:
                              const EdgeInsets.all(
                            14,
                          ),

                          decoration:
                              BoxDecoration(
                            color: dark
                                ? const Color(
                                    0xFF1C2738,
                                  )
                                : Colors.white,

                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,

                            children: [

                              Text(
                                index == 0
                                    ? "Now"
                                    : formatTime(
                                        item["time"],
                                      ),

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              Icon(
                                getWeatherIcon(
                                  code,
                                ),

                                size: 38,

                                color:
                                    Colors.blue,
                              ),

                              Text(
                                temperatureText(
                                  temp,
                                ),

                                style:
                                    const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,

                                children: [

                                  const Icon(
                                    Icons.water_drop,
                                    size: 14,
                                    color:
                                        Colors.blue,
                                  ),

                                  const SizedBox(
                                    width: 3,
                                  ),

                                  Text(
                                    "$rain%",
                                    style:
                                        TextStyle(
                                      fontSize: 12,
                                      color: dark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ======================================
                  // SUNRISE / SUNSET
                  // ======================================

                  const Text(
                    "Sunrise & Sunset",

                    style:
                        TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Row(
                    children: [

                      Expanded(
                        child:
                            _SunCard(
                          icon:
                              Icons.wb_sunny_outlined,
                          title:
                              "Sunrise",
                          value:
                              sunrise,
                          dark:
                              dark,
                        ),
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      Expanded(
                        child:
                            _SunCard(
                          icon:
                              Icons.nights_stay_outlined,
                          title:
                              "Sunset",
                          value:
                              sunset,
                          dark:
                              dark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ======================================
                  // 5 DAY FORECAST
                  // ======================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [

                      const Text(
                        "5-Day Forecast",

                        style:
                            TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        tooltip:
                            "Refresh",

                        onPressed:
                            getWeather,

                        icon:
                            const Icon(
                          Icons.refresh,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  SizedBox(
                    height: 170,

                    child:
                        ListView.builder(
                      scrollDirection:
                          Axis.horizontal,

                      itemCount:
                          forecast.length,

                      itemBuilder:
                          (context, index) {

                        final item =
                            forecast[index];

                        final int code =
                            item["weatherCode"];

                        final double maxTemp =
                            item["maxTemp"];

                        final double minTemp =
                            item["minTemp"];

                        return Container(
                          width: 125,

                          margin:
                              const EdgeInsets.only(
                            right: 12,
                          ),

                          padding:
                              const EdgeInsets.all(
                            15,
                          ),

                          decoration:
                              BoxDecoration(
                            color: dark
                                ? const Color(
                                    0xFF1C2738,
                                  )
                                : Colors.white,

                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,

                            children: [

                              Text(
                                index == 0
                                    ? "Today"
                                    : formatDate(
                                        item["date"],
                                      ),

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              Icon(
                                getWeatherIcon(
                                  code,
                                ),

                                size: 38,

                                color:
                                    Colors.blue,
                              ),

                              Text(
                                getWeatherCondition(
                                  code,
                                ),

                                textAlign:
                                    TextAlign.center,

                                maxLines: 1,

                                overflow:
                                    TextOverflow
                                        .ellipsis,

                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  color: dark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,

                                children: [

                                  Text(
                                    temperatureText(
                                      maxTemp,
                                    ),

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 6,
                                  ),

                                  Text(
                                    temperatureText(
                                      minTemp,
                                    ),

                                    style:
                                        TextStyle(
                                      color: dark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // ======================================
                  // REFRESH BUTTON
                  // ======================================

                  SizedBox(
                    width:
                        double.infinity,

                    height: 55,

                    child:
                        ElevatedButton.icon(
                      onPressed:
                          getWeather,

                      icon:
                          const Icon(
                        Icons.refresh,
                      ),

                      label:
                          const Text(
                        "Refresh Weather",

                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      style:
                          ElevatedButton.styleFrom(
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ======================================
                  // API CREDIT
                  // ======================================

                  Center(
                    child: Text(
                      "Weather data powered by Open-Meteo",

                      style:
                          TextStyle(
                        fontSize: 12,
                        color: dark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// INFO CARD
// ======================================================

class _InfoCard
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;
  final bool dark;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.dark,
  });

  @override
  Widget build(
      BuildContext context) {

    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: dark
            ? const Color(0xFF1C2738)
            : Colors.white,

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset:
                const Offset(0, 4),
            color:
                Colors.black.withOpacity(
              0.06,
            ),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            padding:
                const EdgeInsets.all(10),

            decoration:
                BoxDecoration(
              color: Colors.blue
                  .withOpacity(0.1),

              shape:
                  BoxShape.circle,
            ),

            child: Icon(
              icon,
              color:
                  Colors.blue,
              size: 22,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style:
                      TextStyle(
                    fontSize: 12,
                    color: dark
                        ? Colors.white60
                        : Colors.black54,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,

                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// SUN CARD
// ======================================================

class _SunCard
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;
  final bool dark;

  const _SunCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.dark,
  });

  @override
  Widget build(
      BuildContext context) {

    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: dark
            ? const Color(0xFF1C2738)
            : Colors.white,

        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Row(
        children: [

          Icon(
            icon,
            size: 32,
            color: Colors.orange,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style:
                      TextStyle(
                    fontSize: 12,
                    color: dark
                        ? Colors.white60
                        : Colors.black54,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  value,

                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}