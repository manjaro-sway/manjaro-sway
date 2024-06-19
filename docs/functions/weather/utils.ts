export const supportedLocales = ["en", "de", "fr", "it"] as const;

type WWOCode =
  | 0
  | 1
  | 2
  | 3
  | 45
  | 48
  | 51
  | 53
  | 55
  | 56
  | 57
  | 61
  | 63
  | 65
  | 66
  | 67
  | 71
  | 73
  | 75
  | 77
  | 80
  | 81
  | 82
  | 85
  | 86
  | 95
  | 96
  | 99;

export const wmoCodeToEmojiMap: Record<WWOCode, string> = {
  0: "☀️", // Clear sky
  1: "🌤️", // Mainly clear
  2: "⛅", // Partly cloudy
  3: "☁️", // Overcast
  45: "🌫️", // Fog
  48: "🌫️", // Depositing rime fog
  51: "🌧️", // Drizzle: Light intensity
  53: "🌧️", // Drizzle: Moderate intensity
  55: "🌧️", // Drizzle: Dense intensity
  56: "🌧️", // Freezing Drizzle: Light intensity
  57: "🌧️", // Freezing Drizzle: Dense intensity
  61: "🌧️", // Rain: Slight intensity
  63: "🌧️", // Rain: Moderate intensity
  65: "🌧️", // Rain: Heavy intensity
  66: "🌧️", // Freezing Rain: Light intensity
  67: "🌧️", // Freezing Rain: Heavy intensity
  71: "❄️", // Snow fall: Slight intensity
  73: "❄️", // Snow fall: Moderate intensity
  75: "❄️", // Snow fall: Heavy intensity
  77: "❄️", // Snow grains
  80: "🌧️", // Rain showers: Slight intensity
  81: "🌧️", // Rain showers: Moderate intensity
  82: "🌧️", // Rain showers: Violent intensity
  85: "❄️", // Snow showers: Slight intensity
  86: "❄️", // Snow showers: Heavy intensity
  95: "⛈️", // Thunderstorm: Slight or moderate
  96: "⛈️", // Thunderstorm with slight hail
  99: "⛈️", // Thunderstorm with heavy hail
};

type WMOTranslation = Record<WWOCode, string>;

export const wmoCodeToText: Record<(typeof supportedLocales)[number], WMOTranslation> =
  {
    en: {
      0: "Clear sky",
      1: "Mainly clear",
      2: "Partly cloudy",
      3: "Overcast",
      45: "Fog",
      48: "Depositing rime fog",
      51: "Light drizzle",
      53: "Moderate drizzle",
      55: "Dense drizzle",
      56: "Light freezing drizzle",
      57: "Dense freezing drizzle",
      61: "Slight rain",
      63: "Moderate rain",
      65: "Heavy rain",
      66: "Light freezing rain",
      67: "Heavy freezing rain",
      71: "Slight snow fall",
      73: "Moderate snow fall",
      75: "Heavy snow fall",
      77: "Snow grains",
      80: "Slight rain showers",
      81: "Moderate rain showers",
      82: "Violent rain showers",
      85: "Slight snow showers",
      86: "Heavy snow showers",
      95: "Slight or moderate thunderstorm",
      96: "Thunderstorm with slight hail",
      99: "Thunderstorm with heavy hail",
    },
    de: {
      0: "Klarer Himmel",
      1: "Überwiegend klar",
      2: "Teilweise bewölkt",
      3: "Bedeckt",
      45: "Nebel",
      48: "Rauhreifnebel",
      51: "Leichter Nieselregen",
      53: "Mäßiger Nieselregen",
      55: "Dichter Nieselregen",
      56: "Leichter gefrierender Nieselregen",
      57: "Dichter gefrierender Nieselregen",
      61: "Leichter Regen",
      63: "Mäßiger Regen",
      65: "Starker Regen",
      66: "Leichter gefrierender Regen",
      67: "Starker gefrierender Regen",
      71: "Leichter Schneefall",
      73: "Mäßiger Schneefall",
      75: "Starker Schneefall",
      77: "Schneekörner",
      80: "Leichte Regenschauer",
      81: "Mäßige Regenschauer",
      82: "Heftige Regenschauer",
      85: "Leichte Schneeschauer",
      86: "Starke Schneeschauer",
      95: "Leichtes oder mäßiges Gewitter",
      96: "Gewitter mit leichtem Hagel",
      99: "Gewitter mit starkem Hagel",
    },
    fr: {
      0: "Ciel dégagé",
      1: "Ciel peu nuageux",
      2: "Ciel partiellement nuageux",
      3: "Ciel nuageux",
      45: "Brouillard",
      48: "Brouillard givrant",
      51: "Bruine légère",
      53: "Bruine modérée",
      55: "Bruine forte",
      56: "Bruine verglaçante légère",
      57: "Bruine verglaçante forte",
      61: "Pluie faible",
      63: "Pluie modérée",
      65: "Pluie forte",
      66: "Pluie verglaçante légère",
      67: "Pluie verglaçante forte",
      71: "Chute de neige faible",
      73: "Chute de neige modérée",
      75: "Chute de neige forte",
      77: "Grains de neige",
      80: "Averses de pluie faibles",
      81: "Averses de pluie modérées",
      82: "Averses de pluie fortes",
      85: "Averses de neige faibles",
      86: "Averses de neige fortes",
      95: "Orages faibles ou modérés",
      96: "Orages avec grêle légère",
      99: "Orages avec grêle forte",
    },
    it: {
      0: "Cielo sereno",
      1: "Poco nuvoloso",
      2: "Parzialmente nuvoloso",
      3: "Nuvoloso",
      45: "Nebbia",
      48: "Nebbia con rime",
      51: "Pioviggine debole",
      53: "Pioviggine moderata",
      55: "Pioviggine intensa",
      56: "Pioviggine debole ghiacciata",
      57: "Pioviggine intensa ghiacciata",
      61: "Pioggia debole",
      63: "Pioggia moderata",
      65: "Pioggia forte",
      66: "Pioggia debole ghiacciata",
      67: "Pioggia forte ghiacciata",
      71: "Debole nevicata",
      73: "Nevicata moderata",
      75: "Nevicata forte",
      77: "Grani di neve",
      80: "Pioviggine debole",
      81: "Pioviggine moderata",
      82: "Pioviggine intensa",
      85: "Debole nevicata",
      86: "Nevicata forte",
      95: "Temporali deboli o moderati",
      96: "Temporali con grandine leggera",
      99: "Temporali con grandine forte",
    },
  };