# ReaderCount for iPhone, iPad and Mac

The native ReaderCount app: your website's readers, live, wherever you are. One SwiftUI app runs on iPhone, iPad and Mac, with widgets and a live count in the Mac menu bar.

- **iPhone:** Today, Live, Health, More and Account tabs.
- **iPad:** the same, with a sidebar like the website's left menu.
- **Mac:** a window with the website's left menu, a menu bar count of Real-Time Active Visitors and CSV export.
- **Widgets:** visitors today and who's reading now, on the home screen, lock screen and Mac desktop.
- **Alerts:** traffic spikes, a website going down, goals and triggers, broken links and the monthly review, as notifications.

Accounts are made at [readercount.com](https://readercount.com). The app signs in with ReaderCount's own sign in page (an emailed code or a passkey) and only reads stats, plus marking Site Health items as fixed and choosing alerts.

## How it's built

- `apps/project.yml` is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) project, so nobody needs Xcode to change the app.
- `apps/ReaderCount` is the app, `apps/ReaderCountWidget` the widgets, `apps/Shared` what both use (sign in, the API and its answers).
- The app talks to `https://app.readercount.com/app/v1/`.
- A commit whose message starts with `[testflight]` builds both apps and sends them to TestFlight; `[testflight ios]` or `[testflight mac]` builds one.

## Licence

Business Source License 1.1. You can build and use it for yourself. It is not open source. See [LICENSE](LICENSE).
