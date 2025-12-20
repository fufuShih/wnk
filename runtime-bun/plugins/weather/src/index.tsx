// ============================================
// Weather Plugin
// Provides weather results + a forecast panel
// Uses Open-Meteo API (free, no API key required)
// ============================================

import type { ResultItem } from '@wnk/sdk';
import { Box } from '@wnk/sdk';

type WeatherData = {
  city: string;
  temp: number;
  description: string;
};

type ForecastDay = {
  date: string;
  temp_max: number;
  temp_min: number;
  weatherCode: number;
};

// Default coordinates (Taipei)
const DEFAULT_LAT = 25.0330;
const DEFAULT_LON = 121.5654;
const DEFAULT_CITY = 'Taipei';

// Cache for weather data
let cachedWeather: WeatherData | null = null;
let cachedForecast: ForecastDay[] | null = null;
let lastFetch = 0;
const CACHE_DURATION = 10 * 60 * 1000; // 10 minutes

function getWeatherDescription(code: number): string {
  if (code === 0) return 'Clear sky';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 48) return 'Foggy';
  if (code <= 67) return 'Rainy';
  if (code <= 77) return 'Snowy';
  if (code <= 82) return 'Rain showers';
  if (code <= 86) return 'Snow showers';
  return 'Thunderstorm';
}

async function fetchWeatherData(): Promise<{ weather: WeatherData; forecast: ForecastDay[] } | null> {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${DEFAULT_LAT}&longitude=${DEFAULT_LON}&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia/Taipei&forecast_days=7`;
    const response = await fetch(url);
    if (!response.ok) return null;

    const data = await response.json();

    const weather: WeatherData = {
      city: DEFAULT_CITY,
      temp: Math.round(data.current.temperature_2m),
      description: getWeatherDescription(data.current.weather_code),
    };

    const forecast: ForecastDay[] = [];
    for (let i = 0; i < Math.min(7, data.daily.time.length); i++) {
      forecast.push({
        date: data.daily.time[i],
        temp_max: Math.round(data.daily.temperature_2m_max[i]),
        temp_min: Math.round(data.daily.temperature_2m_min[i]),
        weatherCode: data.daily.weather_code[i],
      });
    }

    return { weather, forecast };
  } catch {
    return null;
  }
}

async function updateWeatherCache(): Promise<void> {
  const now = Date.now();
  if (cachedWeather && cachedForecast && now - lastFetch < CACHE_DURATION) return;

  const result = await fetchWeatherData();
  if (result) {
    cachedWeather = result.weather;
    cachedForecast = result.forecast;
    lastFetch = now;
  }
}

type WeatherPanelProps = {
  weather: WeatherData | null;
  forecast: ForecastDay[] | null;
};

function WeatherPanel(props: WeatherPanelProps): JSX.Element {
  if (!props.weather || !props.forecast) {
    return (
      <Box
        top={{ type: 'header', title: 'Weather', subtitle: 'Unable to load weather data' }}
        bottom={{ type: 'info', text: 'Status: offline' }}
        dir="vertical"
        gap={12}
      >
        <Box layout="flex">
          <Box title="Offline" subtitle="No cached forecast available" />
        </Box>
      </Box>
    );
  }

  return (
    <Box
      top={{ type: 'header', title: 'Weather', subtitle: '7-day forecast' }}
      bottom={{ type: 'info', text: 'Data: Open-Meteo · Cache: 10m' }}
      dir="vertical"
      gap={12}
    >
      <Box layout="flex">
        <Box title={`${props.weather.city}  ${props.weather.temp}°C`} subtitle={props.weather.description} />
      </Box>

      <Box layout="grid" columns={2} gap={12}>
        {props.forecast.map((day) => (
          <Box
            key={day.date}
            title={`${day.date}  ${day.temp_max}° / ${day.temp_min}°`}
            subtitle={getWeatherDescription(day.weatherCode)}
          />
        ))}
      </Box>
    </Box>
  );
}

export async function getResults(_query: string): Promise<ResultItem[]> {
  // Always return weather data - filtering is done by Zig host
  return [
    {
      id: 'weather',
      title: 'Weather',
      subtitle: 'View current weather and forecast',
      icon: 'W',
    },
  ];
}

export async function getPanel(itemId: string): Promise<JSX.Element | null> {
  if (itemId !== 'weather') return null;

  await updateWeatherCache();
  return <WeatherPanel weather={cachedWeather} forecast={cachedForecast} />;
}

export default WeatherPanel;
