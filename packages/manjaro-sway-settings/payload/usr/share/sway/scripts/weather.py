#!/usr/bin/env python
"""Script for the Waybar weather module."""

# credits: @bjesus https://gist.github.com/bjesus/f8db49e1434433f78e5200dc403d58a3

import getopt
import json
import locale
import sys
import urllib.parse
from datetime import datetime

import requests

WEATHER_SYMBOL = {
    "Unknown": "✨",
    "Cloudy": "☁️",
    "Fog": "🌫",
    "HeavyRain": "🌧",
    "HeavyShowers": "🌧",
    "HeavySnow": "❄️",
    "HeavySnowShowers": "❄️",
    "LightRain": "🌦",
    "LightShowers": "🌦",
    "LightSleet": "🌧",
    "LightSleetShowers": "🌧",
    "LightSnow": "🌨",
    "LightSnowShowers": "🌨",
    "PartlyCloudy": "⛅️",
    "Sunny": "☀️",
    "ThunderyHeavyRain": "🌩",
    "ThunderyShowers": "⛈",
    "ThunderySnowShowers": "⛈",
    "VeryCloudy": "☁️",
}

WWO_CODE = {
    "113": "Sunny",
    "116": "PartlyCloudy",
    "119": "Cloudy",
    "122": "VeryCloudy",
    "143": "Fog",
    "176": "LightShowers",
    "179": "LightSleetShowers",
    "182": "LightSleet",
    "185": "LightSleet",
    "200": "ThunderyShowers",
    "227": "LightSnow",
    "230": "HeavySnow",
    "248": "Fog",
    "260": "Fog",
    "263": "LightShowers",
    "266": "LightRain",
    "281": "LightSleet",
    "284": "LightSleet",
    "293": "LightRain",
    "296": "LightRain",
    "299": "HeavyShowers",
    "302": "HeavyRain",
    "305": "HeavyShowers",
    "308": "HeavyRain",
    "311": "LightSleet",
    "314": "LightSleet",
    "317": "LightSleet",
    "320": "LightSnow",
    "323": "LightSnowShowers",
    "326": "LightSnowShowers",
    "329": "HeavySnow",
    "332": "HeavySnow",
    "335": "HeavySnowShowers",
    "338": "HeavySnow",
    "350": "LightSleet",
    "353": "LightShowers",
    "356": "HeavyShowers",
    "359": "HeavyRain",
    "362": "LightSleetShowers",
    "365": "LightSleetShowers",
    "368": "LightSnowShowers",
    "371": "HeavySnowShowers",
    "374": "LightSleetShowers",
    "377": "LightSleet",
    "386": "ThunderyShowers",
    "389": "ThunderyHeavyRain",
    "392": "ThunderySnowShowers",
    "395": "HeavySnowShowers",
}

# see https://docs.python.org/3/library/locale.html#background-details-hints-tips-and-caveats
locale.setlocale(locale.LC_ALL, "")
current_locale, _ = locale.getlocale(locale.LC_NUMERIC)
data = {}
city = ""
temperature = "C"
distance = "km"

if current_locale == "en_US":
    temperature = "F"
    distance = "miles"

argument_list = sys.argv[1:]
options = "t:c:d:"
long_options = ["temperature=", "city=", "distance="]

try:
    args, values = getopt.getopt(argument_list, options, long_options)

    for current_argument, current_value in args:
        if current_argument in ("-t", "--temperature"):
            temperature = current_value[0].upper()
            if temperature not in ("C", "F"):
                msg = "temperature unit is neither (C)elsius, nor (F)ahrenheit"
                raise RuntimeError(
                    msg,
                    temperature,
                )

        elif current_argument in ("-d", "--distance"):
            distance = current_value.lower()
            if distance not in ("km", "miles"):
                msg = "distance unit is neither km, nor miles", distance
                raise RuntimeError(msg)

        else:
            city = urllib.parse.quote(current_value)

except getopt.error as err:
    print(str(err))
    sys.exit(1)

if city == "":
    try:
        city_info = requests.get("http://ip-api.com/json/", timeout=10).json()
        city = city_info["city"]
    except (
        requests.exceptions.HTTPError,
        requests.exceptions.ConnectionError,
        requests.exceptions.Timeout,
    ) as err:
        print(str(err))
        sys.exit(1)

feels_like = f"FeelsLike{temperature}"
temp = f"temp_{temperature}"
min_temp = f"mintemp{temperature}"
max_temp = f"maxtemp{temperature}"

windspeed = "windspeedKmph"
if distance == "miles":
    windspeed = "windspeedMiles"

try:
    weather = requests.get("https://wttr.in/" + city + "?format=j1", timeout=10).json()
except (
    requests.exceptions.HTTPError,
    requests.exceptions.ConnectionError,
    requests.exceptions.Timeout,
) as err:
    print(str(err))
    sys.exit(1)


def format_time(time: str) -> str:
    """Format time."""
    return time.replace("00", "").zfill(2)


def format_temp(temp: str) -> str:
    """Format temp."""
    return (f"{temp}°{temperature}").ljust(3)


def format_chances(hour: int) -> str:
    """Format chances."""
    chances = {
        "chanceoffog": "Fog",
        "chanceoffrost": "Frost",
        "chanceofovercast": "Overcast",
        "chanceofrain": "Rain",
        "chanceofsnow": "Snow",
        "chanceofsunshine": "Sunshine",
        "chanceofthunder": "Thunder",
        "chanceofwindy": "Wind",
    }

    conditions = []
    for event in chances:
        if int(hour[event]) > 0:
            conditions.append(chances[event] + " " + hour[event] + "%")  # noqa: PERF401
    return ", ".join(conditions)


data["text"] = f"{weather['current_condition'][0][feels_like]}°{temperature}"
data["alt"] = WWO_CODE[weather["current_condition"][0]["weatherCode"]]

data["tooltip"] = (
    f"Weather in <b>{weather['nearest_area'][0]['areaName'][0]['value']}</b>:\n"
)
data["tooltip"] += (
    f"<b>{weather['current_condition'][0]['weatherDesc'][0]['value']} "
    f"{weather['current_condition'][0][temp]}°{temperature}</b>\n"
)
data["tooltip"] += (
    f"Feels like: {weather['current_condition'][0][feels_like]}°{temperature}\n"
)
data["tooltip"] += f"Wind: {weather['current_condition'][0][windspeed]}{distance}/h\n"
data["tooltip"] += f"Humidity: {weather['current_condition'][0]['humidity']}%\n"
for i, day in enumerate(weather["weather"]):
    data["tooltip"] += "\n<b>"
    if i == 0:
        data["tooltip"] += "Today, "
    if i == 1:
        data["tooltip"] += "Tomorrow, "
    data["tooltip"] += f"{day['date']}</b>\n"
    data["tooltip"] += (
        f"⬆️ {day[max_temp]}°{temperature} ⬇️ {day[min_temp]}°{temperature} "
    )
    data["tooltip"] += (
        f"🌅 {day['astronomy'][0]['sunrise']} 🌇 {day['astronomy'][0]['sunset']}\n"
    )
    for hour in day["hourly"]:
        if i == 0 and int(format_time(hour["time"])) < datetime.now().hour - 2:  # noqa: DTZ005
            continue
        data["tooltip"] += (
            f"{format_time(hour['time'])} "
            f"{WEATHER_SYMBOL[WWO_CODE[hour['weatherCode']]]} "
            f"{format_temp(hour[feels_like])} {hour['weatherDesc'][0]['value']}, "
            f"{format_chances(hour)}\n"
        )


print(json.dumps(data))
