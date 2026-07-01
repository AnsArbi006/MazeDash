# MazeDash

MazeDash is a SpriteKit arcade maze game for iPhone, with additional macOS and tvOS targets in the Xcode project.

This repository contains:

- the iOS game client
- shared gameplay and UI code
- assets, audio, and SpriteKit scenes
- an optional Cloudflare Worker backend for leaderboards
- product, QA, and UI/UX handoff documentation

## Current repo status

This is an actively developed project, not a minimal open-source sample. The working tree includes game code, UI/UX iterations, release notes, App Store support files, and documentation created during development.

Some production-specific values have been intentionally removed or replaced before publishing this repository:

- AdMob IDs in `MazeDash/iOS/Info.plist` use Google sample values
- the leaderboard base URL in `MazeDash/Shared/LeaderboardService.swift` is a placeholder
- the Cloudflare D1 database ID in `backend/leaderboard-worker/wrangler.toml` is a placeholder
- `app-ads.txt` uses a placeholder publisher ID

You must replace those values with your own before using ads or the hosted leaderboard in production.

## Project structure

```text
MazeDash/
  Shared/                 Shared SpriteKit gameplay, UI, data, and assets
  iOS/                    iOS app delegate, storyboard, plist, controller
MazeDash macOS/           macOS target resources
MazeDash tvOS/            tvOS target resources
backend/leaderboard-worker/
                          Optional Cloudflare Worker leaderboard backend
AppStoreSubmission/       App Store support docs
AppStoreScreenshots/      Marketing / store screenshots
Versions/                 Version notes and planning
Tools/                    Local helper scripts
```

## Main gameplay surfaces

- `StartScene.swift`: main menu and shell entry point
- `LevelSelectScene.swift`: story progression and chapter browsing
- `GameScene.swift`: core gameplay, HUD, overlays, and result flow
- `OverlayNodes.swift`: modal overlays, reward prompts, tutorial surfaces
- `ResultOverlayNode.swift`: result and payoff overlays
- `LevelCardNode.swift`: reusable story level cards
- `TopBarNode.swift`, `ButtonNode.swift`, `UIStyle.swift`: reusable UI primitives

## Requirements

- macOS with Xcode
- iOS SDK matching the Xcode version in use
- for the optional leaderboard worker:
  - Node.js
  - npm
  - Cloudflare Wrangler

## Run locally

1. Open `MazeDash.xcodeproj` in Xcode.
2. Select the `MazeDash iOS` scheme.
3. Build and run on a simulator or device.

The game should run without any private credentials. Ads will not operate with the placeholder/sample configuration, and leaderboard submission/fetching will stay disabled until you configure your own backend URL.

## Configure ads for your own release

Replace the sample values in:

- `MazeDash/iOS/Info.plist`

Expected keys:

- `GADApplicationIdentifier`
- `MazeDashRewardedAdUnitID`
- `MazeDashStoryInterstitialAdUnitID`
- `MazeDashTimeChallengeInterstitialAdUnitID`

The code already treats Google sample IDs as non-production values.

## Configure the leaderboard backend

1. Go to `backend/leaderboard-worker/`
2. Install dependencies:

```bash
npm install
```

3. Log in to Cloudflare:

```bash
npx wrangler login
```

4. Create a D1 database:

```bash
npx wrangler d1 create mazedash_leaderboard
```

5. Put the returned database ID into:

- `backend/leaderboard-worker/wrangler.toml`

6. Apply the schema:

```bash
npm run db:apply
```

7. Deploy the worker:

```bash
npm run deploy
```

8. Set your deployed worker URL in:

- `MazeDash/Shared/LeaderboardService.swift`

The client expects the `/leaderboard` endpoint used by the included worker.

## Notes on privacy and publishing

This repo has been prepared to avoid publishing obvious production secrets or monetization identifiers by default, but you should still review before making the repository public.

Recommended checks before every public push:

- inspect `git diff --staged`
- make sure no local account credentials or API keys were added
- keep build artifacts, archives, and local QA captures out of Git
- keep backend credentials in Cloudflare secrets or local-only config, never hardcoded

## Helpful docs in this repo

- `NEON_MAZE_STARS_UI_UX_HANDOFF_FOR_CLAUDE.md`
- `VERSIONING.md`
- `Versions/1.1/README.md`
- `backend/leaderboard-worker/README.md`

## License

No license file is included right now. That means others do not automatically have permission to reuse, modify, or redistribute this code outside normal GitHub viewing/forking mechanics. Add a license explicitly if you want open-source reuse.
