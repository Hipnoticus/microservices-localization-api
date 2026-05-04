# Localization API

International country, state, and city data service for the Hipnoticus platform.

## Technology Stack
- **Language**: Ruby 3.3
- **Framework**: Sinatra 4.0
- **Database**: MongoDB (via Mongoid 9.0)
- **Server**: Puma 6.4
- **Data Sources**: REST Countries API, IBGE (Brazil), CountriesNow

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/countries` | List all countries (sorted by name) |
| GET | `/countries/:code` | Get country details by ISO code |
| GET | `/countries/:code/states` | List states/provinces for a country |
| GET | `/states/:country/:state/cities` | List cities for a state |
| GET | `/health` | Health check with data counts |
| POST | `/sync` | Trigger manual data sync |

## Data Sync
- Automatic sync every 24 hours via Rufus Scheduler
- Countries from REST Countries API (250+ countries)
- Brazilian states/cities from IBGE API (27 states, 5,570+ cities)
- International states from CountriesNow API

## Development
```bash
bundle install
RACK_ENV=development bundle exec puma -p 4001
```

## Testing
```bash
bundle exec rspec
```

## Docker
```bash
docker build -t localization-api .
docker run -p 4001:4001 -e MONGODB_URI=mongodb://... localization-api
```

## Architecture
- **DDD**: Models (Country, State, City) represent domain entities
- **SOLID**: Single responsibility per class, dependency injection via Mongoid
- **Clean**: Controller → Service → Model separation
