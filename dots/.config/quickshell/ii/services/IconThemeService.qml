pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var    availableThemes: []
    property string currentTheme:    ""

    function ensureInitialized(): void {
        currentThemeProc.running = true
        listThemesProc.running = true
    }

    function setTheme(themeName): void {
        const t = String(themeName).trim()
        if (!t) return
        
        root.currentTheme = t
        Config.setNestedValue('appearance.iconTheme', t)        
        Quickshell.execDetached([Directories.themeScriptPath, "set", t])
    }

    Process {
        running: Config.ready
        command: [Directories.themeScriptPath, "set", Config.options.appearance.iconTheme]
    }

    Process {
        id: currentThemeProc
        command: [Directories.themeScriptPath, "get"]
        stdout: SplitParser {
            onRead: line => root.currentTheme = line.trim()
        }
    }

    Process {
        id: listThemesProc
        command: [Directories.themeScriptPath, "list"]
        stdout: StdioCollector {
            id: themeCollector
            onStreamFinished: {
                root.availableThemes = themeCollector.text
                    .split("\n")
                    .filter(t => t.trim().length > 0)
            }
        }
    }
}