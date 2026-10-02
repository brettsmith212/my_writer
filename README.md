# MyWriter

A quiet Markdown writing app for macOS. A plain page by default; writing tools appear when you want them.

## Install

Requires macOS 14+, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make install    # release build → /Applications/MyWriter.app
make run        # or: build and launch a debug build
```

Or download the signed, notarized `.dmg` from [Releases](../../releases).

**Shipping a version** (maintainers): `make release V=0.1.1` sets the version, builds a Developer ID signed and notarized `.dmg`, publishes a GitHub Release, and installs that copy into /Applications. It needs the Developer ID certificate and saved notarization credentials (see the comments above `dmg` in the Makefile).

Optional: **MyWriter → Install Shell Command…** adds a `mywriter` command for opening files from a terminal:

```bash
mywriter draft.md    # open a file (created if it doesn't exist)
```

## First steps

1. **Write.** The page is all you see. Edits save to disk automatically within a couple of seconds.
   Quit with ⌘Q and your documents reopen where you left off; close a window and it stays closed. With nothing open, MyWriter shows a welcome window with your recent files.
2. **Click the word count** (top right) to bring in the writing tools. Click it again to hide them.
3. **Select some text.** A small bar offers Alternatives, AI, Ghost and Stash.
4. **Take the tour** from the **?** button, or open the practice document from the Help menu.

## Features

| Feature | What it does |
| --- | --- |
| **Alternatives** | Keep several versions of a word, sentence or paragraph. A wavy underline and dots mark them. Hover and press → / ← to try each one; a lower tone plays when you're back on the original. Click the dots to see them all. |
| **AI alternatives** | Suggestions that fit the sentence, marked ✦. Type `??` in the panel for more. |
| **Ghost** | Dims text instead of deleting it. It stays in the file but leaves the word count, preview and copied text. |
| **Overflow** | A side drawer for spare paragraphs and notes. |
| **Lab** | AI editing that points things out and never rewrites: convoluted sentences, off-tone words, and trims (slight, tighten, sharper, half) shown as strike-throughs you cut or keep. Hover a tool and click its sliders icon (or right-click it) to edit its prompt; **New tool** adds your own. |
| **Zen** | Full screen with one key; everything else works as usual. Toggle again to return to how the window was. |
| **Markdown** | Styled as you type; the symbols hide outside the line you're editing. Preview renders it. |
| **Vim mode** | Normal, insert, visual and visual-line modes, with your own mappings. |
| **Export** | **File → Export Clean Copy…** saves the finished essay as a new Markdown or HTML file: current alternatives only, no ghosted text, overflow or MyWriter notes. Your working file is untouched. Also: copy clean text, post to X. |

## Shortcuts

Standard Mac shortcuts (⌘S, ⌘Z, ⌘C, ⌘,) work as usual. Use Caps Lock as Control, or want plain ⌃ keys left to Vim? Settings → Keyboard → Shortcuts switches MyWriter's own shortcuts to **Control + Shift + letter** (⌃⇧ column).

| Action | Keys | ⌃⇧ style |
| --- | --- | --- |
| Show / hide writing tools | ⇧⌘E, or click the word count | ⌃⇧E |
| Alternatives for a selection (or open/close the panel) | ⇧⌘A, or right-click | ⌃⇧A |
| AI alternatives | ⌥⌘A | ⌃⇧I |
| Next / previous alternative | Hover the underline + → / ←, or ⌥⌘↓ / ⌥⌘↑ | ⌃⇧J / ⌃⇧K |
| In the alternatives panel | Return adds · `??` asks AI · click applies · ↑ ↓ cycle · Delete removes | |
| Ghost / revive | ⌥⌘G | ⌃⇧G |
| Stash in overflow | ⌥⌘S | ⌃⇧S |
| Overflow / Lab | ⌥⌘O / ⌥⌘L | ⌃⇧O / ⌃⇧L |
| Preview | ⌥⌘P | ⌃⇧P |
| Zen mode (full screen) | ⌃⌘Z | ⌃⇧Z |
| Zoom in / out / actual size | ⌘+ / ⌘− / ⌘0 (resets each launch) | |
| Export clean copy | ⌥⇧⌘E | |
| Copy clean text | ⇧⌘C | ⌃⇧C |
| All shortcuts | ⌘/ | ⌘/ |

## Vim

Turn on in Settings → Keyboard → Vim. Mappings are written vimrc-style, e.g. `inoremap jk <Esc>`, and are always non-recursive.

Supported: counts; `h j k l w b e W B E 0 ^ $ gg G { } ( ) f t F T ; ,`; `d c y` with motions and text objects (`iw aw is as ip ap`, quotes `" ' `` ` ``, brackets `( [ { <`); `dd cc yy x X s S D C Y p P r J ~ u ⌃r .`; `i a I A o O`; `v V`; `/ n N *`; `⌃d ⌃u ⌃f ⌃b`. Yank and delete use the system clipboard.

By default, line commands work on the line you see, not the whole wrapped paragraph: `j k 0 ^ $ A I D C dd cc yy V`. Turn off "Line motions follow wrapped lines" (Settings → Keyboard) for strict Vim; `gj gk g0 g^ g$` still move by screen line.

Alternatives: hover an underlined word and press → / ←, or use `]a` / `[a` on the word under the cursor.

## AI

The first time you use an AI feature, MyWriter offers to connect. Choose one (Settings → AI):

- **Sign in with ChatGPT** to use the plan you already have; no API key needed (defaults to Astra, medium reasoning)
- **Anthropic API key** (defaults to Claude Sonnet 5.5)
- **OpenAI API key**

One model and one **Reasoning** level drive alternatives, `??` and the Lab. Lower reasoning is faster. Results appear as they stream in. Keys and sign-in tokens live in your Keychain.

## Updates

MyWriter checks for updates about once a day. When one is ready, a small **Update** label appears in the top bar; click it to see what's new and install. Settings → Editor → Updates can install them automatically instead, and **MyWriter → Check for Updates…** checks right away.

## Files

- **Documents** are plain `.md` files, saved wherever you choose. New documents show **Not saved** (top bar) until you give them a name with ⌘S. Move the pointer to the top edge to see the file's name; click it for its folder, Show in Finder, Copy Path and Rename.
- **Alternatives and ghosts** are inline `<span>` tags, so other Markdown apps show your current wording. The alternatives list and overflow sit in an HTML comment at the end of the file.
- **Settings and Lab tools** live in `~/Library/Preferences/com.brettsmith.MyWriter.plist`.
