/* PA Desktop — Firefox defaults.
 * NON Attivi:
 *  - proxy Tor/AnonSurf (network.proxy.*) e onion PAC
 *  - privacy.firstparty.isolate (rompe Teams / basic auth)
 *  - privacy.resistFingerprinting (può rompere web-app PA/SPID)
 *  - locale/regione US (qui: IT)
 */
pref("browser.contentblocking.category", "strict");
pref("privacy.trackingprotection.enabled", true);
pref("privacy.trackingprotection.pbmode.enabled", true);
pref("privacy.trackingprotection.cryptomining.enabled", true);
pref("privacy.trackingprotection.socialtracking.enabled", true);
pref("privacy.donottrackheader.enabled", true);
pref("network.cookie.cookieBehavior", 5);
pref("network.cookie.cookieBehavior.pbmode", 5);
pref("privacy.firstparty.isolate", false);
pref("privacy.resistFingerprinting", false);

pref("browser.search.region", "IT");
pref("javascript.use_us_english_locale", false);
pref("browser.search.suggest.enabled", false);
pref("browser.urlbar.suggest.searches", false);
pref("network.dns.disablePrefetch", true);
pref("network.dns.disablePrefetchFromHTTPS", true);
pref("network.predictor.enabled", false);
pref("network.captive-portal-service.enabled", false);

pref("browser.shell.checkDefaultBrowser", false);
pref("app.normandy.enabled", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.enabled", false);

pref("browser.newtabpage.enabled", false);
pref("browser.newtabpage.activity-stream.showSponsored", false);
pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
pref("extensions.pocket.enabled", false);

pref("browser.startup.homepage", "https://www.agid.gov.it/");
pref("browser.startup.firstrunSkipsHomepage", true);
pref("intl.locale.matchOS", true);
pref("browser.tabs.inTitlebar", 1);
pref("devtools.theme", "dark");
pref("browser.theme.toolbar-theme", 0);
pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");

pref("media.video_stats.enabled", false);
pref("webgl.enable-debug-renderer-info", false);
pref("dom.gamepad.enabled", false);
