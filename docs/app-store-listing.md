# App Store listing draft

Draft only. Nothing here is uploaded, and no signing team is changed. Name availability was not checked in App Store Connect. The names אור החיים and Ohr HaChaim may already be taken, so the listing should use one of the alternatives below.

## Name

Apple allows 30 characters. Suggested alternatives, in order:

1. **אור החיים לפרשה** / **Ohr HaChaim Parasha**
2. **לימוד אור החיים** / **Learn Ohr HaChaim**
3. **קורא אור החיים** / **Ohr HaChaim Reader**

## Subtitle

30 characters.

- Hebrew: הפירוש לפי פרשת השבוע
- English: Weekly Torah commentary

## Description

Hebrew:

אור החיים לפרשה הוא קורא לא־מקוון לפירוש אור החיים של רבי חיים אבן עטר על התורה. הפירוש עצמו עברי בלבד, בלי תרגום.

המסך הראשון מוביל לשחזור המקום האחרון, להיסטוריה, למועדפים, לפרשת השבוע, לחיפוש, לחמישה חומשים, להגדרות, לעזרה ולאודות. בראשית כולל את הקדמת המחבר. פרשה נפתחת לפי הסדר, ובשבוע של שתי פרשות מחוברות הן נקראות ברצף. לוח ישראל ולוח חוץ לארץ נבחרים בהגדרות. וזאת הברכה נקבעת לפי שמחת תורה.

החיפוש רץ על הטקסט השמור במכשיר ומוצא מילה גם בלי ניקוד. תוצאה מציגה את הפרשה, את הפסוק וקטע קצר, ולחיצה פותחת את המקום בקורא.

בהגדרות: עברית או אנגלית לממשק, ניקוד, גודל אות, ומראה בהיר, כהה או לפי המערכת. כוכב שומר קטע, ומסך המועדפים מציג את הקטעים שנשמרו. מסך האודות מציג את המחבר, את המקורות ואת הרישיונות. לחיצה ארוכה מעתיקה או משתפת את הקטע העברי עם מראה המקום. במקום שאין בו פירוש במהדורה זו, כמו בראשית פרק י׳ וויקרא פרק כ״ז, מופיעה הערה.

English:

Ohr HaChaim Parasha is an offline reader for Rabbi Chaim ibn Attar's Ohr HaChaim on the Torah. The commentary itself is Hebrew only. There is no translation.

The home screen opens the last place, history, favourites, this week's parasha, search, the five books, settings, help, and about. Genesis includes the author's introduction. A parasha opens in order, and when two portions are read together they follow one another. The Israel and Diaspora calendars are chosen in Settings. Vezot HaBerachah follows Simchat Torah.

Search runs on the text stored in the app and matches a word without nikud. A result shows the parasha, the verse, and a short snippet. Tapping it opens that place in the reader.

Settings cover a Hebrew or English interface, nikud, type size, and light, dark, or system appearance. A star saves a passage, and Favourites lists those passages. About shows the author, the sources, and the licences. A long press copies or shares the Hebrew passage with its citation. Where this edition has no commentary, such as Genesis 10 and Leviticus 27, the reader shows a short note.

## Promotional text

170 characters maximum. These can be changed without a new binary.

- English (151 characters): A free, offline Hebrew reader for Ohr HaChaim, arranged by the weekly parasha. Interface in Hebrew or English; the commentary itself is not translated.
- Hebrew (96 characters): קורא חינמי ולא-מקוון לפירוש אור החיים לפי פרשת השבוע. הממשק בעברית או באנגלית; אין תרגום לפירוש.

## Keywords

Comma-separated, with no space after each comma. The app name is not included. The Hebrew list is 98 UTF-8 bytes.

- Hebrew: פרשה,תורה,פירוש,חיים אבן עטר,חומש,שבועי,עברית,לא מקוון
- English: parasha,Torah,commentary,ibn Attar,Chumash,weekly,Hebrew,offline

## Category

Reference. Books is the nearer second choice. Reference fits a commentary arranged for study.

## App Review notes

For guideline 4.2. This is a native offline SwiftUI reader, not a web wrapper. No account is needed.

The app includes:

- Full-text search of the Hebrew commentary that ignores nikud.
- Israel and Diaspora reading calendars.
- Combined parashot opened together.
- Resume, history, and favourites.
- A Hebrew or English interface. The commentary itself is Hebrew only.

Licences of the bundled material:

- Commentary: Sefaria Vocalized Edition, CC0.
- Author's introduction: the Hebrew version titled exactly “On Your Way”, Public Domain.
- Weekly calendar: Hebcal, CC BY 4.0.
- Typeface: Noto Serif Hebrew, SIL Open Font License 1.1.

## Content rights

The app includes third-party content under these licences: Sefaria Vocalized Edition of Or HaChaim (CC0), the author's introduction from the Hebrew version titled “On Your Way” (Public Domain), the Torah reading schedule from Hebcal (CC BY 4.0), and Noto Serif Hebrew (SIL Open Font License 1.1).

## Copyright

2026 Ohr HaChaim App

This names the app's owner as a project name. It does not claim the commentary, which is public domain (the vocalized edition is CC0).

## Age rating

4+. Answer “None” to every content question.

## Availability

Exclude China mainland. Religious content distributed there needs an NRAA permit, and this app does not have one.

All other countries, including the European Union. Under the EU Digital Services Act, David declares in App Store Connect that he is not a trader: the app is free, with no in-app purchases and no ads. Update that declaration if the app adds in-app purchases, an in-app tip jar, or ads.

## Privacy

Data Not Collected.

The app has no account, no analytics, and no network calls of its own. History, favourites, and settings remain on the device. See `docs/privacy/index.html`.

## Donations

The app is free. Donations stay on the website support page only. This listing, and the app, must not include a donate button, a PayPal link, or a “support us” call to action. Apple guideline 3.1.1(a) forbids that outside the US storefront. An in-app tip jar (an in-app purchase) can be added later, once a paid Apple Developer account exists.

## URLs

These addresses match the pages in `docs/`, which GitHub Pages publishes from `main`.

- Support URL: https://dberrebi.github.io/OhrHachaim/
- Privacy Policy URL: https://dberrebi.github.io/OhrHachaim/privacy/
- Support email: ohrhachaimapp@gmail.com. It is on both pages. Use it as the contact email in App Review Information too; the phone number there is seen only by Apple.

## Screenshots

The iOS workflow writes an `app-store-screenshots` artifact, in the Hebrew interface: home, the weekly reading, a book's parasha list, the reader, search, and settings.

- iPhone 17 Pro, the required medium Dynamic Island slot: 1206×2622.
- iPhone 17 Pro Max, the 6.9-inch slot: 1320×2868.
- iPad Pro 13-inch: 2064×2752.
