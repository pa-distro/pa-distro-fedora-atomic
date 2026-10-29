// PA Desktop — layout di default (Plasma 6).
// Pannello in basso, stile Windows: Kickoff, Icon Tasks, tray, orologio, mostra desktop.
// Riferimento API: KDE plasma-desktop/layout-templates + shell/scripting/panel.h (6.7).

var panel = new Panel
var panelScreen = panel.screen

panel.location   = "bottom"
panel.floating   = true
panel.opacity    = "adaptive"
panel.lengthMode = "fill"

// Altezza ~44 px, indipendente dal DPI (stessa formula del template KDE)
panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2)

panel.addWidget("org.kde.plasma.kickoff")

// Icon Tasks con i pin "uso quotidiano" (Windows-like)
var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", [
    "applications:org.mozilla.firefox.desktop",
    "preferred://filemanager",
    "applications:thunderbird.desktop",
    "applications:libreoffice-writer.desktop",
    "applications:libreoffice-calc.desktop"
])
tasks.reloadConfig()

panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.digitalclock")
panel.addWidget("org.kde.plasma.showdesktop")
