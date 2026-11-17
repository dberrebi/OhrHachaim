# אור החיים

An offline iPhone and iPad app for reading **Ohr HaChaim** (אור החיים), Rabbi Chaim ibn Attar's commentary on the Torah, arranged by weekly parasha.

The commentary itself is Hebrew only. English is available for the interface: menus, settings, and help. There is no translation of the commentary.

The app does not use the network at runtime, and it has no analytics.

## Open and run

Requirements: Xcode 15 or later to build locally, and a deployment target of iOS 17. To build from source, clone [dberrebi/OhrHachaim](https://github.com/dberrebi/OhrHachaim) and open `OhrHaChaim/OhrHaChaim.xcodeproj`. Apple has required Xcode 26 for App Store uploads since 28 April 2026. This repository does not upload a build. GitHub Actions uses the `macos-26` runner and selects Xcode 26, which includes the iOS 26 SDK, while the deployment target stays iOS 17.

No Apple Developer account is configured. Signing is turned off in the target so the project can compile without a team:

```bash
xcodebuild \
  -project OhrHaChaim/OhrHaChaim.xcodeproj \
  -scheme OhrHaChaim \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

In Xcode, choose an iPhone or iPad simulator and run. Signing stays off for that, so no Apple ID is required.

## Install on your own iPhone for free

This uses a free Apple ID. It does not use the paid Apple Developer Program.

Apple’s account help describes the Personal Team that Xcode creates when you sign in with an Apple ID that has no paid membership: up to 3 apps installed on a device, up to 10 App IDs, and up to 3 devices. Those registrations and the provisioning profile expire after 7 days. When the profile expires the icon can remain, but the app will not open until you rebuild and install it from Xcode again. Source: [About your developer account](https://developer.apple.com/help/account/basics/about-your-developer-account/).

1. Install Xcode from the Mac App Store.
2. In Xcode, open Settings → Accounts and sign in with your Apple ID. The team is shown as a Personal Team.
3. Open `OhrHaChaim/OhrHaChaim.xcodeproj`. Select the OhrHaChaim app target, then Signing & Capabilities. Turn on Automatically manage signing and choose your Personal Team. If the bundle identifier is already registered to someone else, change it to a unique one, such as `app.ohrhachaim.yourname`.
4. The project file leaves code signing off so CI can build without a team. For this device install, set Code Signing Allowed to Yes on that target if Xcode still refuses to sign.
5. Connect the iPhone (or pair it from Xcode’s device list). On the phone, turn on Developer Mode under Settings → Privacy & Security, which iOS asks for the first time a development app is installed, and restart if prompted.
6. Choose your iPhone as the run destination and press Run. If iOS says the developer is not trusted, open Settings → General → VPN & Device Management and trust your Apple ID.

This is the official free way to put the app on a phone you control. A Personal Team cannot publish to the App Store or send the build to other people. The first screen is a full-width list: resume, history, this week's parasha, the five books, settings, help, and about.

GitHub Actions (`.github/workflows/ios.yml`) runs on a GitHub-hosted `macos-26` runner. That image's default toolchain is Xcode 26, and the workflow also selects `/Applications/Xcode_26*.app` so the build does not follow a newer Xcode if one becomes the default. Code signing stays off. Tests run on an iPhone 17 Pro Max simulator (6.9-inch, 1320×2868), including a check that tapping בראשית opens its parasha list and a search test. The same screens are then captured on an iPad Pro 13-inch simulator (2064×2752).

Two artifacts are uploaded:

- `simulator-screenshots` — home and a book's parasha list, in light and dark appearance, on both devices, so the light status icons on the dark bar and the full-width dividers can be checked under the iOS 26 SDK.
- `app-store-screenshots` — Hebrew UI at the 6.9-inch and 13-inch sizes: home, the weekly reading, a parasha list, the reader, search, and settings. Alpha is removed so the files match the App Store's opaque PNG rule.

A pull request from this repository is covered by the branch push, so the workflow does not start a second macOS run for it.

The in-app language changes the interface strings, the layout direction, and date formatting immediately. The name on the device Home Screen, some system sheets, and the VoiceOver language stay on the device language.

## Screens

- **Home.** Centred rows and a dark bar with the app mark, the title, share, and favourites.
- **Book.** The parshiyot of that book. Genesis also lists the author's introduction.
- **Search.** Offline full-text search of the Hebrew commentary. A query without nikud or cantillation matches the pointed text. A result shows the parasha, the verse, and a snippet, and opens that place.
- **Reading.** Ohr HaChaim for one parasha, or for two when they are read together, grouped by chapter and verse. Phrases marked in the edition (the dibbur hamatchil, and other highlighted phrases) are emphasised. A star saves a passage. A long press copies or shares the Hebrew text.
- **This week.** The coming Shabbat reading, using the Israel or Diaspora table from Settings. Combined parshiyot open together. וזאת הברכה is scheduled on Simchat Torah.
- **Resume and history.** The last passage, and recent passages.
- **Settings.** Interface language (Hebrew or English, String Catalog only), Israel or Diaspora, nikud, type size (the in-app slider and the system text size), light, dark, or system appearance, and a link to the privacy policy.
- **About.** The author, the sources, the licences, and the same privacy-policy link.

Genesis 10 and Leviticus 27 have no commentary in this edition. The reading shows a short note instead of empty text.

Hebrew layout is right to left. Commentary is set in Noto Serif Hebrew, which covers nikud, with extra line spacing. VoiceOver labels on the commentary are the Hebrew words.

## Data pipeline

`scripts/build_data.py` uses only the Python standard library (3.11+). It downloads the sources, checks the licence of each file, and writes:

- `OhrHaChaim/OhrHaChaim/Resources/ohr_hachaim.sqlite` — the bundled database, including an FTS5 index of the commentary with nikud and cantillation removed
- `data/manifest.json` — counts, licences, and a checksum

`--index-only` rebuilds that search index from the comments already in the database, without downloading. A full `python3 scripts/build_data.py` builds the index as part of writing the database.

```bash
python3 scripts/build_data.py
python3 scripts/build_data.py --validate-only
```

`--year-start` and `--year-end` default to 2024 through 2038. Downloaded files are cached in `scripts/.cache/` (not part of the app). Delete that directory to force a fresh download.

The database is keyed by book, parasha, chapter, verse, and comment. Stable integer ids keep favourites and the resume position valid across launches. Rebuilding can still change ids if the upstream segmentation changes; regenerate, then reinstall.

### What is downloaded

| Text | Version | Licence |
| --- | --- | --- |
| Or HaChaim on Genesis, Exodus, Leviticus, Numbers, Deuteronomy | Sefaria Vocalized Edition, Hebrew | CC0 |
| Author's introduction (Genesis only; the vocalized edition has none) | The Hebrew version titled exactly `On Your Way` | Public Domain |

Parasha boundaries come from each book's Sefaria index, `alt_structs.Parasha`.

The version titled `On Your Way ` (with a trailing space) is never requested. Its licence is unknown. The script refuses any file whose `versionTitle` or `license` is not exactly the pair above, and it refuses any segment that looks like an English translation.

The weekly table comes from Hebcal's calendar API (`s=on` for the Shabbat parasha, `i=on` for Israel and `i=off` for the Diaspora, plus Simchat Torah for וזאת הברכה). Hebcal content is **CC BY 4.0**. The app credits Hebcal.com. No GPL calendar library is used.

## Licences and attribution

- Commentary: Sefaria Vocalized Edition of Or HaChaim on the five books of the Torah. Hebrew. [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). [sefaria.org](https://www.sefaria.org)
- Author's introduction: Sefaria Hebrew version `On Your Way`. Public domain. [sefaria.org](https://www.sefaria.org)
- Reading calendar: [Hebcal.com](https://www.hebcal.com), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Attribute the schedule to Hebcal.com.
- Typeface: Noto Serif Hebrew, © 2022 The Noto Project Authors, [SIL Open Font License 1.1](OhrHaChaim/OhrHaChaim/Resources/Fonts/OFL.txt). The licence file is bundled next to the font.

## Privacy and support pages

`docs/index.html` is the support page for people using the app, in Hebrew and English. It describes the offline Hebrew commentary, points to the GitHub issue tracker for help, links to the privacy policy, and includes the optional PayPal donation. Building from source is documented in this README, not on that page. `docs/privacy/index.html` is the privacy policy, also in both languages: the app collects no data, has no analytics, and makes no network request of its own. History, favourites, and settings stay on the device. The in-app links in About and Settings point at:

- https://dberrebi.github.io/OhrHachaim/
- https://dberrebi.github.io/OhrHachaim/privacy/

Those URLs work after GitHub Pages is enabled for the repository (Settings → Pages → Deploy from a branch → `main` → `/docs`). This repository does not change that setting. `docs/app-store-listing.md` is a store-listing draft and is excluded from the Pages site.

An optional donation link lives only on that website support page. The iOS app, its About and Help screens, and the App Store listing do not ask for a donation. Apple guideline 3.1.1(a) forbids that outside the US storefront. An in-app tip jar, as an in-app purchase, can be added later, once a paid Apple Developer account exists.

## Not included

There is no App Store setup, no signing identity, and no in-app payment. Readings outside 2024–2038 need a new run of the data script.
