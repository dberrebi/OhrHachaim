# אור החיים

An offline iPhone and iPad app for reading **Ohr HaChaim** (אור החיים), Rabbi Chaim ibn Attar's commentary on the Torah, arranged by weekly parasha.

The commentary itself is Hebrew only. English is available for the interface: menus, settings, and help. There is no translation of the commentary.

The app does not use the network at runtime, and it has no analytics.

## Open and run

Requirements: Xcode 15 or later, iOS 17 or later. The project is `OhrHaChaim/OhrHaChaim.xcodeproj`.

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

In Xcode, choose an iPhone or iPad simulator and run. The first screen is a full-width list: resume, history, this week's parasha, the five books, settings, help, and about.

GitHub Actions (`.github/workflows/ios.yml`) builds and tests the same way on a macOS runner, with code signing disabled. The tests include an iPhone check that tapping בראשית opens its parasha list. The run uploads screenshots of that list and of the home screen. A pull request from this repository is covered by the branch push, so the workflow does not start a second macOS run for it.

The in-app language changes the interface strings, the layout direction, and date formatting immediately. The name on the device Home Screen, some system sheets, and the VoiceOver language stay on the device language.

## Screens

- **Home.** Centred rows and a dark bar with the app mark, the title, share, and favourites.
- **Book.** The parshiyot of that book. Genesis also lists the author's introduction.
- **Reading.** Ohr HaChaim for one parasha, or for two when they are read together, grouped by chapter and verse. Phrases marked in the edition (the dibbur hamatchil, and other highlighted phrases) are emphasised. A star saves a passage. A long press copies or shares the Hebrew text.
- **This week.** The coming Shabbat reading, using the Israel or Diaspora table from Settings. Combined parshiyot open together. וזאת הברכה is scheduled on Simchat Torah.
- **Resume and history.** The last passage, and recent passages.
- **Settings.** Interface language (Hebrew or English, String Catalog only), Israel or Diaspora, nikud, type size (the in-app slider and the system text size), and light, dark, or system appearance.
- **About.** The author, the sources, and the licences.

Genesis 10 and Leviticus 27 have no commentary in this edition. The reading shows a short note instead of empty text.

Hebrew layout is right to left. Commentary is set in Noto Serif Hebrew, which covers nikud, with extra line spacing. VoiceOver labels on the commentary are the Hebrew words.

## Data pipeline

`scripts/build_data.py` uses only the Python standard library (3.11+). It downloads the sources, checks the licence of each file, and writes:

- `OhrHaChaim/OhrHaChaim/Resources/ohr_hachaim.sqlite` — the bundled database
- `data/manifest.json` — counts, licences, and a checksum

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

## Not included

There is no App Store setup, no signing identity, and no payments. Readings outside 2024–2038 need a new run of the data script.
