# NEON_MAZE_STARS_UI_UX_HANDOFF_FOR_CLAUDE

## 1. Game Overview

### Product identity

- **Repo / codebase name:** `MazeDash`
- **Visible current front-end title:** `NEON MAZE STARS` in menu screenshots and QA artifacts
- **Naming status:** `Repo conflict` between internal project naming (`MazeDash`) and visible product naming (`NEON MAZE STARS`)
- **Engine / UI tech:** SpriteKit on iPhone, with SpriteKit scenes and scene-local SKNode-based UI
- **Platform target:** iPhone portrait is the clearly supported primary target
- **Visual identity in docs and code:** dark futuristic background, neon cyan/magenta/yellow/green accents, glossy arcade panels, compact HUD cards, glow-heavy arcade presentation

### Genre and core idea

- Neon arcade maze game, not a free-roam exploratory maze game
- Core loop:
  - read maze quickly
  - swipe one cardinal direction
  - commit to route decisions
  - collect all required orbs
  - reach exit as fast and cleanly as possible
- The game emphasizes:
  - speed
  - route reading
  - deterministic systems
  - mechanic learning
  - replay for better time and stars
  - cosmetic progression

### Target player and player goal

- Likely target player: mobile player who likes fast runs, repeatable arcade mastery, compact sessions, and visible progression
- Primary player goals:
  - clear story levels
  - improve star ratings and best times
  - learn new mechanics chapter by chapter
  - beat time challenge records
  - beat the daily bot for coins
  - unlock and equip cosmetics

### Main mode framing

- **Story Mode:** structured progression through 100 levels, chapter-backed internally
- **Time Challenge:** timed endless/chain run where player clears as many mazes as possible before timer ends
- **Daily Challenge:** one fixed daily maze, player chooses bot difficulty and can earn daily coin rewards
- **Shop:** cosmetic loadout / progression sink using gameplay-earned coins

## 2. Current Product State

### What works

- The game has a complete playable shell: start menu, level select, gameplay, time challenge, daily challenge, shop, settings, result overlays, leaderboard overlays
- Story progression, stars, best times, coins, cosmetics, achievements, challenge records, and daily rewards all exist in code
- The UI already has a recognizable neon arcade identity instead of default iOS styling
- Level content appears substantial and structured:
  - 100 story levels
  - 10 internal chapters
  - multiple mechanics and later combinations
- Gameplay HUD is feature-rich:
  - timer
  - star display
  - pause
  - mode/status labels
  - combo and flow systems
  - minimap / overview support
- A tutorial system exists for:
  - first-time start/basic play instructions
  - newly seen mechanics
- Optional leaderboard flow exists for time challenge and story levels

### What is unfinished or recently changed

- The repo is mid-iteration and visibly carries redesign churn across menu, level select, overlays, and supporting docs
- The current repository includes multiple shell/visual experiments and rollback traces:
  - App Store screenshots
  - `.qa-start-*` files
  - scene-local layout variants reflected in code structure
- `StoryChapterCardNode.swift` exists, but current docs and current visible level select direction favor a flat level grid, so chapter-card usage is `Uncertain`
- The tutorial system is present in current code, but external screenshots do not verify all tutorial states

### What feels weak or inconsistent

- The shell UI often feels like accumulated cards/overlays rather than one tightly unified premium game surface
- Start menu hierarchy has been unstable over multiple passes and is sensitive to clutter
- Level Select progression language is still a recurring weak point:
  - current
  - ready
  - cleared
  - locked
  - stars
  - best time
  all compete inside small cards
- Overlay density varies heavily between overlay types
- Shop, daily, challenge, story result, and gameplay HUD all belong to the same product language, but they do not always feel governed by the same design discipline

### What is fragile to touch

- `MazeDash/Shared/GameScene.swift`
  - very large
  - mixes gameplay, HUD, overlays, tutorial logic, minimap logic, leaderboard logic, pause/result flow, and touch handling
- `MazeDash/Shared/StartScene.swift`
  - contains `StartScene` plus multiple shell scenes and several overlay/component classes in one file
- Layout is heavily hardcoded with manual positions, sizing, safe-area math, and scene-specific touch handling
- Several overlays are scene-local and not centralized in a clean design system

### What was recently rolled back or revised after negative feedback

- A bolder “arcade neon” redesign direction for start, level select, and reward overlays was strongly rejected by the user
- The user then requested a rollback toward a calmer, simpler structure “closer to before”
- The menu hero treatment, heavier overlay copy, stronger star styling, and more decorative passes were specifically pushed back against

## 3. Complete Screen / Scene Inventory

### StartScene

- **File:** `MazeDash/Shared/StartScene.swift`
- **Purpose:** main entry shell for the game
- **Entry path:** initial scene from `GameViewController`
- **Visible elements:**
  - animated neon background, grid, glow layers, particles
  - title and subtitle
  - main action stack
  - utility row
  - compact progression messaging on `Continue`
- **Current primary actions:**
  - `CONTINUE`
  - `TIME CHALLENGE`
  - `LEVELS`
- **Current utility actions:**
  - `DAILY`
  - `SETTINGS`
  - `SHOP`
- **Navigation destinations:**
  - Continue -> `GameScene` story
  - Time Challenge -> `ChallengeSelectScene`
  - Levels -> `LevelSelectScene`
  - Daily -> `DailyChallengeScene` or daily prompt flow
  - Settings -> settings modal
  - Shop -> `ShopScene`
- **Visual style:** neon buttons, glossy panels, animated backdrop, monospace-heavy title treatment
- **Current UX problems:**
  - this screen has historically become cluttered quickly when more hierarchy ideas are added
  - too many actions can become equal-priority if spacing and emphasis drift
  - utility row placement and emphasis are highly sensitive
- **Redesign opportunities:**
  - protect simple scan order
  - keep one obvious first action
  - keep utility visible but clearly secondary
  - reduce “experimental leftovers” feel

### LevelSelectScene

- **File:** `MazeDash/Shared/LevelSelectScene.swift`
- **Purpose:** direct story-level browsing
- **Entry path:** Start menu `LEVELS`
- **Visible elements:**
  - `TopBarNode` with `BACK`
  - summary strip / stat chips
  - bot toggle
  - two-column scrollable `LevelCardNode` grid
- **Interactions:** tap level card to enter story level, tap back, toggle bot
- **Navigation destinations:** selected level -> `GameScene`; back -> `StartScene`
- **Visual style:** flat direct grid, glossy level cards, muted dark background, neon outlines
- **Current UX problems:**
  - state clarity remains a known pain point
  - star row, lock state, current state, and best-time band are fighting for the same small card
  - current screenshots show locked text sitting in the same central band as stars, which reads poorly
- **Redesign opportunities:**
  - make next playable level unmistakable
  - keep grid structure
  - make locked state structurally distinct from star band
  - reduce monotony without making cards busy

### GameScene gameplay HUD and sub-states

- **File:** `MazeDash/Shared/GameScene.swift`
- **Purpose:** main gameplay scene for story, time challenge, and daily challenge
- **Entry path:** story start/continue, level select, time challenge, daily
- **Visible HUD elements depending on mode:**
  - timer panel
  - top HUD bar
  - mode labels
  - story star display
  - coin chip in daily/challenge contexts
  - pause button
  - combo/flow feedback
  - mechanic badges
  - minimap
  - swipe hint in some contexts
- **Sub-states / overlays inside gameplay:**
  - pause
  - story result
  - time challenge result
  - daily result
  - reward unlock
  - story leaderboard
  - leaderboard name prompt
  - tutorial overlay
  - overview/minimap overlay
- **Current UX problems:**
  - very feature-dense
  - overlay handling is powerful but architecturally tangled
  - premium feel depends on restraint; this scene can easily become over-instrumented
- **Redesign opportunities:**
  - unify shell/gameplay panel language
  - reduce style drift between HUD, modals, and shell screens
  - standardize spacing, button stacks, and card structures

### ChallengeSelectScene

- **File:** `MazeDash/Shared/StartScene.swift`
- **Purpose:** choose time challenge duration
- **Entry path:** Start -> `TIME CHALLENGE`
- **Visible elements:**
  - top bar
  - subtitle: currently `Pick a clock. Clear fast.`
  - duration cards for 1, 2, 3 minutes
  - best score per duration
  - footer copy
- **Interactions:** tap duration card, back button
- **Current UX problems:**
  - thread feedback explicitly called out too much text on challenge surfaces
  - supporting copy can become heavier than the choice itself
- **Redesign opportunities:**
  - keep reward/value first
  - keep copy tight
  - reduce slogan layers

### DailyChallengeScene

- **File:** `MazeDash/Shared/StartScene.swift`
- **Purpose:** choose daily difficulty and see daily context
- **Entry path:** Start -> `DAILY` or daily prompt -> play
- **Visible elements:**
  - top bar
  - subtitle
  - day/date label
  - best time label
  - easy and hard bot cards with reward amounts
  - footer explanation
- **Interactions:** tap difficulty card, back button
- **Current UX problems:**
  - screenshots show explanatory text competing with reward and difficulty
  - copy density can outgrow the actual decision
- **Redesign opportunities:**
  - reward amount and difficulty should scan first
  - explanatory copy should become supporting, not primary

### ShopScene

- **File:** `MazeDash/Shared/StartScene.swift`
- **Purpose:** buy/equip cosmetics with gameplay-earned coins
- **Entry path:** Start -> `SHOP`
- **Visible elements:**
  - top bar
  - subtitle about gameplay coins / no real-money purchases
  - coin card and coin total
  - tab buttons
  - scrollable item grid
  - shop info/status text
- **Interactions:** switch tabs, purchase/equip item, back button
- **Current UX problems:**
  - another shell surface with its own local layout logic and copy style
  - shop tab/content model does not yet feel fully integrated into a unified shell system
- **Redesign opportunities:**
  - unify panel scale and hierarchy with other shell scenes
  - reduce text redundancy

### Pause overlay

- **File:** `MazeDash/Shared/OverlayNodes.swift`
- **Purpose:** pause current run
- **Visible elements:** title, subtitle, `RESUME`, `RESTART`, `MENU`
- **Entry path:** pause button in gameplay HUD
- **Current UX issues:** functionally clear; main opportunity is consistency with other overlays

### Story result overlay

- **File:** `MazeDash/Shared/ResultOverlayNode.swift`
- **Purpose:** story completion result
- **Visible elements:**
  - headline
  - star row
  - time caption/value
  - optional leaderboard button
  - requirement rows for star thresholds
  - `NEXT`, `RETRY`, `MENU`
- **Current UX issues:**
  - visually richer than other overlays
  - can feel denser than the simpler challenge result flow
- **Redesign opportunities:**
  - preserve earned feeling
  - simplify without making it flat

### Challenge result overlay

- **File:** `MazeDash/Shared/OverlayNodes.swift`
- **Purpose:** end state for time challenge
- **Visible elements:** `TIME UP`, completed mazes count, record/best line, `RUN AGAIN`, `MENU`
- **Current UX issues:** user complained about too much text on some overlays; this one is already relatively compact and should stay that way

### Daily result overlay

- **File:** `MazeDash/Shared/ResultOverlayNode.swift`
- **Purpose:** end state for daily clear
- **Visible elements:**
  - `DAILY CLEARED`
  - difficulty chip
  - time
  - reward card
  - best/status line
  - `RUN AGAIN`, `MENU`
- **Current UX issues:** more structured than challenge result, but can still drift toward too much carding/copy

### Reward unlock overlay

- **File:** `MazeDash/Shared/OverlayNodes.swift`
- **Purpose:** show story milestone cosmetic unlock
- **Visible elements:** reward title, unlocked item name, milestone line, visual preview, `CONTINUE`
- **Current UX issues:** user explicitly rejected heavier reward-overlay embellishment and too much text

### Mechanic / start tutorial overlay

- **File:** `MazeDash/Shared/OverlayNodes.swift`
- **Purpose:** onboarding and first-time mechanic introduction
- **Content types:**
  - basic play tutorial
  - one-time mechanic tutorial
- **Current behavior from code:**
  - start/basic tutorial appears on story level 1 if unseen
  - mechanic tutorial appears on first encounter of a mechanic if unseen
  - challenge mode still uses a simpler swipe hint path
- **Visible elements:** section label, title, demo frame, wrapped copy, continue button
- **Current UX issues:** copy is necessary here, but this is still another modal system with custom presentation rules

### Story leaderboard overlay

- **File:** `MazeDash/Shared/OverlayNodes.swift`
- **Purpose:** show per-level leaderboard
- **Visible elements:** title, level name, player label, loading/status text, up to 10 rows, close button

### Leaderboard name prompt

- **File:** `MazeDash/Shared/OverlayNodes.swift`
- **Purpose:** ask for short leaderboard player name
- **Visible elements:** title, detail text, validation label, input plate, `CANCEL`, `SAVE`

### Settings overlay

- **File:** `MazeDash/Shared/StartScene.swift`
- **Purpose:** adjust vibration, volume, sound FX, music
- **Visible elements:** title, subtitle, toggles, volume slider, value label, `DONE`
- **Entry path:** Start -> `SETTINGS`
- **Current UX issues:** solid functionally, but still a scene-local overlay with its own copy voice

### Daily prompt overlay

- **File:** `MazeDash/Shared/StartScene.swift`
- **Purpose:** lightweight nudge into daily challenge
- **Visible elements:** title, short body, reward line, `PLAY NOW`, `LATER`
- **Entry path:** optional launch prompt

### Overview / minimap overlay state

- **File:** `MazeDash/Shared/GameScene.swift`
- **Purpose:** full overview map with time penalty
- **Visible elements:** enlarged minimap and close button
- **Current UX issues:** functionally useful, but another unique modal branch inside `GameScene`

## 4. Reusable UI Component Inventory

### Buttons

- **Primary primitive:** `ArcadeButtonNode` in `MazeDash/Shared/ButtonNode.swift`
- Used for:
  - start menu actions
  - top-bar back buttons
  - overlay buttons
  - settings toggles
  - shop actions
- States:
  - normal
  - pressed
  - disabled
  - visual emphasis styles (`none`, `quiet`, `primary`)
- Strengths:
  - reusable base exists
  - supports accent color and card style variation
- Problems:
  - behavior is centralized, but layout/content treatment is still scene-specific
  - icon placement and label alignment vary by screen
- Design-system potential: **high**

### Cards and panels

- Common card textures come from `TextureFactory` plus `CardStyle`, but card composition is often local
- Repeated families:
  - level cards
  - result cards
  - daily bot cards
  - challenge duration cards
  - shop item cards
  - settings card
  - prompt cards
  - HUD panels
- Problems:
  - same “glass arcade card” idea, but not one disciplined component family
  - inconsistent density, accent placement, and copy count
- Design-system potential: **very high**

### Labels and counters

- Repeated label roles:
  - titles
  - subtitles
  - best-time counters
  - coin totals
  - chapter/sector labels
  - bot labels
  - timer digits
  - stars/cleared/next chips
- Typography family is fairly unified through `ArcadeFont`, but hierarchy discipline is inconsistent by scene

### Progress and reward elements

- Stars:
  - HUD stars
  - level-card stars
  - result-overlay stars
  - requirement rows
- Reward elements:
  - story unlock overlay
  - daily payout card
  - achievement/progression supporting labels
- Problems:
  - star treatment is one of the clearest consistency pain points
  - reward emphasis differs substantially between surfaces

### Navigation components

- `TopBarNode`
- start menu action stack
- overlay dismissal buttons
- manual back navigation to previous scene
- Problems:
  - shell navigation exists, but scene-local assembly causes drift

## 5. Visual Design Audit

### Colors

- Strong current palette:
  - cyan
  - magenta
  - yellow
  - green
  - dark blue/black panel base
- Good base identity is already present
- Main risk is not wrong colors, but inconsistent intensity and accent assignment from screen to screen

### Typography

- Uses system-derived monospaced/heavy fonts via `ArcadeFont`
- This gives the game a technical arcade voice
- Hierarchy problems come more from scale/placement/copy density than from font choice itself

### Spacing and layout

- The codebase relies on manual scene-specific coordinate systems
- This allows strong custom layouts, but it also creates:
  - fragile spacing
  - inconsistent vertical rhythm
  - screens that feel hand-tuned separately rather than part of one system

### Glow, shadows, and borders

- Glow is core to the game identity
- The best-looking states use glow as controlled accent
- Rejected states happened when glow became:
  - too constant
  - too large
  - too decorative
  - stacked with too much extra copy and paneling

### Icons

- UI uses a mixture of:
  - text-first buttons
  - some scene-local icon nodes
  - gameplay icons and asset-backed symbols
- Icon system does not yet read as fully standardized across shell, HUD, and shop

### Motion

- Background motion, button pulses, overlay entrances, combo feedback, and tutorial demos all exist
- Motion capability is strong
- User preference from thread history is clear:
  - targeted motion is welcome
  - constant noisy animation is not

### Visual hierarchy

- Strongest recurring issue in shell screens is equalized importance
- Screens can quickly look like a set of similarly weighted widgets
- This is especially visible in:
  - start menu with many direct actions
  - level cards with too many signals inside one footprint
  - overlay variants with inconsistent density

### Readability and consistency

- The game is often readable in isolation
- The bigger problem is product-level consistency:
  - a premium cohesive game should feel authored by one system
  - this codebase often feels like multiple good widgets added over time

## 6. UX Audit

### First-time experience

- Current code supports:
  - first basic tutorial
  - one-time mechanic tutorial reveals
- This is a meaningful improvement to onboarding
- `Uncertain`: whether the first-time shell/menu path fully prepares the player emotionally before first run; available evidence is mostly code and screenshots, not live device testing

### Main menu flow

- Main friction is not missing functionality
- Main friction is scan order and competition between visible actions
- The user repeatedly preferred simpler, calmer hierarchy over larger “hero” redesigns

### Level-select flow

- The core navigation model is sound:
  - direct grid
  - fast tap-to-play
- The weak point is comprehension speed
- The user should identify next playable level instantly; current state has improved logic in code, but past screenshots and feedback show this remains fragile

### Gameplay onboarding and mechanic introduction

- Start/basic tutorial plus first-mechanic tutorial is the right general UX direction
- This should be preserved unless testing shows serious friction

### Pause / result / reward pacing

- Flow exists for all major outcomes
- Emotional pacing is uneven:
  - story result is relatively elaborate
  - challenge result is compact
  - reward/daily/result moods are not yet fully harmonized

### Shop and progression comprehension

- Systems exist and are meaningful
- Risk is comprehension burden:
  - multiple cosmetic types
  - reward unlocks
  - coin economy
  - daily rewards
  - achievements
  all surface in separate places with different UI density

### Settings discoverability and density

- Settings are directly accessible from StartScene
- As a modal, this is convenient
- It should stay compact and low-friction

### Daily / challenge clarity

- Daily and challenge screens are structurally understandable
- The recurring UX issue is too much supporting copy relative to the decision

### Emotional feedback

- The game has many systems for excitement:
  - combo
  - stars
  - unlocks
  - new bests
  - daily payouts
- But thread history shows the user does not want louder emotion through more clutter
- Emotional payoff should come from sequence, contrast, timing, and restraint

## 7. Game Content Relevant to UI

### Story structure

- 100 levels
- 10 internal chapters of 10 levels each
- Chapters have names and mechanic identities
- Current visible browsing remains direct flat level grid despite internal chapter structure

### Mechanics

- Present in code:
  - one-way
  - breakable walls
  - switch blocks
  - keys/doors
  - teleporters
  - timing gates
  - fog
  - moving blocks
  - chaser enemy
- UI implication:
  - mechanic identity matters for onboarding, chapter framing, badges, and tutorial presentation

### Scoring and progression

- Story tracks:
  - best time
  - stars per level
  - next playable level
  - completed level count
  - total stars
- Challenge tracks:
  - best cleared mazes per duration
- Daily tracks:
  - best time per day
  - claimed reward state per difficulty

### Rewards and unlocks

- Coins from gameplay and daily challenge
- Story milestone cosmetic unlocks at levels:
  - 10, 20, 30, 40, 50, 60, 70, 80, 90, 100
- Cosmetic categories in code:
  - player colors
  - player patterns
  - trails
  - win animations
  - teleporter skins exist in data, but are not currently exposed as a visible shop tab in current `ShopScene`

### Achievements

- Present in `AchievementStore`
- Examples include:
  - first escape
  - first 3-star
  - five clears
  - flow collector
  - theme shift
  - elite runner

### Leaderboards

- Optional online leaderboard flow exists
- Story level leaderboard and time challenge leaderboard both matter to UI
- Name prompt is intentionally lightweight and account-free

### Tutorial system

- First-run/start tutorial and first-seen mechanic tutorial now matter to UX and should be accounted for in any redesign

## 8. Frontend / SpriteKit Architecture

### Main scenes

- `StartScene`
- `LevelSelectScene`
- `GameScene`
- `ChallengeSelectScene`
- `DailyChallengeScene`
- `ShopScene`

### Scene relationships

- `GameViewController` decides initial scene and supports screenshot launch targets
- StartScene is the main hub
- Challenge, Daily, and Shop are separate SpriteKit scenes, but they live in `StartScene.swift`

### Shell vs gameplay separation

- There is conceptual separation between shell scenes and gameplay
- There is not a strong architectural separation between shared shell UI patterns and scene-specific implementations

### Reusable UI primitives

- `ArcadeButtonNode`
- `TopBarNode`
- `LevelCardNode`
- `MiniMapNode`
- `ScrollContainerNode`
- shared style enums in `UIStyle.swift`

### Duplicated or scene-local UI

- Many cards and overlays are still local to one scene file
- `StartScene.swift` is a major concentration point for shell UI sprawl
- `GameScene.swift` is a major concentration point for gameplay UI sprawl

### Hardcoded layout/style hotspots

- Manual per-scene layout math is widespread
- Safe-area handling is repeated per scene/overlay
- Overlay button placement and card sizing are repeated in multiple classes

### Risk zones for redesign

- `GameScene.swift`: large mixed-responsibility file
- `StartScene.swift`: multiple scenes + overlays + custom controls in one file
- modal handling in gameplay
- state-dependent UI branches in gameplay result flow
- level-card layout due to dense state language

## 9. Prior User Feedback, Complaints, and Rejected Directions

### Persistent preferences from this thread

- User wants the UI to feel more premium, more polished, and more “neon arcade”
- User does **not** want that achieved through clutter
- User repeatedly preferred simpler, calmer structure when heavier redesigns were shown
- User wants clearer hierarchy, not more surface area
- User wants subtle glow/light effects and animation accents, not constant noisy motion

### Explicit complaints from this thread

- User called some redesign passes:
  - overloaded
  - ugly
  - terrible
  - too much text
  - worse than before
- User explicitly disliked:
  - too much text in overlays
  - too much text in time challenge surfaces
  - bad level-select star treatment
  - overworked level-select redesigns
  - monotone-feeling results that were still somehow busy

### Rejected experiments

- Heavy start-screen hero treatment
- Overdesigned reward/result overlays
- Aggressive star styling on level cards
- Bolder “arcade neon” pass that increased density instead of quality

### Requests that were later contradicted or softened

- Utility placement ideas changed over time
- At one point, the user asked for utility actions like shop/settings/daily to move or change emphasis
- Later feedback asked to restore or roll back toward the older state when the result felt worse
- Treat these as unstable preferences compared to the stable preference for **clarity without clutter**

### Important historical takeaway

- The user is highly sensitive to UI that feels:
  - overdesigned
  - overexplained
  - too decorative
  - too many equally loud parts at once

## 10. Redesign Briefing for Claude

Claude, the highest-impact redesign targets are:

- **Start menu hierarchy**
  - make first action obvious
  - keep all current destinations
  - avoid adding hero complexity unless it is extremely restrained
- **Level Select clarity**
  - preserve the direct two-column grid
  - make `next`, `ready`, `cleared`, and `locked` unmistakable
  - fix stars as communication, not decoration
- **Overlay density**
  - keep reward/result screens emotionally satisfying
  - cut copy and decorative layering before adding new visual ideas
- **Design-system cohesion**
  - unify card language, spacing rhythm, accent logic, and button hierarchy across shell, gameplay HUD, shop, and overlays

### Preserve

- Neon arcade identity
- Current feature set and content systems
- SpriteKit reality
- Direct level grid browsing
- Existing progression systems
- Current tutorial intent

### Change carefully

- StartScene layout
- Level-card composition
- Overlay sequencing and copy density
- Cross-screen component consistency

### Do not touch casually

- Gameplay rules
- Save/progression schema
- Navigation model
- Existing content inventory

### Implementation risks

- Scene-local UI sprawl
- Hardcoded layout coupling
- Inconsistent docs vs code vs screenshot state
- User history of rejecting redesigns that feel louder rather than better

### Recommended redesign direction

- Conservative, clarity-first refinement
- Premium through discipline, not through more effects
- Stronger hierarchy and cleaner pacing
- More consistent product language across all surfaces

## 11. Evidence / References

### Repo docs used

- `MAZEDASH_FULL_GAME_DESCRIPTION.txt`
- `MAZEDASH_SPIELDOKU_DETAILLIERT.txt`
- `AppStoreSubmission/AppReviewNotes.txt`
- `Versions/1.1/README.md`

### Key UI / scene files

- `MazeDash/Shared/StartScene.swift`
- `MazeDash/Shared/LevelSelectScene.swift`
- `MazeDash/Shared/GameScene.swift`
- `MazeDash/Shared/OverlayNodes.swift`
- `MazeDash/Shared/ResultOverlayNode.swift`
- `MazeDash/Shared/LevelCardNode.swift`
- `MazeDash/Shared/ButtonNode.swift`
- `MazeDash/Shared/TopBarNode.swift`
- `MazeDash/Shared/UIStyle.swift`
- `MazeDash/Shared/ScrollContainerNode.swift`
- `MazeDash/Shared/MiniMapNode.swift`
- `MazeDash/Shared/NeonData.swift`
- `MazeDash/iOS/GameViewController 09.03.23.swift`

### Visual artifacts used

- `AppStoreScreenshots/menu.png`
- `AppStoreScreenshots/level-select.png`
- `AppStoreScreenshots/daily-challenge.png`
- `AppStoreScreenshots/level-types/*.png`
- `.qa-start.png`
- `.qa-start-2.png`
- `.qa-start-redesign*.png`
- `.qa-start-layout-*.png`
- `.codex-startscreen.png`

### Files Claude should inspect first

- `MazeDash/Shared/StartScene.swift`
- `MazeDash/Shared/LevelSelectScene.swift`
- `MazeDash/Shared/LevelCardNode.swift`
- `MazeDash/Shared/GameScene.swift`
- `MazeDash/Shared/OverlayNodes.swift`
- `MazeDash/Shared/ResultOverlayNode.swift`
- `MazeDash/Shared/NeonData.swift`

## 12. Uncertainties and Repo Conflicts

- **Naming conflict:** repo/docs use `MazeDash`, but current visible menu title uses `NEON MAZE STARS`
- **Ads conflict:** `AppStoreSubmission/AppReviewNotes.txt` says there are no ads, but current code still contains `AdService` and ad-related logic, including rewarded coins and interstitial registration
- **Screenshot freshness:** some App Store screenshots and QA screenshots likely reflect earlier UI states rather than the exact current code state
- **Chapter UI status:** docs say content is chapter-based but visible level select is intentionally back on a flat grid; `StoryChapterCardNode.swift` exists, so chapter-card direction is present in repo but not confirmed as active in current player flow
- **Thread-history vs repo-state drift:** previous redesign attempts, rollbacks, and local edits may not all be fully represented by the visible screenshots
- **Behavior inferred from code:** some tutorial, overlay, and leaderboard behaviors are documented from code inspection rather than directly verified in a running build on device

