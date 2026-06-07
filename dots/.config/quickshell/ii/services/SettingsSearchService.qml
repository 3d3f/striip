pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string query: ""
    property var results: []
    property string targetSection: ""
    property string highlightSection: ""
    property var registeredCards: ({})
    property var settingsIndex: []
    property bool indexLoaded: false

    Component.onCompleted: indexFile.reload()

    FileView {
        id: indexFile
        path: Directories.settingsSearchIndex
        onLoaded: {
            try {
                root.settingsIndex = JSON.parse(text());
                root.indexLoaded = true;
            } catch (e) {
                console.warn("SettingsSearchService: failed to parse index:", e);
                root.settingsIndex = [];
            }
        }
        onLoadFailed: error => console.warn("SettingsSearchService: failed to load index:", error)
    }

    // Card registration (called by ContentSection)

    function registerCard(settingKey, item, flickable) {
        if (!settingKey) return;
        var cards = Object.assign({}, registeredCards);
        cards[settingKey] = { item: item, flickable: flickable };
        registeredCards = cards;
        if (targetSection === settingKey)
            scrollTimer.restart();
    }

    function unregisterCard(settingKey) {
        if (!settingKey) return;
        var cards = Object.assign({}, registeredCards);
        delete cards[settingKey];
        registeredCards = cards;
    }

    // Navigation

    function navigateToSection(section) {
        targetSection = section;
        if (registeredCards[section])
            scrollTimer.restart();
        // If card isn't registered yet (page not loaded), the Loader's
        // onLoaded will trigger scrollTimer via registerCard above.
    }

    function scrollToTarget() {
        if (!targetSection) return;
        const entry = registeredCards[targetSection];
        if (!entry || !entry.item || !entry.flickable) return;

        const flickable = entry.flickable;
        const item = entry.item;
        const contentItem = flickable.contentItem;
        if (!contentItem) return;

        const mapped = item.mapToItem(contentItem, 0, 0);
        const maxY = Math.max(0, flickable.contentHeight - flickable.height);
        const targetY = Math.min(maxY, Math.max(0, mapped.y - 16));
        flickable.contentY = targetY;

        highlightSection = targetSection;
        targetSection = "";
        highlightTimer.restart();
    }

    function clearHighlight() {
        highlightSection = "";
    }

    Timer {
        id: scrollTimer
        interval: 50
        onTriggered: root.scrollToTarget()
    }

    Timer {
        id: highlightTimer
        interval: 2500
        onTriggered: root.highlightSection = ""
    }

    // Search
    
    function search(text) {
        query = text;
        if (!text) {
            results = [];
            return;
        }
        results = _searchEntries(text, 15);
    }

    function clear() {
        query = "";
        results = [];
        targetSection = "";
        highlightSection = "";
    }

    function _bestFieldScore(field, queryLower, exactScore, prefixScore, includesScore) {
        if (!field) return 0;
        const f = field.toLowerCase();
        if (f === queryLower) return exactScore;
        if (f.startsWith(queryLower)) return prefixScore;
        if (f.includes(queryLower)) return includesScore;
        return 0;
    }

    function _searchEntries(text, maxResults) {
        if (!text) return [];

        const queryLower = text.toLowerCase().trim();
        const queryWords = queryLower.split(/\s+/).filter(w => w.length > 0);
        const scored = [];

        for (let i = 0; i < settingsIndex.length; i++) {
            const entry = settingsIndex[i];
            let score = 0;

            // Label (highest priority)
            score = Math.max(score, _bestFieldScore(entry.label, queryLower, 10000, 5000, 1000));
            // Category
            score = Math.max(score, _bestFieldScore(entry.category, queryLower, 500, 500, 500));
            // Description
            score = Math.max(score, _bestFieldScore(entry.description, queryLower, 250, 250, 250));

            // Keywords
            if (score === 0) {
                const kws = entry.keywords || [];
                for (let k = 0; k < kws.length; k++) {
                    const kw = kws[k].toLowerCase();
                    if (kw.startsWith(queryLower)) { score = 800; break; }
                    if (kw.includes(queryLower) && score < 400) score = 400;
                }
            }

            // Multi-word fallback: all words must appear somewhere
            if (score === 0 && queryWords.length > 1) {
                const allFields = [
                    (entry.label || "").toLowerCase(),
                    (entry.description || "").toLowerCase(),
                    (entry.category || "").toLowerCase(),
                    ...(entry.keywords || []).map(k => k.toLowerCase())
                ];
                const allMatch = queryWords.every(word =>
                    allFields.some(f => f.includes(word))
                );
                if (allMatch) score = 300;
            }

            if (score > 0)
                scored.push({ item: entry, score: score });
        }

        scored.sort((a, b) => b.score - a.score);
        return scored.slice(0, maxResults).map(s => s.item);
    }
}
