# Mole — Native macOS UI Design Specification

> **Version:** 1.0 draft
> **Target:** macOS 13+ (Ventura) — SwiftUI with `NavigationSplitView`
> **CLI:** wraps the existing `mo` / `mole` CLI (Bash + Go binaries)

---

## Table of Contents

1. [Overview & Architecture](#1-overview--architecture)
2. [Navigation & Layout](#2-navigation--layout)
3. [Screen-by-Screen Specs](#3-screen-by-screen-specs)
4. [Component Library](#4-component-library)
5. [Design Tokens](#5-design-tokens)
6. [CLI Integration Layer](#6-cli-integration-layer)
7. [State Management](#7-state-management)
8. [Data Models](#8-data-models)

---

## 1. Overview & Architecture

### 1.1 App Identity

| Field | Value |
|-------|-------|
| **Name** | Mole |
| **Bundle ID** | `com.mole.app` |
| **Icon concept** | Stylised mole emerging from a tunnel, matching the ASCII mole mascot used in `mo status`. Rounded-square macOS icon with purple gradient (`#BD93F9` → `#C79FD7`). |
| **Positioning** | Native macOS companion for the `mo` CLI — same capabilities, graphical interface. |

### 1.2 Architecture

```
┌──────────────────────────────────────────────────┐
│                  SwiftUI App                     │
│  ┌────────────┐  ┌───────────────────────────┐   │
│  │  Sidebar   │  │      Detail View           │   │
│  │ Navigation │  │  (per-screen content)      │   │
│  └────────────┘  └───────────────────────────┘   │
│         │                    │                    │
│  ┌──────┴────────────────────┴──────────────┐    │
│  │         CLIBridge (actor)                 │    │
│  │  • Process spawning                       │    │
│  │  • stdout/stderr streaming                │    │
│  │  • JSON / line-based parsing              │    │
│  │  • Privilege escalation                   │    │
│  └──────────────────────────────────────────┘    │
│                      │                            │
│              ┌───────┴────────┐                   │
│              │   mo / mole    │                   │
│              │  CLI binaries  │                   │
│              └────────────────┘                   │
└──────────────────────────────────────────────────┘
```

The app does **not** reimplement CLI logic. Every operation dispatches through `CLIBridge`, which resolves the installed `mo` binary path, spawns `Process` (née `NSTask`), and parses output.

### 1.3 Supported macOS Versions

- **Minimum:** macOS 13 Ventura (required for `NavigationSplitView`).
- **Recommended:** macOS 14 Sonoma or later.

### 1.4 Sandboxing & Permissions

| Concern | Approach |
|---------|----------|
| **App Sandbox** | Disabled. The app requires access to arbitrary filesystem paths (`~/Library/Caches`, `/Applications`, project directories) and must invoke `mo` which itself calls `du`, `rm`, `system_profiler`, `pmset`, etc. |
| **Full Disk Access** | Requested on first launch via a guided onboarding sheet. Without it, `mo clean` and `mo analyze` cannot scan all cache directories. |
| **sudo / Admin** | Commands that need root (`mo optimize` operations, firewall check) are elevated via `AuthorizationExecuteWithPrivileges` replacement — the app calls `osascript -e 'do shell script "..." with administrator privileges'` or uses the `Authorization Services` C API. A permission prompt is shown to the user by macOS. |
| **Network** | Outbound only — update checks hit `api.github.com`. No server component. |
| **Hardened Runtime** | Enabled with entitlement for spawning child processes. |

---

## 2. Navigation & Layout

### 2.1 Window

| Property | Value |
|----------|-------|
| **Style** | `NSWindow` with `.titled`, `.closable`, `.miniaturizable`, `.resizable` masks. |
| **Default size** | 1040 × 680 pt |
| **Minimum size** | 780 × 520 pt |
| **Toolbar** | Unified — title hidden in toolbar, integrated with sidebar toggle. |

### 2.2 NavigationSplitView

```
┌──────────────┬───────────────────────────────────────┐
│  Sidebar     │  Detail                               │
│  (220 pt)    │                                       │
│              │                                       │
│  Dashboard   │   [content for selected section]      │
│  ──────────  │                                       │
│  Clean       │                                       │
│  Uninstall   │                                       │
│  Analyze     │                                       │
│  Optimize    │                                       │
│  ──────────  │                                       │
│  Status      │                                       │
│  ──────────  │                                       │
│  Purge       │                                       │
│  Installers  │                                       │
│              │                                       │
│              │                                       │
│  ──────────  │                                       │
│  ⚙ Settings │                                       │
└──────────────┴───────────────────────────────────────┘
```

**Sidebar sections** (top to bottom):

| Section | SF Symbol | CLI mapping |
|---------|-----------|-------------|
| Dashboard | `gauge.with.dots.needle.bottom.50percent` | Aggregated (status + health JSON) |
| **separator** | | |
| Clean | `trash` | `mo clean` |
| Uninstall | `xmark.app` | `mo uninstall` |
| Analyze | `chart.bar.doc.horizontal` | `mo analyze` |
| Optimize | `wrench.and.screwdriver` | `mo optimize` |
| **separator** | | |
| Status | `waveform.path.ecg.rectangle` | `mo status` |
| **separator** | | |
| Purge | `folder.badge.minus` | `mo purge` |
| Installers | `doc.zipper` | `mo installer` |
| **separator** | | |
| Settings | `gearshape` | — |

Settings opens as a **sheet** (`.sheet` modifier), not a sidebar destination.

### 2.3 Responsive Behaviour

- Sidebar collapses at window widths < 600 pt; toolbar button toggles it.
- Detail area stretches to fill remaining space.
- All lists use `LazyVStack` for large data sets.

---

## 3. Screen-by-Screen Specs

---

### 3.1 Dashboard

**Purpose:** At-a-glance system overview with quick actions.

**Data sources:**

| Data point | Source |
|------------|--------|
| Health score (0-100) | Parsed from `mo status` Go binary's `MetricsSnapshot.HealthScore` via the health JSON generator (`lib/check/health_json.sh`) |
| Disk usage | `df` via health JSON (`disk_used_gb`, `disk_total_gb`, `disk_used_percent`) |
| Memory usage | health JSON (`memory_used_gb`, `memory_total_gb`) |
| Uptime | health JSON (`uptime_days`) |
| Cache size cleanable | `lib/check/all.sh` → `check_cache_size` output |
| Last clean date | Read from `~/.config/mole/operations.log` (last `clean` entry timestamp) |

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│  Dashboard                                                  │
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │  Health Score        │  │  Disk Usage          │        │
│  │      ● 92            │  │  ██████████░░  67%   │        │
│  │   Excellent          │  │  156 GB free          │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │  Memory              │  │  Cache Size          │        │
│  │  ██████████░░  58%   │  │  8.4 GB cleanable    │        │
│  │  14 / 24 GB          │  │  Last cleaned: 3d ago│        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                             │
│  Quick Actions                                              │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌──────────┐   │
│  │ 🧹 Clean  │ │ ⚡ Optimize│ │ 📊 Status │ │ 🗑 Purge │   │
│  └───────────┘ └───────────┘ └───────────┘ └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
DashboardView
├── LazyVGrid(columns: 2, spacing: 16)
│   ├── MetricCard(title: "Health Score", variant: .score)
│   ├── MetricCard(title: "Disk Usage", variant: .gauge)
│   ├── MetricCard(title: "Memory", variant: .gauge)
│   └── MetricCard(title: "Cache Size", variant: .info)
├── Divider()
└── HStack (Quick Actions)
    ├── QuickActionButton(label: "Clean", icon: "trash")
    ├── QuickActionButton(label: "Optimize", icon: "wrench.and.screwdriver")
    ├── QuickActionButton(label: "Status", icon: "waveform.path.ecg.rectangle")
    └── QuickActionButton(label: "Purge", icon: "folder.badge.minus")
```

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Loading** | Each `MetricCard` shows a `ProgressView()` shimmer placeholder. Quick action buttons are disabled. |
| **Populated** | Cards show live data. Quick action buttons navigate to corresponding sidebar section. |
| **Error** | Card shows a red `StatusBadge(.error)` with a "Retry" button. Other cards remain independent. |
| **Stale data** | If health JSON is older than 5 minutes, a subtle "Refreshing..." label appears. Auto-refresh fires on view appearance and every 60 seconds. |

**User actions:**

| Action | Result |
|--------|--------|
| Tap Quick Action button | Sets sidebar selection → navigates to that screen. |
| Pull-to-refresh (trackpad gesture) | Re-runs health JSON collection. |
| Click "Clean" quick action while data is loading | Queued — navigates after load completes. |

---

### 3.2 Clean

**Purpose:** Free up disk space by removing caches, logs, and temp files.

**CLI:** `mo clean [--dry-run] [--debug]`

**Clean categories** (from `lib/clean/` modules):

| Category | Module | Description |
|----------|--------|-------------|
| User App Caches | `app_caches.sh` | Per-app cache directories in `~/Library/Caches` |
| Browser Caches | `caches.sh` | Chrome, Safari, Firefox, Edge, Arc, Brave, Opera, Vivaldi |
| Developer Tools | `dev.sh` | Xcode DerivedData, npm/yarn/pnpm cache, pip, cargo, CocoaPods, Gradle, Maven |
| System Logs & Temp | `system.sh` | `/var/log`, `/tmp`, diagnostic reports, crash logs |
| Homebrew | `brew.sh` | Brew cache, old formula versions |
| App-Specific | `apps.sh` | Spotify, Dropbox, Slack, Discord, Teams, VS Code, etc. |
| User Data | `user.sh` | Trash, Downloads cleanable items |
| Project Artifacts | `project.sh` | Build output directories |

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│  Clean                                          [Dry Run ◻] │
│                                                              │
│  Select categories to clean:                                 │
│                                                              │
│  ☑  User App Caches ........................... 12.4 GB     │
│  ☑  Browser Caches ............................. 8.2 GB     │
│  ☑  Developer Tools ........................... 15.7 GB     │
│  ☑  System Logs & Temp ......................... 2.1 GB     │
│  ☑  Homebrew ................................... 3.4 GB     │
│  ☐  App-Specific ............................... 4.8 GB     │
│  ☐  User Data (Trash) .......................... 6.3 GB     │
│  ☐  Project Artifacts .......................... 1.2 GB     │
│                                                              │
│  ──────────────────────────────────────────────────────────  │
│  Total selected: 41.8 GB                                     │
│                                                              │
│           [Cancel]    [Clean Selected]                        │
└─────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
CleanView
├── HStack
│   ├── Text("Clean").font(.title2).bold()
│   └── Toggle("Dry Run", isOn: $dryRun)
├── ScrollView
│   └── VStack
│       └── ForEach(categories)
│           └── CategoryRow(
│                 name, size, isSelected,
│                 onToggle, onExpand
│               )
├── Divider()
├── HStack
│   ├── SizeLabel(totalSelected)
│   └── Spacer()
└── HStack
    ├── Button("Cancel")
    └── Button("Clean Selected", role: .destructive)
```

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Loading** | "Calculating sizes..." with per-category shimmer. Categories appear as they resolve (streamed). |
| **Populated** | All categories shown with sizes. Top 4 selected by default. |
| **Cleaning in progress** | Replaces list with `ProgressView` showing current category, files cleaned count, and bytes freed. Cancel button becomes "Stop". |
| **Complete** | Summary view: "Freed 41.8 GB. Free space now: 223 GB." with a "Done" button returning to the category list. |
| **Dry-run complete** | Summary: "Would free 41.8 GB across 1,247 files." No files deleted. Badge: `StatusBadge(.dryRun)`. |
| **Error** | Inline error below the failed category with "Retry" / "Skip" options. Other categories continue. |
| **Empty** | "Your system is already clean! No significant caches found." with `EmptyState` component. |

**Confirmation dialog** (when Dry Run is OFF):

```
┌─────────────────────────────────────────────┐
│  ⚠ Clean 41.8 GB?                          │
│                                             │
│  This will permanently delete cached files  │
│  from 4 categories. This cannot be undone.  │
│                                             │
│  Whitelisted paths will be skipped.         │
│                                             │
│         [Cancel]    [Clean]                 │
└─────────────────────────────────────────────┘
```

**CLI invocations:**

| Action | Command |
|--------|---------|
| Calculate sizes | Parse stdout of `mo clean --dry-run` — each line matching `⚠ <item> <size> dry` |
| Execute clean | `mo clean` (no flags) |
| Dry run | `mo clean --dry-run` |
| Debug mode | `mo clean --debug` (toggled from Settings) |

**Whitelist integration:**

- Config file: `~/.config/mole/whitelist`
- Accessible from Settings sheet → "Clean Whitelist" section.
- Protected paths (Playwright, HuggingFace, Ollama, etc.) shown as read-only entries.

---

### 3.3 Uninstall

**Purpose:** Completely remove applications and their associated files.

**CLI:** `mo uninstall [--debug]`

**Scan locations:**

- `/Applications`
- `~/Applications`
- `/Library/Input Methods`
- `~/Library/Input Methods`
- `/Volumes/*/Applications`

**Associated file locations removed:**

- Application Support, Caches, Preferences, Logs
- WebKit storage, Cookies, Extensions, Plugins
- Launch Agents/Daemons

**Cache:** `~/.cache/mole/app_scan_cache` (24-hour TTL)

**Layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Uninstall                                                      │
│                                                                  │
│  ┌─────────────────────────────────────┐                        │
│  │ 🔍 Search apps...                   │  Sort: [Size ▾]       │
│  └─────────────────────────────────────┘                        │
│                                                                  │
│  ┌─ App List ───────────────────────────┬─ Detail ────────────┐ │
│  │                                      │                      │ │
│  │  ☐  Xcode              14.2 GB  Old │  Xcode               │ │
│  │  ☐  Docker Desktop      4.8 GB      │  Version 15.0        │ │
│  │  ☐  Slack               2.1 GB      │  Size: 14.2 GB       │ │
│  │  ☐  Spotify             1.8 GB      │  Last opened: 6mo    │ │
│  │  ☐  Discord             1.2 GB  Old │  Location:            │ │
│  │  ☐  Visual Studio Code  980 MB      │  /Applications/       │ │
│  │  ...                                 │                      │ │
│  │                                      │  Associated files:   │ │
│  │                                      │  • App Support 2.1GB │ │
│  │                                      │  • Caches     1.4GB  │ │
│  │                                      │  • Preferences  12KB │ │
│  │                                      │  • Logs        340KB │ │
│  │                                      │                      │ │
│  │                                      │  Total: 17.7 GB      │ │
│  └──────────────────────────────────────┴──────────────────────┘ │
│                                                                  │
│  Selected: 2 apps (19.0 GB)                                      │
│              [Cancel]    [Uninstall Selected]                    │
└─────────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
UninstallView
├── HStack
│   ├── SearchBar(text: $searchText)
│   └── Picker("Sort", selection: $sortOrder)
│         // options: .size, .name, .lastOpened
├── HSplitView
│   ├── List(selection: $selectedApps)
│   │   └── ForEach(filteredApps)
│   │       └── AppRow(name, icon, size, ageLabel)
│   └── AppDetailPane(app: focusedApp)
│       ├── AppIcon + name + version
│       ├── SizeLabel(totalSize)
│       ├── Text("Last opened: ...")
│       └── AssociatedFilesList
├── Divider()
├── HStack
│   ├── Text("Selected: \(count) apps (\(size))")
│   └── Spacer()
└── HStack
    ├── Button("Cancel")
    └── Button("Uninstall Selected", role: .destructive)
```

**Sort options:**

| Option | Behaviour |
|--------|-----------|
| Size (default) | Largest first |
| Name | Alphabetical A-Z |
| Last Opened | Least recently used first |

**Filter:** Live search matches app name (case-insensitive substring).

**Age label:** Apps not opened in > 90 days show an "Old" badge (yellow `StatusBadge(.warning)`).

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Loading** | "Scanning applications..." with progress. Uses cached data if < 24 hours old; shows "Using cached data" subtitle. |
| **Populated** | Full list with sizes. Detail pane shows focused app info. |
| **Removing** | Progress sheet overlay showing current app being removed, file count, bytes freed. |
| **Complete** | "Removed 2 apps, freed 19.0 GB." Done button returns to list (re-scans). |
| **Error** | Per-app error inline: "Could not remove Xcode — permission denied." Skip / Retry. |
| **Empty search** | `EmptyState(message: "No apps matching '\(query)'")` |

**Confirmation dialog:**

```
┌────────────────────────────────────────────────────┐
│  ⚠ Uninstall 2 Applications?                      │
│                                                    │
│  • Xcode (14.2 GB)                                │
│  • Discord (1.2 GB)                               │
│                                                    │
│  This will remove the apps and all associated      │
│  files (caches, preferences, support files).       │
│  This cannot be undone.                            │
│                                                    │
│           [Cancel]    [Uninstall]                  │
└────────────────────────────────────────────────────┘
```

**CLI invocations:**

| Action | Command |
|--------|---------|
| Scan apps | Parse `mo uninstall` TUI output (or directly scan `/Applications` and call `du`) |
| Remove app | Invoke `mo uninstall` with the selected app names piped as input (or shell out to the same removal logic) |

---

### 3.4 Analyze

**Purpose:** Visual disk usage explorer with drill-down navigation.

**CLI:** `mo analyze [PATH]`

**Go binary:** `analyze-go` (Bubbletea TUI, ~4,300 lines)

Since the analyze command is a full TUI, the native app reimplements the view layer while reusing the same scanning logic by invoking `analyze-go` with machine-readable output, or by performing filesystem scanning natively in Swift.

**Preferred approach:** Native Swift scanning using `FileManager` + `DispatchQueue.concurrentPerform` to mirror the Go binary's worker pool (16-64 workers). This avoids TUI parsing complexity.

**Data structures mirrored:**

```
dirEntry  → AnalyzeEntry(name, path, size, isDir, lastAccess)
fileEntry → LargeFile(name, path, size)
scanResult → ScanResult(entries: [AnalyzeEntry], largeFiles: [LargeFile], totalSize, totalFiles)
```

**Layout:**

```
┌──────────────────────────────────────────────────────────────────┐
│  Analyze    ~/Documents                    Total: 156.8 GB       │
│  ← Back                                                          │
│                                                                   │
│  ┌─ Bar Chart ──────────────────────────────────────────────────┐ │
│  │ Library      ███████████████████████████████░░░░░  48.2%     │ │
│  │ Downloads    ██████████████░░░░░░░░░░░░░░░░░░░░░  22.1%     │ │
│  │ Movies       █████████░░░░░░░░░░░░░░░░░░░░░░░░░░  14.3%     │ │
│  │ Desktop      ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   6.7%    │ │
│  │ Documents    ███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   4.2%    │ │
│  │ Pictures     ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   2.8%    │ │
│  │ ...                                                           │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─ Large Files (> 1 MB) ──────────────────────────────────────┐ │
│  │  movie_backup.mov ................ 8.2 GB   ~/Movies/       │ │
│  │  Xcode_15.xip ................... 6.1 GB   ~/Downloads/     │ │
│  │  database.sqlite ................ 2.4 GB   ~/Library/       │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  [Open in Finder]  [Delete Selected]                              │
└──────────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
AnalyzeView
├── HStack
│   ├── Button("← Back", action: navigateUp)
│   ├── PathBreadcrumb(segments: pathComponents)
│   └── SizeLabel(totalSize)
├── Toggle("Show Large Files", isOn: $showLargeFiles)
├── ScrollView
│   ├── Section("Directories — Top 30")
│   │   └── ForEach(entries)
│   │       └── AnalyzeRow(
│   │             name, size, percentage,
│   │             isDir, isSelected,
│   │             onTap: drillDown,
│   │             onSelect: toggleMultiSelect
│   │           )
│   └── Section("Large Files (> 1 MB) — Top 20") // conditional
│       └── ForEach(largeFiles)
│           └── FileRow(name, size, parentDir)
├── Divider()
└── HStack
    ├── Button("Open in Finder")
    └── Button("Delete Selected", role: .destructive)
```

**Bar rendering:**

Each `AnalyzeRow` contains a `ProgressBar` showing the percentage of parent directory size. Color is `semantic.primary` (`#BD93F9`). The percentage label is right-aligned.

**Navigation:**

| Gesture | Action |
|---------|--------|
| Click directory row | Drill into that directory (push onto history stack). |
| Click "← Back" / swipe back | Pop history stack, restore scroll position. |
| Breadcrumb segment click | Navigate directly to that ancestor path. |

**Overview mode** (path = `/`):

Shows predefined system locations instead of scanning root:
- Home (`~`)
- Library (`~/Library`)
- Applications (`/Applications`)
- System Library (`/Library`)
- Volumes (`/Volumes`)

Sizes are fetched concurrently with a cached overview (`~/.cache/mole/overview_sizes.json`, 7-day TTL).

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Scanning** | `ProgressView` with "Scanning... 12,456 files" counter (updated via `filesScanned` atomic). |
| **Populated** | Bar chart + optional large files section. |
| **Empty directory** | `EmptyState(message: "This directory is empty")` |
| **Permission denied** | Inline warning: "Cannot access this directory. Grant Full Disk Access in System Settings." |
| **Deleting** | Progress overlay: "Deleting 3 items..." with file counter. |
| **Delete complete** | Toast notification: "Deleted 3 items (4.2 GB)." Directory re-scans automatically. |

**Confirmation dialog (delete):**

```
┌────────────────────────────────────────────────┐
│  ⚠ Delete 3 items (4.2 GB)?                   │
│                                                │
│  • Library/ (2.1 GB)                           │
│  • movie_backup.mov (8.2 GB)                   │
│  • old_project/ (1.4 GB)                       │
│                                                │
│  Items will be moved to Trash.                 │
│                                                │
│         [Cancel]    [Move to Trash]            │
└────────────────────────────────────────────────┘
```

**Cache system:**

- Scan results cached at `~/.cache/mole/` with 7-day TTL per path.
- Cache key: `xxhash` of absolute path.
- "Refresh" button forces a cache-busting re-scan.

---

### 3.5 Optimize

**Purpose:** Run system maintenance checks and apply optimizations.

**CLI:** `mo optimize [--dry-run] [--whitelist] [--debug]`

**Optimization items** (from `lib/check/health_json.sh`):

| Action key | Name | Description |
|------------|------|-------------|
| `system_maintenance` | DNS & Spotlight Check | Refresh DNS cache, verify Spotlight |
| `cache_refresh` | Finder Cache Refresh | QuickLook thumbnails, icon services |
| `saved_state_cleanup` | App State Cleanup | Remove old saved application states (30+ days) |
| `fix_broken_configs` | Broken Config Repair | Fix corrupted preferences files |
| `network_optimization` | Network Cache Refresh | DNS cache, restart mDNSResponder |
| `sqlite_vacuum` | Database Optimization | Compress SQLite databases (Mail, Safari, Messages) |
| `launch_services_rebuild` | LaunchServices Repair | "Open with" menu, file associations |
| `font_cache_rebuild` | Font Cache Rebuild | Rebuild font database |
| `dock_refresh` | Dock Refresh | Fix broken icons, visual glitches |
| `memory_pressure_relief` | Memory Optimization | Release inactive memory |
| `network_stack_optimize` | Network Stack Refresh | Flush routing table, ARP cache |
| `disk_permissions_repair` | Permission Repair | Fix user directory permissions |
| `bluetooth_reset` | Bluetooth Refresh | Restart Bluetooth module |
| `spotlight_index_optimize` | Spotlight Optimization | Rebuild index if search is slow |

**System checks** (from `lib/check/all.sh`):

| Group | Checks |
|-------|--------|
| Security | FileVault, Firewall, Gatekeeper, SIP |
| Configuration | Touch ID sudo, Rosetta 2, Git identity |
| Updates | macOS updates, Mole updates |
| Health | Disk space, Memory usage, Swap, Login items, Cache size |

**Layout:**

```
┌──────────────────────────────────────────────────────────────┐
│  Optimize                                       [Dry Run ◻]  │
│                                                               │
│  ┌─ System Checks ──────────────────────────────────────────┐ │
│  │  ✓  FileVault      Disk encryption active                │ │
│  │  ✓  Firewall       Little Snitch active                  │ │
│  │  ✓  Gatekeeper     App security active                   │ │
│  │  ✓  SIP            System integrity protected            │ │
│  │  ⚠  macOS          Update available                      │ │
│  │  ✓  Disk Space     156 GB free                           │ │
│  │  ⚠  Cache Size     8.4 GB cleanable                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─ Optimizations ──────────────────────────────────────────┐ │
│  │  ☑  DNS & Spotlight Check                                │ │
│  │  ☑  Finder Cache Refresh                                 │ │
│  │  ☑  App State Cleanup                                    │ │
│  │  ☑  Broken Config Repair                                 │ │
│  │  ☑  Network Cache Refresh                                │ │
│  │  ☑  Database Optimization                                │ │
│  │  ☑  LaunchServices Repair                                │ │
│  │  ☑  Font Cache Rebuild                                   │ │
│  │  ☑  Dock Refresh                                         │ │
│  │  ☑  Memory Optimization                                  │ │
│  │  ☑  Network Stack Refresh                                │ │
│  │  ☑  Permission Repair                                    │ │
│  │  ☑  Bluetooth Refresh                                    │ │
│  │  ☑  Spotlight Optimization                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  14 optimizations selected                                    │
│              [Cancel]    [Run Optimizations]                   │
└──────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
OptimizeView
├── HStack
│   ├── Text("Optimize").font(.title2).bold()
│   └── Toggle("Dry Run", isOn: $dryRun)
├── ScrollView
│   ├── Section("System Checks")
│   │   └── ForEach(checks)
│   │       └── CheckRow(icon, status, label, detail)
│   └── Section("Optimizations")
│       └── ForEach(optimizations)
│           └── OptimizationRow(
│                 name, description,
│                 isSelected, isWhitelisted,
│                 onToggle, onWhitelistToggle
│               )
├── Divider()
└── HStack
    ├── Text("\(selectedCount) optimizations selected")
    └── Button("Run Optimizations")
```

**Check row states:**

| Icon | Color | Meaning |
|------|-------|---------|
| `checkmark.circle.fill` | `.ok` (green) | Check passed |
| `exclamationmark.triangle.fill` | `.warning` (yellow) | Attention needed |
| `xmark.circle.fill` | `.danger` (red) | Critical issue |
| `minus.circle` | `.subtle` (gray) | Not applicable |

**Whitelist toggle:** Each optimization row has a secondary toggle icon. When whitelisted, the row is dimmed and excluded from "Run Optimizations." Config persists to `~/.config/mole/whitelist_optimize`.

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Loading** | System checks run first (sequential with spinners). Optimization list appears after checks complete. |
| **Populated** | Both sections visible. All optimizations selected by default (unless whitelisted). |
| **Running** | Progress view replaces list. Current optimization name shown. Progress bar: `3 of 14`. Each completed item gets ✓ or ✗. |
| **Complete** | Summary: "Cache cleaned: 340 MB. Databases optimized: 3. Configs repaired: 1." |
| **Dry-run complete** | Summary: "Would apply 14 optimizations." No changes made. |
| **Error** | Per-item error with "Skip" button. Other items continue. |
| **Sudo required** | macOS authentication dialog appears (via `osascript` or Authorization Services). If denied, affected items show "Requires admin." |

**CLI invocations:**

| Action | Command |
|--------|---------|
| Run checks | `mo optimize --dry-run` (parse check output lines) |
| Execute optimizations | `mo optimize` |
| Dry run | `mo optimize --dry-run` |
| Health JSON | Invoke `lib/check/health_json.sh` directly for structured data |

---

### 3.6 Status

**Purpose:** Real-time system metrics dashboard, mirroring the `mo status` TUI.

**CLI:** `mo status` (Go binary `status-go`)

Since `mo status` is a live TUI, the native app collects metrics directly using the same system APIs (via Swift bindings) or by running the Go binary in a headless JSON-output mode.

**Preferred approach:** Native Swift metric collection using:
- `sysctl` for CPU, memory
- `IOKit` for thermal sensors, fan speed, battery
- `DiskArbitration` / `statfs` for disk
- `SystemConfiguration` / `Network.framework` for network
- `IOBluetooth` for Bluetooth devices
- `Process` for top processes (`ps aux`)

**Refresh interval:** 1 second (matching the Go TUI).

**Metric data** (from `MetricsSnapshot`):

| Category | Metrics |
|----------|---------|
| **CPU** | Total usage %, per-core usage, load average (1/5/15), P-core/E-core counts (Apple Silicon) |
| **Memory** | Used/Total GB, usage %, swap used/total, cached, pressure (normal/warn/critical) |
| **GPU** | Per-GPU: name, usage %, memory used/total, core count |
| **Disk** | Per-mount: used/total, usage %, fstype, external flag |
| **Disk I/O** | Read rate MB/s, write rate MB/s |
| **Network** | Per-interface: name, RX/TX rate MB/s, IP. History: 120-sample ring buffer for sparkline. |
| **Battery** | Percent, status (charging/discharging/charged), time left, health, cycle count, max capacity % |
| **Thermal** | CPU temp, GPU temp, fan speed RPM, fan count, system/adapter/battery power (watts) |
| **Bluetooth** | Per-device: name, connected, battery level |
| **Processes** | Top 5-10 by CPU: name, CPU %, memory % |
| **System** | Hostname, platform, uptime, process count, hardware model, OS version |

**Health score** (0-100, calculated identically to Go):

| Component | Weight | Thresholds |
|-----------|--------|------------|
| CPU | 30% | Normal < 30%, High > 70% |
| Memory | 25% | Normal < 50%, High > 80%. Additional penalty for `warn`/`critical` pressure. |
| Disk | 20% | Warn > 70%, Critical > 90% |
| Thermal | 15% | Normal < 60°C, High > 85°C |
| Disk I/O | 10% | Normal < 50 MB/s, High > 150 MB/s |

**Score labels:** 90+ Excellent, 75+ Good, 60+ Fair, 40+ Poor, < 40 Critical.

**Layout:**

```
┌──────────────────────────────────────────────────────────────────┐
│  Status     Health ● 92  MacBook Pro · M4 Pro · 32GB · macOS 15 │
│                                                                   │
│  ┌─ CPU ────────────────────┐  ┌─ Memory ──────────────────────┐ │
│  │ Total ████████████░░ 45% │  │ Used  ███████████░░░░░░░ 58%  │ │
│  │ Load  0.82/1.05/1.23    │  │ 14.2 / 24.0 GB                │ │
│  │ P×6   ████████████░ 63% │  │ Swap  ██░░░░░░░░░░░░░░  2.1GB│ │
│  │ E×4   ███░░░░░░░░░  22% │  │ Pressure: Normal              │ │
│  └──────────────────────────┘  └────────────────────────────────┘ │
│                                                                   │
│  ┌─ Disk ───────────────────┐  ┌─ Network ─────────────────────┐ │
│  │ /     ██████████████ 67% │  │ en0 (Wi-Fi)                   │ │
│  │ 156 GB free              │  │ ↓ 12.4 MB/s  ↑ 2.1 MB/s      │ │
│  │ Read  ▮▯▯▯▯  2.1 MB/s   │  │ ▁▂▃▅▇█▇▅▃▂▁▂▃  (RX history) │ │
│  │ Write ▮▮▯▯▯  4.8 MB/s   │  │ IP: 192.168.1.42             │ │
│  └──────────────────────────┘  └────────────────────────────────┘ │
│                                                                   │
│  ┌─ Battery ────────────────┐  ┌─ Thermal ─────────────────────┐ │
│  │ ██████████████████░ 100% │  │ CPU   42°C                    │ │
│  │ Status: Charged          │  │ GPU   38°C                    │ │
│  │ Health: Normal           │  │ Fans  1,200 RPM (×2)         │ │
│  │ Cycles: 423  Cap: 87%   │  │ Power 8.2W (battery)          │ │
│  └──────────────────────────┘  └────────────────────────────────┘ │
│                                                                   │
│  ┌─ Top Processes ──────────────────────────────────────────────┐ │
│  │  Xcode             34.2% CPU   1.8% MEM                     │ │
│  │  Google Chrome      8.7% CPU   4.2% MEM                     │ │
│  │  Slack              3.1% CPU   2.1% MEM                     │ │
│  │  Finder             1.2% CPU   0.4% MEM                     │ │
│  │  WindowServer       0.9% CPU   0.3% MEM                     │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─ Bluetooth ──────────────────────────────────────────────────┐ │
│  │  AirPods Pro        Connected   🔋 82%                       │ │
│  │  Magic Keyboard     Connected   🔋 64%                       │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
StatusView
├── HStack (header)
│   ├── Text("Status").font(.title2).bold()
│   ├── HealthScoreBadge(score: healthScore, message: healthMsg)
│   └── Text(hardwareInfo).foregroundStyle(.secondary)
├── ScrollView
│   └── LazyVGrid(columns: 2, spacing: 16)
│       ├── MetricCard("CPU")
│       │   ├── ProgressBar(cpuUsage, label: "Total")
│       │   ├── Text(loadAverage)
│       │   └── ForEach(perCoreGroups) { CoreBar }
│       ├── MetricCard("Memory")
│       │   ├── ProgressBar(memUsage, label: "Used")
│       │   ├── Text("\(used) / \(total) GB")
│       │   ├── ProgressBar(swapUsage, label: "Swap")
│       │   └── Text("Pressure: \(pressure)")
│       ├── MetricCard("Disk")
│       │   ├── ForEach(disks) { ProgressBar }
│       │   ├── Text("\(free) GB free")
│       │   ├── IOBar(read, label: "Read")
│       │   └── IOBar(write, label: "Write")
│       ├── MetricCard("Network")
│       │   ├── ForEach(interfaces) { ... }
│       │   ├── Text("↓ \(rx) MB/s  ↑ \(tx) MB/s")
│       │   └── SparklineChart(rxHistory)
│       ├── MetricCard("Battery")  // conditional: only if battery present
│       │   ├── ProgressBar(percent)
│       │   ├── Text(status)
│       │   └── Text("Cycles: \(cycles)  Cap: \(capacity)%")
│       └── MetricCard("Thermal")
│           ├── Text("CPU \(cpuTemp)°C")
│           ├── Text("GPU \(gpuTemp)°C")
│           └── Text("Fans \(speed) RPM")
├── Section("Top Processes")  // full-width
│   └── Table(topProcesses, columns: [name, cpu, memory])
└── Section("Bluetooth")  // conditional
    └── ForEach(bluetoothDevices) { BluetoothRow }
```

**Sparkline chart:** Renders the 120-sample ring buffer as a mini area chart using SwiftUI `Path`. X-axis is time (120 seconds), Y-axis auto-scales to peak value.

**Color coding for gauges:**

| Range | Color |
|-------|-------|
| 0–50% | `.ok` (green `#A5D6A7`) |
| 50–80% | `.warning` (yellow `#FFD75F`) |
| 80–100% | `.danger` (red `#FF5F5F`) |

**Memory pressure badge:**

| Value | Badge |
|-------|-------|
| `normal` | `StatusBadge(.ok, "Normal")` |
| `warn` | `StatusBadge(.warning, "Warning")` |
| `critical` | `StatusBadge(.danger, "Critical")` |

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Connecting** | "Collecting metrics..." with shimmer placeholders for each card. |
| **Live** | All cards update every 1 second. Smooth gauge animations using `withAnimation(.linear(duration: 0.3))`. |
| **Paused** | When window is not visible, collection pauses to save resources. Resumes on window focus. |
| **Error** | Individual card shows "Unavailable" with gray styling. Other cards continue updating. |

---

### 3.7 Purge

**Purpose:** Remove old build artifacts from project directories.

**CLI:** `mo purge [--paths] [--debug]`

**Default scan paths:**
- `~/Projects`
- `~/GitHub`
- `~/dev`

**Custom paths:** `~/.config/mole/purge_paths` (newline-separated directories)

**Artifact types detected:** `node_modules`, `target` (Rust), `build`, `dist`, `venv`, `.venv`, `__pycache__`, `.next`, `.nuxt`, `.svelte-kit`, `.gradle`, `.cache`, `vendor` (Go/PHP), `Pods` (CocoaPods), `DerivedData`, and 150+ others.

**Layout:**

```
┌──────────────────────────────────────────────────────────────┐
│  Purge                                                        │
│                                                               │
│  Scanning: ~/Projects, ~/GitHub, ~/dev                        │
│                                                               │
│  ☑  my-web-app/node_modules ................... 340 MB       │
│  ☑  rust-project/target ....................... 1.2 GB       │
│  ☑  python-ml/venv ............................ 890 MB       │
│  ☐  ios-app/DerivedData ....................... 2.4 GB       │
│  ☑  next-site/.next ........................... 210 MB       │
│  ☑  old-project/node_modules .................. 520 MB       │
│  ☐  api-server/dist ........................... 45 MB        │
│  ...                                                          │
│                                                               │
│  ──────────────────────────────────────────────────────────   │
│  Selected: 5 artifacts (3.16 GB)                              │
│                                                               │
│           [Cancel]    [Purge Selected]                        │
└──────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
PurgeView
├── Text("Purge").font(.title2).bold()
├── Text("Scanning: \(scanPaths.joined(separator: ", "))")
│       .foregroundStyle(.secondary)
├── ScrollView
│   └── ForEach(artifacts)
│       └── FileRow(
│             projectName + "/" + artifactName,
│             size,
│             isSelected,
│             onToggle
│           )
├── Divider()
├── HStack
│   ├── Text("Selected: \(count) artifacts (\(size))")
│   └── Spacer()
└── HStack
    ├── Button("Cancel")
    └── Button("Purge Selected", role: .destructive)
```

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Scanning** | "Scanning projects..." with spinner. Items appear incrementally as found. |
| **Populated** | Full list. Items sorted by size (largest first). |
| **Purging** | Progress overlay: "Purging 5 artifacts..." with current item name and progress bar. |
| **Complete** | "Purged 5 artifacts, freed 3.16 GB." |
| **Empty** | `EmptyState(message: "No build artifacts found in scan directories.")` with a "Configure Paths" button linking to Settings. |
| **Error** | Per-item error inline with skip option. |

**Confirmation dialog:**

```
┌────────────────────────────────────────────────────┐
│  ⚠ Purge 5 Build Artifacts (3.16 GB)?             │
│                                                    │
│  This will permanently delete:                     │
│  • node_modules (2 directories)                    │
│  • target (1 directory)                            │
│  • venv (1 directory)                              │
│  • .next (1 directory)                             │
│                                                    │
│  Projects can regenerate these by reinstalling      │
│  dependencies or rebuilding.                        │
│                                                    │
│           [Cancel]    [Purge]                      │
└────────────────────────────────────────────────────┘
```

---

### 3.8 Installers

**Purpose:** Find and remove installer files (.dmg, .pkg, etc.).

**CLI:** `mo installer [--debug]`

**File types:** `.dmg`, `.pkg`, `.mpkg`, `.iso`, `.xip`, `.zip`

**Scan paths:**
- `~/Downloads`, `~/Desktop`, `~/Documents`, `~/Public`
- `~/Library/Downloads`
- `/Users/Shared`, `/Users/Shared/Downloads`
- `~/Library/Caches/Homebrew`
- `~/Library/Mobile Documents/com~apple~CloudDocs/Downloads` (iCloud)
- `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads`
- Telegram Desktop folders

**Scan depth:** 2 levels.

**Layout:**

```
┌──────────────────────────────────────────────────────────────┐
│  Installers                                                   │
│                                                               │
│  ☑  Xcode_15.xip ................. 6.1 GB   Downloads        │
│  ☑  Docker.dmg ................... 1.2 GB   Downloads        │
│  ☐  macOS_Sonoma.pkg ............. 13.4 GB  Shared           │
│  ☑  node-v20.pkg ................. 42 MB    Downloads        │
│  ☑  Slack-4.35.dmg ............... 180 MB   Downloads        │
│  ☑  homebrew-core.zip ............ 340 MB   Homebrew Cache   │
│  ...                                                          │
│                                                               │
│  ──────────────────────────────────────────────────────────   │
│  Selected: 5 files (7.86 GB)                                  │
│                                                               │
│           [Cancel]    [Delete Selected]                       │
└──────────────────────────────────────────────────────────────┘
```

**Component hierarchy:**

```
InstallersView
├── Text("Installers").font(.title2).bold()
├── ScrollView
│   └── ForEach(installers)
│       └── FileRow(
│             fileName, size,
│             sourceLabel,   // "Downloads", "Homebrew Cache", etc.
│             isSelected,
│             onToggle
│           )
├── Divider()
├── HStack
│   ├── Text("Selected: \(count) files (\(size))")
│   └── Spacer()
└── HStack
    ├── Button("Cancel")
    └── Button("Delete Selected", role: .destructive)
```

**Source labels** (derived from parent path):

| Path contains | Label |
|---------------|-------|
| `~/Downloads` | Downloads |
| `~/Desktop` | Desktop |
| `~/Documents` | Documents |
| `/Users/Shared` | Shared |
| `Homebrew` | Homebrew Cache |
| `CloudDocs` | iCloud |
| `Mail Downloads` | Mail |
| `Telegram` | Telegram |

**Interaction states:**

| State | Behaviour |
|-------|-----------|
| **Scanning** | "Scanning for installer files..." with spinner. Items appear as found. |
| **Populated** | Full list sorted by size. All items selected by default. |
| **Deleting** | Progress: "Deleting 5 files..." with progress bar. |
| **Complete** | "Deleted 5 installer files, freed 7.86 GB." |
| **Empty** | `EmptyState(message: "No installer files found.")` |
| **Error** | Per-file error inline. |

**Confirmation dialog:**

```
┌────────────────────────────────────────────────────┐
│  ⚠ Delete 5 Installer Files (7.86 GB)?            │
│                                                    │
│  This will permanently delete the selected         │
│  installer files. Downloaded apps are not affected. │
│                                                    │
│           [Cancel]    [Delete]                     │
└────────────────────────────────────────────────────┘
```

---

### 3.9 Settings (Sheet)

**Presented as:** `.sheet` from sidebar footer gear icon.

**Sections:**

```
┌──────────────────────────────────────────────────────┐
│  Settings                                     [Done] │
│                                                      │
│  ─── General ───                                     │
│  CLI Path          /usr/local/bin/mo        [Browse] │
│  Debug Mode        ◻                                 │
│  Check for Updates ☑  (on launch)                    │
│                                                      │
│  ─── Clean Whitelist ───                             │
│  ~/.config/mole/whitelist                            │
│  /path/to/protected/dir1                       [✕]   │
│  /path/to/protected/dir2                       [✕]   │
│  [+ Add Path]                                        │
│                                                      │
│  Protected (read-only):                              │
│  Playwright browsers                                 │
│  HuggingFace models                                  │
│  Ollama models                                       │
│  Maven repository                                    │
│                                                      │
│  ─── Optimize Whitelist ───                          │
│  ~/.config/mole/whitelist_optimize                   │
│  check_touchid                                 [✕]   │
│  [+ Add Rule]                                        │
│                                                      │
│  ─── Purge Paths ───                                 │
│  ~/.config/mole/purge_paths                          │
│  ~/Projects                                    [✕]   │
│  ~/GitHub                                      [✕]   │
│  ~/dev                                         [✕]   │
│  [+ Add Directory]                                   │
│                                                      │
│  ─── About ───                                       │
│  Mole v1.23.2                                        │
│  [Check for Updates]  [View on GitHub]               │
└──────────────────────────────────────────────────────┘
```

**Config file mapping:**

| Setting | File |
|---------|------|
| Clean whitelist | `~/.config/mole/whitelist` |
| Optimize whitelist | `~/.config/mole/whitelist_optimize` |
| Purge paths | `~/.config/mole/purge_paths` |
| Status preferences | `~/.config/mole/status_prefs` |
| Operation log | `~/.config/mole/operations.log` (read-only view) |

---

## 4. Component Library

### 4.1 ProgressBar

Horizontal gauge bar with label and percentage.

```swift
struct ProgressBar: View {
    let value: Double        // 0.0–1.0
    let label: String        // "Total", "Used", etc.
    var showPercentage: Bool = true
    var barHeight: CGFloat = 8
    var tint: Color?         // nil = auto from value
}
```

**Auto-tint logic:**
- `value` < 0.5 → `.ok`
- `value` < 0.8 → `.warning`
- `value` >= 0.8 → `.danger`

**Rendering:** Rounded capsule, background is `Color(.separatorColor)`, fill is tint color. Percentage label is right-aligned monospaced text.

### 4.2 MetricCard

Rounded container for a group of related metrics.

```swift
struct MetricCard<Content: View>: View {
    let title: String
    let icon: String         // SF Symbol name
    @ViewBuilder var content: () -> Content
}
```

**Rendering:** `GroupBox`-style with title row (icon + label) and content below. Corner radius 10. Background: `.background` material.

### 4.3 SizeLabel

Formatted file size display with adaptive units.

```swift
struct SizeLabel: View {
    let bytes: Int64
    var style: Font = .body
}
```

**Formatting rules:**
- < 1 KB → "\(bytes) B"
- < 1 MB → "\(bytes/1024) KB"
- < 1 GB → "\(bytes/1048576, specifier: "%.1f") MB"
- >= 1 GB → "\(bytes/1073741824, specifier: "%.2f") GB"

### 4.4 StatusBadge

Colored pill label indicating status.

```swift
struct StatusBadge: View {
    enum Variant { case ok, warning, danger, info, dryRun }
    let variant: Variant
    let text: String
}
```

**Colors per variant:**

| Variant | Background | Foreground |
|---------|------------|------------|
| `.ok` | `#A5D6A7` @ 20% | `#A5D6A7` |
| `.warning` | `#FFD75F` @ 20% | `#FFD75F` |
| `.danger` | `#FF5F5F` @ 20% | `#FF5F5F` |
| `.info` | `#BD93F9` @ 20% | `#BD93F9` |
| `.dryRun` | `#737373` @ 20% | `#737373` |

**Rendering:** Capsule shape, small font, horizontal padding 8pt, vertical padding 3pt.

### 4.5 CategoryRow

Selectable row for clean/optimize categories.

```swift
struct CategoryRow: View {
    let name: String
    let size: Int64
    let isSelected: Bool
    let onToggle: () -> Void
    var isExpanded: Bool = false
    var onExpand: (() -> Void)? = nil
}
```

**Rendering:** Checkbox → name → dotted leader → `SizeLabel`. Optional disclosure chevron for expansion.

### 4.6 AppRow

Application entry for uninstall list.

```swift
struct AppRow: View {
    let name: String
    let icon: NSImage?       // loaded from app bundle
    let size: Int64
    let isOld: Bool          // > 90 days since last opened
    let isSelected: Bool
}
```

**Rendering:** Checkbox → 32×32 app icon → name → Spacer → `SizeLabel` → optional `StatusBadge(.warning, "Old")`.

### 4.7 FileRow

Generic file/directory entry for analyze, purge, installers.

```swift
struct FileRow: View {
    let name: String
    let size: Int64
    let subtitle: String     // parent path, source label, etc.
    let isSelected: Bool
    let onToggle: () -> Void
}
```

### 4.8 ConfirmationDialog

Destructive action confirmation sheet.

```swift
struct ConfirmationDialog: View {
    let title: String
    let message: String
    let items: [String]?       // optional bullet list
    let confirmLabel: String   // "Clean", "Uninstall", "Delete", "Purge"
    let onConfirm: () -> Void
    let onCancel: () -> Void
}
```

**Rendering:** Alert-style sheet with icon (warning triangle), title, message body, optional item list, Cancel + destructive Confirm buttons.

### 4.9 EmptyState

Placeholder for screens with no data.

```swift
struct EmptyState: View {
    let icon: String         // SF Symbol
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
}
```

**Rendering:** Centered vertically. Large icon (48pt) in `.secondary`, message text below, optional action button.

### 4.10 SearchBar

Text field with magnifying glass icon and clear button.

```swift
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
}
```

**Rendering:** Uses `TextField` with `RoundedBorderTextFieldStyle()`. Leading `magnifyingglass` icon. Trailing `xmark.circle.fill` when text is non-empty.

### 4.11 SparklineChart

Mini line/area chart for network history.

```swift
struct SparklineChart: View {
    let data: [Double]       // ring buffer slice, oldest → newest
    var color: Color = .accentColor
    var height: CGFloat = 32
}
```

**Rendering:** SwiftUI `Path` drawing an area chart. Y-axis auto-scales to `max(data)`. Fill is `color` at 30% opacity, stroke is `color` at full opacity.

### 4.12 HealthScoreBadge

Circular health indicator with score number.

```swift
struct HealthScoreBadge: View {
    let score: Int           // 0–100
    let message: String      // "Excellent", "Good: High CPU", etc.
}
```

**Score color:**
- 90+ → `.ok`
- 75+ → `Color(#A5D6A7)` blended toward `.warning`
- 60+ → `.warning`
- 40+ → `Color(#FFD75F)` blended toward `.danger`
- < 40 → `.danger`

**Rendering:** Filled circle (16pt diameter) in score color, score number in bold, message text in secondary.

---

## 5. Design Tokens

### 5.1 Color Palette

All colors support both light and dark mode via `Color(.init(name:))` or asset catalog entries.

**Brand colors:**

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `brand.primary` | `#BD93F9` | `#BD93F9` | Accent, sidebar selection, primary buttons |
| `brand.primaryLight` | `#C79FD7` | `#C79FD7` | Headers, title styling |

**Semantic colors:**

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `semantic.ok` | `#2E7D32` | `#A5D6A7` | Success states, passing checks |
| `semantic.warning` | `#F9A825` | `#FFD75F` | Attention needed, old apps |
| `semantic.danger` | `#C62828` | `#FF5F5F` | Errors, critical states, destructive buttons |
| `semantic.info` | `#7B1FA2` | `#BD93F9` | Informational badges |
| `semantic.dryRun` | `#616161` | `#737373` | Dry-run mode indicators |

**Surface colors:**

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `surface.primary` | system background | system background | Main content area |
| `surface.secondary` | `Color(.controlBackgroundColor)` | `Color(.controlBackgroundColor)` | Cards, grouped content |
| `surface.sidebar` | `Color(.windowBackgroundColor)` | `Color(.windowBackgroundColor)` | Sidebar background |

**Text colors:**

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `text.primary` | `Color(.labelColor)` | `Color(.labelColor)` | Primary content |
| `text.secondary` | `Color(.secondaryLabelColor)` | `Color(.secondaryLabelColor)` | Subtitles, metadata |
| `text.subtle` | `#737373` | `#737373` | Disabled, placeholder |
| `text.line` | `#D0D0D0` | `#404040` | Dividers, separators |

### 5.2 Typography Scale

Uses the system font (SF Pro) throughout.

| Token | Style | Size | Weight | Usage |
|-------|-------|------|--------|-------|
| `type.title` | `.title2` | 22pt | `.bold` | Screen titles |
| `type.heading` | `.headline` | 17pt | `.semibold` | Section headers |
| `type.body` | `.body` | 13pt | `.regular` | Content text |
| `type.callout` | `.callout` | 12pt | `.regular` | Descriptions |
| `type.caption` | `.caption` | 11pt | `.regular` | Metadata, timestamps |
| `type.metric` | `.body` | 13pt | `.monospaced` | Numbers, sizes, percentages |
| `type.metricLarge` | `.title3` | 20pt | `.monospaced` + `.bold` | Health score, large numbers |

### 5.3 Spacing System

Based on a 4pt grid:

| Token | Value | Usage |
|-------|-------|-------|
| `space.xs` | 4pt | Inline padding, between badge and text |
| `space.sm` | 8pt | Between related elements, list item padding |
| `space.md` | 12pt | Section padding, card internal margin |
| `space.lg` | 16pt | Between sections, grid gap |
| `space.xl` | 24pt | Screen margins, major section gaps |
| `space.xxl` | 32pt | Empty state padding |

### 5.4 Icon Set (SF Symbols)

| Concept | SF Symbol | Usage |
|---------|-----------|-------|
| Dashboard | `gauge.with.dots.needle.bottom.50percent` | Sidebar |
| Clean | `trash` | Sidebar, quick action |
| Uninstall | `xmark.app` | Sidebar |
| Analyze | `chart.bar.doc.horizontal` | Sidebar |
| Optimize | `wrench.and.screwdriver` | Sidebar, quick action |
| Status | `waveform.path.ecg.rectangle` | Sidebar, quick action |
| Purge | `folder.badge.minus` | Sidebar, quick action |
| Installers | `doc.zipper` | Sidebar |
| Settings | `gearshape` | Sidebar footer |
| Success | `checkmark.circle.fill` | Check results |
| Warning | `exclamationmark.triangle.fill` | Attention items |
| Error | `xmark.circle.fill` | Failed items |
| Info | `info.circle` | Informational |
| Search | `magnifyingglass` | Search bar |
| Folder | `folder.fill` | Directory entries |
| File | `doc.fill` | File entries |
| App | `app.fill` | App entries (fallback icon) |
| Refresh | `arrow.clockwise` | Refresh buttons |
| Back | `chevron.left` | Navigation |
| Expand | `chevron.right` | Disclosure |
| CPU | `cpu` | Status card |
| Memory | `memorychip` | Status card |
| Disk | `internaldrive` | Status card |
| Network | `network` | Status card |
| Battery | `battery.100` | Status card |
| Thermal | `thermometer.medium` | Status card |
| Bluetooth | `wave.3.right` | Status card |
| Process | `list.number` | Top processes |

---

## 6. CLI Integration Layer

### 6.1 CLIBridge Actor

```swift
actor CLIBridge {
    /// Resolved path to the `mo` binary.
    let moPath: String

    /// Run a command synchronously, returning stdout.
    func run(_ arguments: [String]) async throws -> String

    /// Run a command with streaming stdout line-by-line.
    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error>

    /// Run a command with admin privileges.
    func runPrivileged(_ arguments: [String]) async throws -> String
}
```

### 6.2 Command Execution

```swift
// Internal implementation uses Process (NSTask)
private func execute(
    _ arguments: [String],
    environment: [String: String] = [:]
) async throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: moPath)
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment
        .merging(environment) { _, new in new }

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    // ... collect output, wait for termination
}
```

**Environment variables passed:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `MOLE_DRY_RUN` | `1` | Enable dry-run mode |
| `MO_DEBUG` | `1` | Enable debug logging |
| `MO_NO_OPLOG` | `1` | Disable operation logging (if needed) |
| `MO_ANALYZE_PATH` | `<path>` | Override analyze target path |
| `TERM` | `dumb` | Prevent ANSI escape codes in output |
| `NO_COLOR` | `1` | Disable colored output for parsing |

### 6.3 Output Parsing

CLI output uses structured text patterns. The parser strips ANSI codes and matches:

```swift
enum CLIOutputLine {
    /// ✓ Label     Description
    case success(label: String, detail: String)

    /// ⚠ Label     Description
    case warning(label: String, detail: String)

    /// ✗ Label     Description
    case error(label: String, detail: String)

    /// Plain text line
    case text(String)

    /// Summary line: "Space freed: 95.5GB | Free space now: 223.5GB"
    case summary(freed: String, freeSpace: String)
}
```

**ANSI stripping regex:** `\x1B\[[0-9;]*[a-zA-Z]`

**Health JSON parsing:** The `generate_health_json` function in `lib/check/health_json.sh` outputs JSON directly. Parse with `JSONDecoder`.

### 6.4 Progress Tracking

For long-running commands (`clean`, `uninstall`, `purge`), progress is tracked by streaming stdout:

```swift
func trackProgress(_ arguments: [String]) -> AsyncThrowingStream<ProgressUpdate, Error> {
    stream(arguments).compactMap { line in
        // Parse each line into a ProgressUpdate
        // e.g., "  ✓ Browser caches     2.1 GB"
        //       → ProgressUpdate(category: "Browser caches", size: 2.1GB, status: .done)
    }
}
```

### 6.5 Privilege Escalation

Commands requiring root (parts of `mo optimize`) use Authorization Services:

```swift
func runPrivileged(_ arguments: [String]) async throws -> String {
    // Option A: osascript
    let script = "do shell script \"\(moPath) \(arguments.joined(separator: " "))\" with administrator privileges"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    // ...

    // Option B: Authorization Services (preferred for better UX)
    // Use AuthorizationCreate + AuthorizationExecuteWithPrivileges
    // or SMJobBless for a privileged helper tool.
}
```

**When sudo is needed:**
- `mo optimize` (network services, launch daemons, memory purge, Bluetooth reset)
- Firewall check (`/usr/libexec/ApplicationFirewall/socketfilterfw`)
- Some system-level clean operations

### 6.6 Dry-Run Mode

Dry-run is a UI toggle (available on Clean and Optimize screens) that sets the `MOLE_DRY_RUN=1` environment variable. The CLI prints what it would do with `⚠` prefixed lines instead of `✓` lines. The parser differentiates these and the UI shows:
- `StatusBadge(.dryRun)` on the screen header
- "Would" language in summary: "Would free 41.8 GB" instead of "Freed 41.8 GB"
- No confirmation dialog required for dry-run

---

## 7. State Management

### 7.1 App-Level State

```swift
@Observable
final class AppState {
    /// Currently selected sidebar item.
    var selectedSection: SidebarSection = .dashboard

    /// Global preferences.
    var preferences: AppPreferences

    /// Active background tasks.
    var backgroundTasks: [TaskID: TaskState] = [:]

    /// Notification/alert queue.
    var alerts: [AppAlert] = []

    /// Whether a privileged operation is pending.
    var awaitingSudo: Bool = false
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard, clean, uninstall, analyze, optimize, status, purge, installers
    var id: String { rawValue }
}
```

### 7.2 Per-Screen State Machines

Each screen follows a consistent state machine:

```
idle → loading → populated
                    ↓
              [user action]
                    ↓
              confirming → executing → complete
                                         ↓
                                    [dismiss]
                                         ↓
                                   populated (refreshed)

Any state → error → [retry] → loading
```

**Clean screen state:**

```swift
@Observable
final class CleanState {
    enum Phase {
        case idle
        case calculating          // Running --dry-run to get sizes
        case ready(categories: [CleanCategory])
        case confirming           // Showing confirmation dialog
        case cleaning(progress: CleanProgress)
        case complete(summary: CleanSummary)
        case error(Error)
    }

    var phase: Phase = .idle
    var dryRun: Bool = false
    var selectedCategories: Set<String> = []
}
```

**Uninstall screen state:**

```swift
@Observable
final class UninstallState {
    enum Phase {
        case idle
        case scanning             // Scanning /Applications
        case ready(apps: [AppEntry])
        case confirming
        case removing(progress: RemoveProgress)
        case complete(summary: RemoveSummary)
        case error(Error)
    }

    var phase: Phase = .idle
    var searchText: String = ""
    var sortOrder: SortOrder = .size
    var selectedApps: Set<String> = []
    var focusedApp: AppEntry? = nil
}
```

**Analyze screen state:**

```swift
@Observable
final class AnalyzeState {
    enum Phase {
        case idle
        case scanning(progress: ScanProgress)
        case populated(entries: [AnalyzeEntry], largeFiles: [LargeFile])
        case deleting(progress: DeleteProgress)
        case error(Error)
    }

    var phase: Phase = .idle
    var currentPath: String = "/"
    var history: [HistoryEntry] = []
    var showLargeFiles: Bool = true
    var multiSelected: Set<String> = []
}
```

**Optimize screen state:**

```swift
@Observable
final class OptimizeState {
    enum Phase {
        case idle
        case checking             // Running system checks
        case ready(checks: [CheckResult], optimizations: [Optimization])
        case confirming
        case running(progress: OptimizeProgress)
        case complete(summary: OptimizeSummary)
        case error(Error)
    }

    var phase: Phase = .idle
    var dryRun: Bool = false
    var selectedOptimizations: Set<String> = []
}
```

**Status screen state:**

```swift
@Observable
final class StatusState {
    var isCollecting: Bool = false
    var metrics: MetricsSnapshot? = nil
    var error: Error? = nil
    var isPaused: Bool = false   // True when window not visible
}
```

**Purge screen state:**

```swift
@Observable
final class PurgeState {
    enum Phase {
        case idle
        case scanning
        case ready(artifacts: [BuildArtifact])
        case confirming
        case purging(progress: PurgeProgress)
        case complete(summary: PurgeSummary)
        case error(Error)
    }

    var phase: Phase = .idle
    var selectedArtifacts: Set<String> = []
}
```

**Installers screen state:**

```swift
@Observable
final class InstallersState {
    enum Phase {
        case idle
        case scanning
        case ready(files: [InstallerFile])
        case confirming
        case deleting(progress: DeleteProgress)
        case complete(summary: DeleteSummary)
        case error(Error)
    }

    var phase: Phase = .idle
    var selectedFiles: Set<String> = []
}
```

### 7.3 Background Task Tracking

```swift
struct TaskState: Identifiable {
    let id: UUID
    let kind: TaskKind
    var status: TaskStatus
    var progress: Double       // 0.0–1.0
    var message: String

    enum TaskKind { case clean, uninstall, optimize, purge, delete }
    enum TaskStatus { case running, completed, failed, cancelled }
}
```

Active tasks are shown as a subtle progress indicator in the toolbar. If the user navigates away from a screen with an active task, the task continues in the background and the toolbar indicator remains.

### 7.4 Alert Queue

```swift
struct AppAlert: Identifiable {
    let id: UUID
    let level: AlertLevel
    let title: String
    let message: String
    var action: (() -> Void)? = nil

    enum AlertLevel { case info, warning, error }
}
```

Alerts are presented as macOS-native `.alert` modifiers, dequeued one at a time.

---

## 8. Data Models

### 8.1 Health JSON Model

Matches the output of `lib/check/health_json.sh`:

```swift
struct HealthJSON: Codable {
    let memoryUsedGB: Double
    let memoryTotalGB: Double
    let diskUsedGB: Double
    let diskTotalGB: Double
    let diskUsedPercent: Double
    let uptimeDays: Double
    let optimizations: [HealthOptimization]

    enum CodingKeys: String, CodingKey {
        case memoryUsedGB = "memory_used_gb"
        case memoryTotalGB = "memory_total_gb"
        case diskUsedGB = "disk_used_gb"
        case diskTotalGB = "disk_total_gb"
        case diskUsedPercent = "disk_used_percent"
        case uptimeDays = "uptime_days"
        case optimizations
    }
}

struct HealthOptimization: Codable, Identifiable {
    var id: String { action }
    let category: String
    let name: String
    let description: String
    let action: String
    let safe: Bool
}
```

### 8.2 Metrics Snapshot (Swift Mirror of Go Types)

```swift
struct MetricsSnapshot {
    let collectedAt: Date
    let host: String
    let platform: String
    let uptime: String
    let processCount: UInt64
    let hardware: HardwareInfo
    let healthScore: Int          // 0–100
    let healthScoreMessage: String

    let cpu: CPUStatus
    let gpu: [GPUStatus]
    let memory: MemoryStatus
    let disks: [DiskStatus]
    let diskIO: DiskIOStatus
    let network: [NetworkStatus]
    let networkHistory: NetworkHistory
    let proxy: ProxyStatus
    let batteries: [BatteryStatus]
    let thermal: ThermalStatus
    let sensors: [SensorReading]
    let bluetooth: [BluetoothDevice]
    let topProcesses: [ProcessInfo]
}

struct HardwareInfo {
    let model: String           // "MacBook Pro 14-inch, 2021"
    let cpuModel: String        // "Apple M1 Pro"
    let totalRAM: String        // "16GB"
    let diskSize: String        // "512GB"
    let osVersion: String       // "macOS Sonoma 14.5"
    let refreshRate: String     // "120Hz"
}

struct CPUStatus {
    let usage: Double
    let perCore: [Double]
    let perCoreEstimated: Bool
    let load1: Double
    let load5: Double
    let load15: Double
    let coreCount: Int
    let logicalCPU: Int
    let pCoreCount: Int         // Performance (Apple Silicon)
    let eCoreCount: Int         // Efficiency (Apple Silicon)
}

struct GPUStatus: Identifiable {
    let id = UUID()
    let name: String
    let usage: Double
    let memoryUsed: Double
    let memoryTotal: Double
    let coreCount: Int
    let note: String
}

struct MemoryStatus {
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let swapUsed: UInt64
    let swapTotal: UInt64
    let cached: UInt64
    let pressure: MemoryPressure

    enum MemoryPressure: String {
        case normal, warn, critical
    }
}

struct DiskStatus: Identifiable {
    let id = UUID()
    let mount: String
    let device: String
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let fstype: String
    let external: Bool
}

struct DiskIOStatus {
    let readRate: Double        // MB/s
    let writeRate: Double       // MB/s
}

struct NetworkStatus: Identifiable {
    let id = UUID()
    let name: String
    let rxRateMBs: Double
    let txRateMBs: Double
    let ip: String
}

struct NetworkHistory {
    let rxHistory: [Double]     // Ring buffer slice (oldest → newest)
    let txHistory: [Double]
}

struct ProxyStatus {
    let enabled: Bool
    let type: String            // "HTTP", "SOCKS", "System"
    let host: String
}

struct BatteryStatus {
    let percent: Double
    let status: String          // "Charging", "Discharging", "Charged"
    let timeLeft: String
    let health: String
    let cycleCount: Int
    let capacity: Int           // Max capacity % of original
}

struct ThermalStatus {
    let cpuTemp: Double
    let gpuTemp: Double
    let fanSpeed: Int           // RPM
    let fanCount: Int
    let systemPower: Double     // Watts
    let adapterPower: Double    // Watts
    let batteryPower: Double    // Watts
}

struct SensorReading: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let unit: String
    let note: String
}

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let connected: Bool
    let battery: String
}

struct ProcessInfo: Identifiable {
    let id = UUID()
    let name: String
    let cpu: Double
    let memory: Double
}
```

### 8.3 Screen-Specific Models

```swift
// Clean
struct CleanCategory: Identifiable {
    let id: String              // "app_caches", "browser_caches", etc.
    let name: String
    let size: Int64
    var isSelected: Bool
    let module: String          // "app_caches.sh", "caches.sh", etc.
}

struct CleanSummary {
    let totalFreed: Int64
    let freeSpaceNow: Int64
    let categoriesCleaned: Int
    let filesRemoved: Int
    let isDryRun: Bool
}

// Uninstall
struct AppEntry: Identifiable {
    let id: String              // Bundle identifier or path
    let name: String
    let icon: NSImage?
    let bundlePath: String
    let size: Int64
    let lastOpened: Date?
    let isOld: Bool             // > 90 days since last opened
    let version: String?
    let associatedFiles: [AssociatedFile]
}

struct AssociatedFile {
    let kind: String            // "Application Support", "Caches", etc.
    let path: String
    let size: Int64
}

// Analyze
struct AnalyzeEntry: Identifiable {
    let id: String              // Absolute path
    let name: String
    let path: String
    let size: Int64
    let isDir: Bool
    let lastAccess: Date
    var percentage: Double      // Of parent total
}

struct LargeFile: Identifiable {
    let id: String              // Absolute path
    let name: String
    let path: String
    let size: Int64
}

struct HistoryEntry {
    let path: String
    let entries: [AnalyzeEntry]
    let largeFiles: [LargeFile]
    let totalSize: Int64
    let totalFiles: Int64
    let scrollPosition: Int
}

// Optimize
struct CheckResult: Identifiable {
    let id: String
    let group: CheckGroup
    let label: String
    let detail: String
    let status: CheckStatus

    enum CheckGroup { case security, configuration, updates, health }
    enum CheckStatus { case pass, warning, fail, neutral }
}

struct Optimization: Identifiable {
    let id: String              // action key
    let name: String
    let description: String
    let category: String
    let safe: Bool
    var isSelected: Bool
    var isWhitelisted: Bool
}

struct OptimizeSummary {
    let cacheCleanedBytes: Int64
    let databasesOptimized: Int
    let configsRepaired: Int
    let isDryRun: Bool
}

// Purge
struct BuildArtifact: Identifiable {
    let id: String              // Absolute path
    let projectName: String
    let artifactName: String    // "node_modules", "target", etc.
    let path: String
    let size: Int64
    var isSelected: Bool
}

// Installers
struct InstallerFile: Identifiable {
    let id: String              // Absolute path
    let name: String
    let path: String
    let size: Int64
    let sourceLabel: String     // "Downloads", "Homebrew Cache", etc.
    let fileType: String        // "dmg", "pkg", etc.
    var isSelected: Bool
}
```

### 8.4 Preferences

```swift
struct AppPreferences: Codable {
    var cliPath: String = "/usr/local/bin/mo"
    var debugMode: Bool = false
    var checkForUpdatesOnLaunch: Bool = true
    var cleanWhitelist: [String] = []
    var optimizeWhitelist: [String] = []
    var purgePaths: [String] = ["~/Projects", "~/GitHub", "~/dev"]
}
```

Persisted to `UserDefaults` (for app-level prefs) and the respective config files (for CLI-shared config):
- `~/.config/mole/whitelist`
- `~/.config/mole/whitelist_optimize`
- `~/.config/mole/purge_paths`

Changes in the UI are written back to these files so the CLI and app share configuration.

---

## Appendix: CLI Command Coverage Matrix

| CLI Command | Flags | UI Screen | Covered |
|-------------|-------|-----------|---------|
| `mo clean` | `--dry-run`, `--whitelist`, `--debug` | Clean | Yes |
| `mo uninstall` | `--debug` | Uninstall | Yes |
| `mo optimize` | `--dry-run`, `--whitelist`, `--debug` | Optimize | Yes |
| `mo analyze [PATH]` | — | Analyze | Yes |
| `mo status` | — | Status | Yes |
| `mo purge` | `--paths`, `--debug` | Purge | Yes |
| `mo installer` | `--debug` | Installers | Yes |
| `mo touchid` | — | Settings (link to terminal) | Partial — show status in Optimize checks |
| `mo completion` | — | — | N/A (CLI-only) |
| `mo update` | `--force` | Settings → Check for Updates | Yes |
| `mo remove` | — | — | N/A (removes CLI) |
| `mo help` | — | — | N/A (CLI-only) |
| `mo version` | — | Settings → About | Yes |

### Flag Coverage

| Flag | Screens | UI Element |
|------|---------|------------|
| `--dry-run` | Clean, Optimize | Toggle switch in header |
| `--whitelist` | Clean, Optimize | Settings sheet sections |
| `--debug` | All | Global toggle in Settings → Debug Mode |
| `--paths` | Purge | Settings → Purge Paths |
| `--force` | Update | Settings → Check for Updates → Force reinstall option |

### Destructive Action Safeguards

| Action | Confirmation | Dry-Run | Whitelist | Undo |
|--------|-------------|---------|-----------|------|
| Clean | Dialog listing selected categories | Yes | Yes (`~/.config/mole/whitelist`) | No (permanent) |
| Uninstall | Dialog listing selected apps | No | No | No (permanent) |
| Analyze → Delete | Dialog listing items, moves to Trash | No | No | Yes (Trash) |
| Optimize | Runs without extra confirm (non-destructive) | Yes | Yes (`~/.config/mole/whitelist_optimize`) | No |
| Purge | Dialog listing artifact types | No | No | No (permanent) |
| Installers → Delete | Dialog listing files | No | No | No (permanent) |
