# App Store Connect Answers for MazeDash

Use these as the exact default answers unless something in your business setup differs.

## App Privacy

Recommended answer:

- Data Collected

Reason:

- The app stores most gameplay data locally on device.
- The optional online Time Challenge leaderboard sends only:
  - a player-chosen display name
  - duration category
  - best maze count
- No login, ads, analytics, or cross-app tracking is implemented.

Important:

- In App Store Connect, this should be disclosed as limited app-functionality data for the optional online leaderboard.
- If you add analytics, ads, crash reporting, cloud save, or account features later, these answers must be updated again.

## Privacy Policy URL

You must host a public URL.

Suggested content:

- Use the text from `PrivacyPolicy.md`
- Publish it on your website, GitHub Pages, Notion public page, or another public HTTPS URL

## Content Rights Information

Choose this only if it is true:

- This app does not contain, show, or access third-party content.

If you used licensed music, licensed icons, stock assets, or external media, do not use the answer above unless your licenses are valid for App Store distribution.

## Age Rating

Recommended default for MazeDash:

- No violence
- No horror/fear themes
- No sexual content or nudity
- No gambling
- No alcohol, tobacco, or drug references
- Limited user-generated content only through the optional leaderboard display name
- No unrestricted web access

Expected result:

- Likely 4+

## Pricing

Recommended:

- Free

Only choose a paid tier if you explicitly want the app itself to be paid.

## Category

Recommended:

- Primary Category: Games
- Subcategory: Puzzle
- Optional secondary subcategory: Arcade

## Sign-In Information for Review

Recommended:

- Sign-in required: No

Do not enter a username or password because the app does not use accounts.

## Reviewer Notes

Use the text from `AppReviewNotes.txt`.

## Build Selection

This cannot be prepared as text alone.
You still need to:

1. archive the app in Xcode
2. upload the build
3. wait for processing in App Store Connect
4. select that processed build for the version
