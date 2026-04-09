<div align="center">
  <img src="assets/icon.png" alt="Tossinger Icon" width="128" height="128">
  
  # Tossinger 🎯
  
  **Toss first, think later.**
  
  Tossinger is a native iOS and macOS app that lets you quickly "toss" content from anywhere - tweets, web pages, articles, links - into your personal collection to revisit and organize later on your preferred device.
</div>

## What it does





<video width="128" height="128" src="https://github.com/user-attachments/assets/25095a11-a784-4c42-9924-0dc699b136b0" autoplay loop muted></video>

* **Quick Toss**: Save URLs or text from anywhere with a simple share action
* **Cross-platform**: Toss on your iPhone, organize on your MacBook (or vice versa)
* **Private**: Your tosses stay yours - no third-party cloud bullshit, just your own iCloud sync
* **Minimalistic**: No extra features, just you and your tosses, I hate bloated software
* **Biometrics lock**: Lock with device biometrics if you want

## Install

### iOS

<a href="https://apps.apple.com/app/id6754607504">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="50">
</a>

### macOS

```sh
brew install --cask pseudobun/tap/tossinger
```

If you don't have the tap added yet:

```sh
brew tap pseudobun/tap
brew install --cask tossinger
```

Requires macOS 15 (Sequoia) or newer.

The macOS cask also installs the `toss` command-line tool on your `PATH` (symlinked from `/Applications/Tossinger.app/Contents/Helpers/toss.app/Contents/MacOS/toss`), so you can read, add, and delete tosses from the terminal:

```sh
toss list                            # most recent 50, newest first
toss list --json                     # machine-readable output
toss add "https://example.com"       # toss a link
toss add "reminder: something"       # toss some text
toss delete <uuid> --force           # delete by id
toss --help                          # see all commands
```

## Claude Code skill

Tossinger ships with a [Claude Code](https://claude.com/claude-code) agent skill that lets AI agents read, create, and delete your tosses via the `toss` CLI. Install it into your personal skills directory:

```sh
mkdir -p ~/.claude/skills/tossinger
curl -L https://raw.githubusercontent.com/pseudobun/tossinger/main/skills/tossinger/SKILL.md \
  -o ~/.claude/skills/tossinger/SKILL.md
```

Or, if you've cloned the repo:

```sh
cp -r skills/tossinger ~/.claude/skills/
```

After install, phrases like *"what did I save about X"*, *"toss this link"*, or *"show me my recent tosses"* will fire the skill in a fresh Claude Code session. Requires the `toss` CLI on your `PATH` (see the macOS install section above).

## How it works

1. **See something interesting?** Hit share → Tossinger
2. **Pick it up later** on any of your devices
4. **Organize** when you have time and headspace

## Privacy first

* **No accounts required** - just download and start tossing
* **CloudKit sync** - your data syncs through your iCloud, I never see it
* **Zero tracking** - no analytics, no hidden accounts, no bullshit

## Perfect for

* Saving tweets for later reading
* Bookmarking articles while commuting
* Collecting research links on mobile, organizing on desktop
* Building reading lists across devices
* Keeping track of random interesting shit you find online

---

*Stop losing track of the good stuff. Start tossing.*
