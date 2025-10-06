#!/usr/bin/env python
"""Script for the Waybar weather module."""

import getopt
import json
import locale
import sys
import urllib.parse
import requests
import configparser
from os import path, environ

config_path = path.join(
    environ.get('APPDATA') or
    environ.get('XDG_CONFIG_HOME') or
    path.join(environ['HOME'], '.config'),
    "weather.cfg"
)

config = configparser.ConfigParser()
config.read(config_path)

# see https://docs.python.org/3/library/locale.html#background-details-hints-tips-and-caveats
locale.setlocale(locale.LC_ALL, "")
current_locale, _ = locale.getlocale(locale.LC_NUMERIC)
city = config.get('DEFAULT', 'city', fallback='auto')
temperature = config.get('DEFAULT', 'temperature', fallback='C')
distance = config.get('DEFAULT', 'distance', fallback='km')
lng = config.get('DEFAULT', 'locale', fallback=locale.getlocale()[0] or current_locale)

if current_locale == "en_US":
    temperature = temperature or "F"
    distance = distance or "miles"

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

if temperature == "F":
    temperature_unit = "fahrenheit"

if temperature == "C":
    temperature_unit = "celsius"

if distance == "miles":
    wind_speed_unit = "mph"

if distance == "km":
    wind_speed_unit = "kmh"

try:
    headers = {"Accept-Language": f"{lng.replace("_", "-")},{lng.split("_")[0]};q=0.5"}
    weather = requests.get(f"https://manjaro-sway.download/weather/{city}?temperature_unit={temperature_unit}&wind_speed_unit={wind_speed_unit}", timeout=10, headers=headers).json()
except (
    requests.exceptions.HTTPError,
    requests.exceptions.ConnectionError,
    requests.exceptions.Timeout,
) as err:
    print(str(err))
    sys.exit(1)

print(json.dumps(weather))
