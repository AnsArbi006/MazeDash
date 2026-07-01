# MazeDash Leaderboard Worker

Free production-friendly path for the MazeDash leaderboard:
- Cloudflare Worker
- Cloudflare D1
- public `workers.dev` URL without a custom domain

The iOS client expects:
- `GET /leaderboard?duration=60`
- `POST /leaderboard`

## Behavior

- The worker stores only the best score per `player_name + duration`.
- Worse or equal scores are ignored server-side.
- `GET` returns the top 10, sorted by:
  - `score DESC`
  - `achieved_at ASC`
  - `id ASC`
- Basic rate limits are enabled:
  - `GET`: 60 Requests pro 30 Sekunden pro IP
  - `POST`: 20 Requests pro 10 Minuten pro IP
- Player names are validated:
  - 2 bis 16 Zeichen
  - simple letters/digits/spaces/`_.-` only
  - basic blocked-word list for obvious abuse

## Setup

1. Create a Cloudflare account.
2. Log in in this folder:
   ```bash
   npm install
   npx wrangler login
   ```
3. Create a D1 database:
   ```bash
   npx wrangler d1 create mazedash_leaderboard
   ```
4. Paste the returned `database_id` into `wrangler.toml`.
5. Apply the schema:
   ```bash
   npm run db:apply
   ```
6. Deploy:
   ```bash
   npm run deploy
   ```

After deploy you will get a URL like:
- `https://mazedash-leaderboard.<dein-subdomain>.workers.dev`

Set that URL in `MazeDash/Shared/LeaderboardService.swift`.

## Testing

```bash
curl "https://mazedash-leaderboard.<dein-subdomain>.workers.dev/leaderboard?duration=60"

curl -X POST "https://mazedash-leaderboard.<dein-subdomain>.workers.dev/leaderboard" \
  -H "Content-Type: application/json" \
  -d '{"name":"Alex","duration":60,"score":8}'
```

## Hardening ideas

- stronger abuse / spam protection
- better name moderation
- signature- or session-based anti-cheat
- monitoring / logging

For a lightweight first release, this worker matches the current client contract.
