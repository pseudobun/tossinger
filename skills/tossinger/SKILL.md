---
name: tossinger
description: Read, create, and delete tosses from the user's Tossinger app via the `toss` CLI. Use this skill when the user references their saved tosses, saved links, reading list, or says things like "what did I save about X", "did I toss anything recently", "add this to my tosses", "toss this link", "show me what I tossed", or mentions Tossinger by name. Also use it when the user wants to search, filter, or manage their saved links — even if they don't explicitly say "toss". Requires the `toss` command to be on PATH, which ships with Tossinger.app via `brew install --cask pseudobun/tap/tossinger`.
---

# Tossinger

Tossinger is a small macOS/iOS app for quickly saving ("tossing") links and short text notes for later. Data syncs across the user's devices via iCloud. The macOS app ships an embedded CLI called `toss` that exposes the same SwiftData store the GUI uses, so you can read and mutate the user's tosses from the command line — which is exactly what this skill is for.

When the user talks about their saved tosses / saved links / reading list, or wants to search through things they've saved, or wants to add or remove something, you should consult this skill and drive the `toss` CLI from your bash tool.

## Preflight: make sure the CLI is installed

Before anything else, run `command -v toss` (or `which toss`). If it's not on PATH, don't try to guess, don't pretend the user has tosses you haven't verified, and don't fall back to searching the filesystem or running `find` for SwiftData stores. Instead, explain to the user:

> The Tossinger CLI isn't installed on this machine. Install it with:
> ```
> brew install --cask pseudobun/tap/tossinger
> ```
> This installs the Tossinger macOS app, which includes a `toss` command-line tool symlinked into your PATH. After install, come back and I'll be able to read and manage your tosses.

Then stop. Don't try to do anything else in the same turn — the user needs to install before you can help.

The reason this matters: the CLI is the only way for an agent to access the user's tosses. Without it, iCloud containers and SwiftData stores are sandboxed and nothing you could grep or read would give you the right data. Pretending otherwise would mean making things up.

## Command reference

The CLI has four subcommands: `list`, `add`, `delete`, and their aliases `ls` and `rm`. All three support the `--help` flag if you need to check syntax. The sections below cover what you actually need.

### Reading tosses: `toss list`

```
toss list [--limit N] [--offset N] [--json]
```

Always pass `--json` when you're going to parse the output. The default text form is for humans, not agents — it uses pretty box-drawing characters and isn't stable for scripting.

JSON shape:

```json
{
  "total": 42,
  "limit": 50,
  "offset": 0,
  "tosses": [
    {
      "id": "AB7DCC94-62EC-4385-B39B-499BC2C50FEE",
      "createdAt": "2026-04-09T07:56:32Z",
      "type": "link",
      "content": "https://example.com",
      "title": "Example Site",
      "description": "An optional description from link metadata",
      "author": "Optional author",
      "platformType": "genericWebsite",
      "metadataFetchState": "success"
    }
  ]
}
```

Notes:

- `type` is `"link"` or `"text"`. Link tosses have `content` = the URL; text tosses have `content` = the raw text.
- `title`, `description`, `author`, `platformType`, `metadataFetchState` are all optional. Text tosses usually have none of them. Link tosses populate them from fetched page metadata.
- `metadataFetchState` can be `"pending"`, `"success"`, `"failed"`, or `"timeout"`. A `"pending"` value means the metadata hasn't been enriched yet (see the *Adding tosses* section for why this happens).
- The default `--limit` is 50. For "most recent 3" use `--limit 3`. For "show me everything" use `--limit 1000` or similar — there's no unbounded mode.

**Searching**: the CLI has no `toss search` subcommand. When the user asks "did I save anything about X", pull a generous chunk of tosses with `toss list --json --limit 500`, then filter the `tosses` array client-side. Check `title`, `description`, `content`, and `author` with case-insensitive substring match. If nothing matches, tell the user "no tosses about X" — don't invent results or paraphrase unrelated tosses into a fake match.

### Adding tosses: `toss add`

```
toss add "<content>" [--json]
```

- URLs (starting with `http://` or `https://`) become link tosses. The CLI detects this automatically.
- Anything else becomes a text toss.
- Use `--json` to get back the created toss with its UUID so you can confirm what was saved.

Link tosses come back with `metadataFetchState: "pending"` and minimal metadata (usually just the host as the title). This is expected and not an error — the macOS app enriches link tosses with full page metadata (real title, description, thumbnail, platform detection) the next time it launches. If you're reporting back to the user, mention this briefly: *"saved — the link will pick up its full title and description the next time you open Tossinger."* Don't treat "pending" as a failure.

Always quote the content argument so shells don't mangle multi-word text or URLs with query strings.

### Deleting tosses: `toss delete`

```
toss delete <uuid> --force
```

- **Always pass `--force`.** Without it, the CLI prints a confirmation prompt and waits for the user to type `yes`. Agents running in non-interactive bash can't respond to the prompt, so the command hangs.
- **Confirm with the user in conversation first.** Deletes are irreversible and sync to all their devices via CloudKit. Don't delete without explicit user approval, even if they asked you to. Show them what you're about to delete (title, content, id) and wait for confirmation.
- The `<uuid>` argument must be the full 36-character UUID. If the user references a toss by a short id (the macOS app's card badge shows only the first 8 characters), resolve it by running `toss list --json`, finding the toss whose `id` starts with the prefix, and passing the full uuid to `delete`. If the prefix matches multiple tosses, ask the user to disambiguate.

### Aliases

- `toss ls` is the same as `toss list`
- `toss rm` is the same as `toss delete`

Prefer the long forms when reporting to the user (it's clearer), but either works when you're just running commands.

## Presenting results

When summarizing tosses for the user in conversation, use a compact format — don't dump raw JSON unless the user explicitly asks for "the JSON" or similar.

Preferred format for each toss:

```
• <title or first-line-of-content> (<relative time>) — <url-or-content-preview>
```

Examples:

```
• Lutra Labs (2 days ago) — https://lutralabs.io
• Toss first, think later. (5 min ago) — https://github.com/pseudobun/tossinger
• Reminder: renew domain next month (yesterday) — text toss
```

Rules of thumb:

- **Sort newest-first by default** unless the user asks for a specific order.
- **Show 5–10 tosses max** in a summary response. If there are more matches, tell the user "and N more" and offer to show the rest.
- **Collapse long content**: text tosses can be multi-paragraph. Truncate to ~80 chars with an ellipsis for the summary view.
- **Don't expose internal fields** (`platformType`, `metadataFetchState`, `searchIndex`, etc.) unless the user's question is specifically about them.
- **Use relative times** ("2 days ago", "yesterday") rather than ISO timestamps for readability. Fall back to dates for tosses older than a month.

## Failure modes

Handle errors honestly. Don't swallow them, don't paper over them, don't make up results.

| Situation | What to do |
|---|---|
| `toss` not installed | Explain the install command. Stop. |
| `toss list` returns empty total | Say "no tosses found" (or "no tosses matching X" for searches). Don't invent. |
| `toss list --json` exits non-zero | Show the error to the user, suggest re-running `toss list` without `--json` to see if the CLI has anything to say. |
| `toss delete <uuid>` prints "No toss found with id ..." | Surface the error honestly. Maybe the user passed the wrong id, or the toss was already deleted on another device. |
| `toss add ""` or whitespace | CLI prints "Toss content cannot be empty". Ask the user what they want to save. |
| Ambiguous short-id prefix on delete | Show the matching tosses and ask the user to pick one. |

## Safety: what not to do

- **Don't delete without explicit per-item confirmation.** Even if the user said "delete all my tosses", confirm before each delete, or at minimum show them the full list and ask "are you sure?" before bulk-deleting.
- **Don't manufacture toss content.** If a search returns nothing, say so. Don't describe what "probably" is in their tosses based on topic guesses.
- **Don't use `toss list` as a backup tool.** It's not designed for that. If the user is asking about data recovery, tell them to use Tossinger.app directly — the SwiftData store and iCloud sync are the source of truth.
- **Don't shell out to the raw SwiftData store.** The shared container path (`~/Library/Group Containers/group.lutra-labs.toss/`) exists but is sandboxed and reserved for entitled processes. Only the `toss` CLI can read it correctly.

## Examples

### Example 1: search

User: *"did I save anything about CloudKit recently?"*

You:
1. `command -v toss` — confirm installed.
2. `toss list --json --limit 500` — pull everything.
3. Filter the `tosses` array for entries where `title`, `description`, `content`, or `author` contains "cloudkit" (case-insensitive).
4. Show the matches in the compact format, newest-first, up to 10. If there are no matches, say "no tosses mentioning CloudKit."

### Example 2: add

User: *"toss this: https://developer.apple.com/documentation/swiftdata"*

You:
1. `command -v toss` — confirm installed.
2. `toss add "https://developer.apple.com/documentation/swiftdata" --json`
3. Parse the returned id and title. Report: *"Saved. ID `abcd1234…`. The title and description will fill in the next time you open Tossinger."*

### Example 3: delete

User: *"delete the Lutra Labs one"*

You:
1. `command -v toss` — confirm installed.
2. `toss list --json --limit 500` — find matching tosses.
3. Find toss(es) with "Lutra Labs" in title/content. If exactly one match, show it to the user: *"Found: `• Lutra Labs — https://lutralabs.io (id a1b2c3d4)`. Delete it?"*
4. Wait for user confirmation.
5. On "yes": `toss delete <full-uuid> --force`
6. Confirm deletion: *"Deleted."*

If multiple "Lutra Labs" tosses match, show all of them and ask which one.

### Example 4: recent

User: *"what have I tossed lately?"*

You:
1. `command -v toss` — confirm installed.
2. `toss list --json --limit 10`
3. Present in compact format, newest-first.

## When in doubt

If you're unsure whether the user wants you to use this skill (e.g., they said "save this" but it's not clear if they mean "save to Tossinger" or "save to a file"), ask them to clarify rather than guessing. Tossinger is a specific tool with specific semantics — don't invoke it unless the user's intent matches.
