#!/usr/bin/env python

# credits: @bjesus https://gist.github.com/bjesus/f8db49e1434433f78e5200dc403d58a3

import json
import os
import requests
import sys
import urllib.parse
from datetime import datetime
import getopt, sys

WEATHER_SYMBOL = {
    "Unknown":             "✨",
    "Cloudy":              "☁️",
    "Fog":                 "🌫",
    "HeavyRain":           "🌧",
    "HeavyShowers":        "🌧",
    "HeavySnow":           "❄️",
    "HeavySnowShowers":    "❄️",
    "LightRain":           "🌦",
    "LightShowers":        "🌦",
    "LightSleet":          "🌧",
    "LightSleetShowers":   "🌧",
    "LightSnow":           "🌨",
    "LightSnowShowers":    "🌨",
    "PartlyCloudy":        "⛅️",
    "Sunny":               "☀️",
    "ThunderyHeavyRain":   "🌩",
    "ThunderyShowers":     "⛈",
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

data = {}
city = ""
temperature = "C"
distance = "km"

if os.environ['LC_MEASUREMENT']:
    current_locale = os.environ['LC_MEASUREMENT'].split('.')[0]

if current_locale == "en_US":
    temperature = "F"
    distance = "miles"

argumentList = sys.argv[1:]
options = "t:c:d:"
long_options = ["temperature=", "city=", "distance="]

try:
    args, values = getopt.getopt(argumentList, options, long_options)
     
    for currentArgument, currentValue in args:
        if currentArgument in ("-t", "--temperature"):
            temperature = currentValue[0].upper()
            if temperature != "C" and temperature != "F":
                raise Exception("temperature unit is neither (C)elsius, nor (F)ahrenheit", temperature)

        elif currentArgument in ("-d", "--distance"):
            distance = currentValue.lower()
            if distance != "km" and distance != "miles":
                raise Exception("distance unit is neither km, nor miles", distance)

        else:
            city = urllib.parse.quote(currentValue)            
  
except getopt.error as err:
    print (str(err))
    exit(1)

feelsLike = f"FeelsLike{temperature}"
temp = f"temp_{temperature}"
minTemp = f"mintemp{temperature}"
maxTemp = f"maxtemp{temperature}"

windspeed = f"windspeedKmph"
if distance == "miles":
    windspeed = f"windspeedMiles"

weather = requests.get("https://wttr.in/" + city + "?format=j1").json()


def format_time(time):
    return time.replace("00", "").zfill(2)

def format_temp(temp):
    return (f"{hour[feelsLike]}°{temperature}").ljust(3)

def format_chances(hour):
    chances = {
        "chanceoffog": "Fog",
        "chanceoffrost": "Frost",
        "chanceofovercast": "Overcast",
        "chanceofrain": "Rain",
        "chanceofsnow": "Snow",
        "chanceofsunshine": "Sunshine",
        "chanceofthunder": "Thunder",
        "chanceofwindy": "Wind"
    }

    conditions = []
    for event in chances.keys():
        if int(hour[event]) > 0:
            conditions.append(chances[event]+" "+hour[event]+"%")
    return ", ".join(conditions)

data['text'] = f"{weather['current_condition'][0][feelsLike]}°{temperature}"
data['alt'] = WWO_CODE[weather['current_condition'][0]['weatherCode']]

data['tooltip'] = f"Weather in <b>{weather['nearest_area'][0]['areaName'][0]['value']}</b>:\n"
data['tooltip'] += f"<b>{weather['current_condition'][0]['weatherDesc'][0]['value']} {weather['current_condition'][0][temp]}°{temperature}</b>\n"
data['tooltip'] += f"Feels like: {weather['current_condition'][0][feelsLike]}°{temperature}\n"
data['tooltip'] += f"Wind: {weather['current_condition'][0][windspeed]}{distance}/h\n"
data['tooltip'] += f"Humidity: {weather['current_condition'][0]['humidity']}%\n"
for i, day in enumerate(weather['weather']):
    data['tooltip'] += f"\n<b>"
    if i == 0:
        data['tooltip'] += "Today, "
    if i == 1:
        data['tooltip'] += "Tomorrow, "
    data['tooltip'] += f"{day['date']}</b>\n"
    data['tooltip'] += f"⬆️ {day[maxTemp]}°{temperature} ⬇️ {day[minTemp]}°{temperature} "
    data['tooltip'] += f"🌅 {day['astronomy'][0]['sunrise']} 🌇 {day['astronomy'][0]['sunset']}\n"
    for hour in day['hourly']:
        if i == 0:
            if int(format_time(hour['time'])) < datetime.now().hour-2:
                continue
        data['tooltip'] += f"{format_time(hour['time'])} {WEATHER_SYMBOL[WWO_CODE[hour['weatherCode']]]} {format_temp(hour[feelsLike])} {hour['weatherDesc'][0]['value']}, {format_chances(hour)}\n"


print(json.dumps(data))
