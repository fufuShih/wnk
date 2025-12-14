// ============================================
// Weather Plugin
// Provides weather results and 7-day forecast in subpanel
// Uses Open-Meteo API (free, no API key required)
// ============================================

export type ResultItem = {
  id?: string;
  title: string;
  subtitle?: string;
  icon?: string;
  action?: 'subpanel';
  subpanelId?: string;
};

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
  if (cachedWeather && cachedForecast && now - lastFetch < CACHE_DURATION) {
    return;
  }

  const result = await fetchWeatherData();
  if (result) {
    cachedWeather = result.weather;
    cachedForecast = result.forecast;
    lastFetch = now;
  }
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

// Subpanel data structure for Zig to render
export type SubpanelItem = {
  title: string;
  subtitle: string;
};

export type SubpanelData = {
  header: string;
  headerSubtitle?: string;
  layout?: { mode: 'list' | 'grid'; columns?: number; gap?: number };
  items: SubpanelItem[];
};

export async function getSubpanel(itemId: string): Promise<SubpanelData | null> {
  if (itemId !== 'weather') return null;

  await updateWeatherCache();

  if (!cachedWeather || !cachedForecast) {
    return {
      header: 'Weather',
      headerSubtitle: 'Unable to load weather data',
      items: [],
    };
  }

  const items: SubpanelItem[] = cachedForecast.map((day) => ({
    title: `${day.date}  ${day.temp_max}° / ${day.temp_min}°`,
    subtitle: getWeatherDescription(day.weatherCode),
  }));

  return {
    header: 'Weather',
    headerSubtitle: `${cachedWeather.city} - ${cachedWeather.temp}°C ${cachedWeather.description}`,
    layout: { mode: 'grid', columns: 2, gap: 12 },
    items,
  };
}

export function renderSubpanel(subpanelId: string): JSX.Element | null {
  if (subpanelId !== 'weather-forecast') return null;
  if (!cachedForecast || cachedForecast.length === 0) {
    return <div>No forecast data available</div>;
  }

  return (
    <div style={{ padding: '16px' }}>
      <h2 style={{ marginBottom: '16px' }}>7-Day Forecast</h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {cachedForecast.map((day, index) => (
          <div
            key={index}
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '12px',
              background: '#f5f5f5',
              borderRadius: '8px',
            }}
          >
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 'bold' }}>{day.date}</div>
              <div style={{ fontSize: '14px', color: '#666' }}>
                {getWeatherDescription(day.weatherCode)}
              </div>
            </div>
            <div style={{ fontSize: '18px', fontWeight: 'bold' }}>
              {day.temp_max}° / {day.temp_min}°
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// Default export for compatibility
export default function WeatherPlugin(): null {
  return null;
}
