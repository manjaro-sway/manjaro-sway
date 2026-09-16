#!/usr/bin/env python
"""Script for the Waybar weather module.

This used to call a cloudflare worker that talked to open-meteo and
rendered the tooltip server-side, so a desktop showed whatever that
deployment happened to be serving. The rendering lives here instead: the
module calls MET Norway (the institute behind yr.no) directly and emits
the {"text", "tooltip"} shape waybar expects, which means an installed
desktop keeps working whatever happens to our infrastructure.

Location is the exception: /geo on the ashlaros worker answers with the
coordinates cloudflare attaches at its edge, so the machine's IP goes
there rather than to a commercial geo-ip service. That deployment belongs
to a sibling project, not to this one - our own /geo redirects to it, and
MANJARO_SWAY_GEO_URL points somewhere else for anyone who prefers. When it
is unreachable the module falls back to the last forecast it cached, and
only fails outright if it has never succeeded.

MET asks three things of a client in return for a free, keyless API, and
all three are obligations rather than courtesies - "if we cannot contact
you in case of problems, you risk being blocked without warning":

  - identify yourself in User-Agent, with a contact address
  - cache, and revalidate with If-Modified-Since rather than refetching
  - do not schedule on the hour; their data updates continuously

Geocoding stays on open-meteo: MET publishes no geocoding API.
"""

import argparse
import configparser
import json
import locale
import sys
from datetime import datetime
from os import environ, makedirs, path

import requests

# MET wants to know who is calling and how to reach them. Sending the
# default python-requests string is against their terms even where it is
# currently served.
USER_AGENT = "manjaro-sway-weather/1.0 github.com/manjaro-sway/manjaro-sway"

FORECAST_URL = "https://api.met.no/weatherapi/locationforecast/2.0/complete"

# The ashlaros worker rather than a commercial geo-ip service: the desktop
# should not tell a data broker its IP address on every weather refresh.
# That deployment belongs to a sibling project, not to this one; set
# MANJARO_SWAY_GEO_URL to use a different one.
GEO_URL = environ.get("MANJARO_SWAY_GEO_URL", "https://ashlaros.download/geo")

# MET's symbol vocabulary, which replaces open-meteo's WMO integers. The
# whole set, not only what one sample happened to return: a code we do not
# know renders as an empty icon, and that is a bug a user sees on the one
# day the weather is interesting. Verified against live responses from
# twelve locations spanning the tropics to Svalbard.
#
# Each of these also appears with a _day, _night or _polartwilight suffix,
# which is why the suffix is stripped before lookup - and why the old
# "a clear sky at night is a moon" special case is gone: MET says
# clearsky_night directly.
SYMBOL_EMOJI = {
    "clearsky": "☀️", "fair": "🌤️", "partlycloudy": "⛅", "cloudy": "☁️",
    "fog": "🌫️",
    "lightrainshowers": "🌦️", "rainshowers": "🌦️", "heavyrainshowers": "🌧️",
    "lightrain": "🌧️", "rain": "🌧️", "heavyrain": "🌧️",
    "lightsleet": "🌨️", "sleet": "🌨️", "heavysleet": "🌨️",
    "lightsleetshowers": "🌨️", "sleetshowers": "🌨️", "heavysleetshowers": "🌨️",
    "lightsnow": "❄️", "snow": "❄️", "heavysnow": "❄️",
    "lightsnowshowers": "🌨️", "snowshowers": "🌨️", "heavysnowshowers": "🌨️",
    "lightrainandthunder": "⛈️", "rainandthunder": "⛈️",
    "heavyrainandthunder": "⛈️",
    "lightrainshowersandthunder": "⛈️", "rainshowersandthunder": "⛈️",
    "heavyrainshowersandthunder": "⛈️",
    "lightsleetandthunder": "⛈️", "sleetandthunder": "⛈️",
    "heavysleetandthunder": "⛈️",
    "lightssleetshowersandthunder": "⛈️", "sleetshowersandthunder": "⛈️",
    "heavysleetshowersandthunder": "⛈️",
    "lightsnowandthunder": "⛈️", "snowandthunder": "⛈️",
    "heavysnowandthunder": "⛈️",
    "lightssnowshowersandthunder": "⛈️", "snowshowersandthunder": "⛈️",
    "heavysnowshowersandthunder": "⛈️",
}

SYMBOL_TEXT = {
    "clearsky": "Clear sky", "fair": "Fair", "partlycloudy": "Partly cloudy",
    "cloudy": "Cloudy", "fog": "Fog",
    "lightrainshowers": "Light rain showers", "rainshowers": "Rain showers",
    "heavyrainshowers": "Heavy rain showers",
    "lightrain": "Light rain", "rain": "Rain", "heavyrain": "Heavy rain",
    "lightsleet": "Light sleet", "sleet": "Sleet", "heavysleet": "Heavy sleet",
    "lightsleetshowers": "Light sleet showers",
    "sleetshowers": "Sleet showers",
    "heavysleetshowers": "Heavy sleet showers",
    "lightsnow": "Light snow", "snow": "Snow", "heavysnow": "Heavy snow",
    "lightsnowshowers": "Light snow showers", "snowshowers": "Snow showers",
    "heavysnowshowers": "Heavy snow showers",
    "lightrainandthunder": "Light rain and thunder",
    "rainandthunder": "Rain and thunder",
    "heavyrainandthunder": "Heavy rain and thunder",
    "lightrainshowersandthunder": "Light rain showers and thunder",
    "rainshowersandthunder": "Rain showers and thunder",
    "heavyrainshowersandthunder": "Heavy rain showers and thunder",
    "lightsleetandthunder": "Light sleet and thunder",
    "sleetandthunder": "Sleet and thunder",
    "heavysleetandthunder": "Heavy sleet and thunder",
    "lightssleetshowersandthunder": "Light sleet showers and thunder",
    "sleetshowersandthunder": "Sleet showers and thunder",
    "heavysleetshowersandthunder": "Heavy sleet showers and thunder",
    "lightsnowandthunder": "Light snow and thunder",
    "snowandthunder": "Snow and thunder",
    "heavysnowandthunder": "Heavy snow and thunder",
    "lightssnowshowersandthunder": "Light snow showers and thunder",
    "snowshowersandthunder": "Snow showers and thunder",
    "heavysnowshowersandthunder": "Heavy snow showers and thunder",
}

# above 6 the index is worth calling out; below it the line is noise
UV_EMOJI = {3: "😎", 4: "😎", 5: "😎", 6: "🫠", 7: "🫠",
            8: "🥵", 9: "🥵", 10: "🥵", 11: "🥵"}

config_path = path.join(
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

if current_locale == "en_US":
    temperature = temperature or "F"
    distance = distance or "miles"

parser = argparse.ArgumentParser(description='Waybar weather module')
parser.add_argument('-t', '--temperature', default=temperature, choices=['C', 'F'],
                    help='Temperature unit: C (Celsius) or F (Fahrenheit)')
parser.add_argument('-d', '--distance', default=distance, choices=['km', 'miles'],
                    help='Distance unit: km or miles')
parser.add_argument('-c', '--city', default=city,
                    help='City name or "auto" for automatic detection')
args = parser.parse_args()

temperature = args.temperature.upper()
distance = args.distance.lower()
city = args.city

cache_dir = path.join(
    environ.get('XDG_CACHE_HOME') or path.join(environ['HOME'], '.cache'),
    "manjaro-sway",
)
cache_file = path.join(cache_dir, "weather.json")
# the upstream response, kept beside the rendered one: revalidating needs
# the body and its Last-Modified, which the rendered tooltip does not carry
response_cache_file = path.join(cache_dir, "weather-response.json")


# MET always answers in celsius and m/s - unlike open-meteo it takes no
# unit parameters - so the -t/-d flags become our conversion job. Dropping
# them would be a silent regression for anyone on Fahrenheit.
def to_temperature(celsius):
    if celsius is None:
        return None
    return round(celsius * 9 / 5 + 32, 1) if temperature == "F" else round(celsius, 1)


def to_speed(metres_per_second):
    """m/s as km/h or mph, whichever the distance unit implies."""
    if metres_per_second is None:
        return None
    factor = 2.236936 if distance == "miles" else 3.6
    return round(metres_per_second * factor, 1)


TEMPERATURE_UNIT = "°F" if temperature == "F" else "°C"
SPEED_UNIT = "mph" if distance == "miles" else "km/h"


def symbol_parts(symbol_code):
    """(emoji, text) for a MET symbol_code, suffix and all."""
    if not symbol_code:
        return "", ""
    base = symbol_code.split("_", 1)[0]
    return SYMBOL_EMOJI.get(base, ""), SYMBOL_TEXT.get(base, "")


def resolve_location(name):
    """Coordinates and display name for a city, or for this machine's IP.

    'auto' asks the ashlaros worker, which reads the geo data Cloudflare
    already attached to the request at its edge - so the machine's IP goes
    there rather than to a commercial geo-ip service. Anything else is
    geocoded by open-meteo, which MET has no equivalent for and which a
    city name typed by the user cannot be derived from.
    """
    if name == 'auto':
        result = requests.get(GEO_URL, timeout=10)
        result.raise_for_status()
        geo = result.json()
        return geo['latitude'], geo['longitude'], geo.get('city')

    result = requests.get(
        "https://geocoding-api.open-meteo.com/v1/search",
        params={"name": name, "count": 1},
        timeout=10,
    ).json()
    if not result.get('results'):
        raise ValueError(f"no such place: {name}")
    place = result['results'][0]
    return place['latitude'], place['longitude'], place['name']


def read_response_cache():
    """The stored upstream body and its Last-Modified, if any."""
    try:
        with open(response_cache_file) as f:
            stored = json.load(f)
        return stored.get('body'), stored.get('last_modified')
    except (OSError, ValueError):
        return None, None


def fetch_forecast(latitude, longitude):
    """The forecast, revalidated rather than refetched when possible.

    MET asks callers to cache and send If-Modified-Since. A 304 costs them
    almost nothing and us a round trip, and skipping it is the behaviour
    they block for.
    """
    body, last_modified = read_response_cache()
    headers = {"User-Agent": USER_AGENT}
    if body is not None and last_modified:
        headers["If-Modified-Since"] = last_modified

    response = requests.get(
        FORECAST_URL,
        params={"lat": round(latitude, 4), "lon": round(longitude, 4)},
        headers=headers,
        timeout=10,
    )

    if response.status_code == 304 and body is not None:
        return body

    response.raise_for_status()
    body = response.json()
    makedirs(cache_dir, exist_ok=True)
    with open(response_cache_file, 'w') as f:
        json.dump(
            {"body": body, "last_modified": response.headers.get("Last-Modified")},
            f,
        )
    return body


def entry_symbol(entry):
    """The symbol_code covering an entry, from the shortest period given.

    MET drops to 6-hourly beyond ~2.5 days, and those entries carry no
    next_1_hours at all - so a lookup that assumed hourly would render a
    blank icon for the tail of the forecast.
    """
    for period in ("next_1_hours", "next_6_hours", "next_12_hours"):
        summary = entry['data'].get(period, {}).get('summary', {})
        if summary.get('symbol_code'):
            return summary['symbol_code']
    return ""


def entry_precipitation(entry):
    """Precipitation in mm over the period this entry covers, if stated."""
    for period in ("next_1_hours", "next_6_hours"):
        details = entry['data'].get(period, {}).get('details', {})
        if 'precipitation_amount' in details:
            return details['precipitation_amount']
    return None


def render(place, data):
    timeseries = data['properties']['timeseries']
    now = timeseries[0]
    details = now['data']['instant']['details']
    icon, text = symbol_parts(entry_symbol(now))

    lines = [
        f"<b>{place}</b>:",
        f"<b>{text} {icon}</b>",
        f"Feels like: {to_temperature(details.get('apparent_air_temperature'))}{TEMPERATURE_UNIT}",
        f"Wind: {to_speed(details.get('wind_speed'))}{SPEED_UNIT}",
        f"Humidity: {details.get('relative_humidity')}%",
    ]

    # MET timestamps are UTC. Grouping by the raw string would put evening
    # hours on the next day for anyone east of Greenwich, so convert to
    # local time first and group on that.
    hours = []
    for entry in timeseries:
        when = datetime.fromisoformat(
            entry['time'].replace("Z", "+00:00")).astimezone()
        instant = entry['data']['instant']['details']
        hours.append({
            'day': when.date(),
            'hour': when.hour,
            'temperature': to_temperature(instant.get('apparent_air_temperature')),
            'symbol': entry_symbol(entry),
            'precipitation': entry_precipitation(entry),
            'uv': instant.get('ultraviolet_index_clear_sky'),
            'min': entry['data'].get('next_6_hours', {})
                        .get('details', {}).get('air_temperature_min'),
            'max': entry['data'].get('next_6_hours', {})
                        .get('details', {}).get('air_temperature_max'),
        })

    # every other hour: 36 rows is a tooltip, 72 is a wall of text. The
    # entries are not uniformly hourly once the forecast coarsens, so this
    # filters on the hour itself rather than on position.
    even_hours = [h for h in hours if h['hour'] % 2 == 0]

    days = []
    for day in sorted({h['day'] for h in hours})[:3]:
        of_day = [h for h in hours if h['day'] == day]
        lows = [h['min'] for h in of_day if h['min'] is not None]
        highs = [h['max'] for h in of_day if h['max'] is not None]
        uvs = [h['uv'] for h in of_day if h['uv'] is not None]

        # the symbol for the day is the one covering its middle, not its
        # first hour, which for today is whatever it is doing right now
        midday = min(of_day, key=lambda h: abs(h['hour'] - 12))
        day_icon, day_text = symbol_parts(midday['symbol'])
        header = f"<b>{day.isoformat()}</b> - {day_text} {day_icon}"

        span = ""
        if lows and highs:
            span = (
                f"⬇️{to_temperature(min(lows))}{TEMPERATURE_UNIT}"
                f" ⬆️{to_temperature(max(highs))}{TEMPERATURE_UNIT}"
            )
        if uvs:
            uv = max(uvs)
            if uv >= 6:
                span += f" {UV_EMOJI.get(round(uv), '')}{uv} UV Index"

        rows = []
        for hour in (h for h in even_hours if h['day'] == day):
            hour_icon, hour_text = symbol_parts(hour['symbol'])
            row = (
                f"{hour['hour']}: {hour['temperature']}{TEMPERATURE_UNIT}"
                f" {hour_text} {hour_icon}"
            )
            # MET publishes no probability of precipitation, only an
            # amount. Labelling it mm rather than reusing the old ☔n%
            # keeps the number meaning what it says.
            if hour['precipitation']:
                row += f" ☔{hour['precipitation']}mm"
            rows.append(row)

        days.append("\n".join([header, *([span] if span else []), *rows]))

    updated = datetime.now().strftime("%c")
    return {
        "text": f"{icon} {to_temperature(details.get('air_temperature'))}{TEMPERATURE_UNIT}",
        "tooltip": "\n".join(lines) + "\n\n" + "\n\n".join(days)
                   + f"\n\nLast update: {updated}"
                   + "\n\nWeather data from MET Norway (met.no)",
    }


try:
    latitude, longitude, place = resolve_location(city)
    forecast = fetch_forecast(latitude, longitude)
    weather = render(place, forecast)
    makedirs(cache_dir, exist_ok=True)
    with open(cache_file, 'w') as f:
        json.dump(weather, f)
except (
    requests.exceptions.HTTPError,
    requests.exceptions.ConnectionError,
    requests.exceptions.Timeout,
    KeyError,
    ValueError,
) as err:
    if path.exists(cache_file):
        with open(cache_file) as f:
            weather = json.load(f)
    else:
        print(str(err), file=sys.stderr)
        sys.exit(1)

print(json.dumps(weather))
