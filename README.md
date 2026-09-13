# rust-web-th

```
██████╗ ██╗   ██╗███████╗████████╗         ██╗    ██╗███████╗██████╗         ████████╗██╗  ██╗
██╔══██╗██║   ██║██╔════╝╚══██╔══╝         ██║    ██║██╔════╝██╔══██╗        ╚══██╔══╝██║  ██║
██████╔╝██║   ██║███████╗   ██║   █████╗   ██║ █╗ ██║█████╗  ██████╔╝   █████╗  ██║   ███████║
██╔══██╗██║   ██║╚════██║   ██║   ╚════╝   ██║███╗██║██╔══╝  ██╔══██╗   ╚════╝  ██║   ██╔══██║
██║  ██║╚██████╔╝███████║   ██║            ╚███╔███╔╝███████╗██████╔╝           ██║   ██║  ██║
╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝             ╚══╝╚══╝ ╚══════╝╚═════╝            ╚═╝   ╚═╝  ╚═╝
```

---

## ◆ PULSE

[![GitHub Pages](https://img.shields.io/badge/Pages-live-2ea44f)](https://suradet-ps.github.io/rust-web-th/)

A web application has a first handler, and a first repository - rust-web-th is
the Thai bridge to that exact moment. This is the complete Thai translation of
the [Bulletproof Rust Web](https://github.com/gruberb/bulletproof-rust-web)
guide: 30 chapters across six sections built with mdbook, terminology locked by
a single glossary, and every code block byte-identical to the original. The
links are checked against the built book (538 anchors), the structure mirrors
the upstream repo file-for-file, and the templates ship verbatim. Built for the
Thai-speaking student of Rust web development:
[suradet-ps.github.io/rust-web-th](https://suradet-ps.github.io/rust-web-th/).

| 30 chapters translated ▣ | Glossary ▣ | Links 538/538 ▣ | Build passing ▣ |
|---|---|---|---|

*v1.0.0 - translation, glossary, verification, and the static build are all
sealed.*

> Built with mdbook 0.5 + Markdown, translated from
> [gruberb/bulletproof-rust-web](https://github.com/gruberb/bulletproof-rust-web),
> verified by script and rendered as static HTML - a guide with the
> pages on the page.
>
> **suradet-ps**, artifact keeper

---

## ◆ IGNITION

One runtime, three commands.

```
⟫ git clone https://github.com/suradet-ps/rust-web-th.git
⟫ cd rust-web-th
⟫ cargo install mdbook
⟫ mdbook serve book --open
```

Open [http://localhost:3000](http://localhost:3000).

```
⟫ mdbook build book                                  # static HTML into book/book
⟫ powershell scripts/check-links.ps1                 # all anchors in the built book (pwsh on Linux/macOS)
⟫ powershell scripts/verify-translation.ps1          # byte-exact check vs upstream
```

> On Linux or macOS, run the verification scripts using `pwsh scripts/<script>.ps1`.
> `verify-translation.ps1` checks against `bulletproof-rust-web` in adjacent
> directories or via `-Orig <path>`.

<details>
<summary>Translating a chapter</summary>

A chapter is a file: `book/src/<chapter>.md`, listed in
`book/src/SUMMARY.md`. The glossary lives in `GLOSSARY.md` - a term
is chosen once and reused everywhere. Code blocks, commands, links,
and filenames stay verbatim; only prose and headings are translated.
One deviation from upstream is intentional and documented in
`scripts/verify-translation.ps1`: the upstream `middleware.md` links to
`putting-it-all-together.md`, a page that does not exist - the Thai
edition fixes the target to `putting-it-together.md` so every link resolves.

</details>

---

## ◆ ANATOMY

One stack, zero custom JS, several quiet helpers.

- **Translates** - the complete guide: introduction, architecture (4
  chapters), core patterns (4), HTTP layer (5), production (5), advanced (7),
  and reference (4) - Thai prose over untouched code.
- **Glossaries** - `GLOSSARY.md` locks the vocabulary (handler, middleware,
  newtype, typestate - one Thai spelling per term), so
  chapter nine agrees with chapter two.
- **Verifies** - `scripts/verify-translation.ps1` diffs every code block,
  heading level, and link target against upstream
  `bulletproof-rust-web` - byte-exact or it does not pass.
- **Checks** - `scripts/check-links.ps1` walks the built book and resolves
  every anchor link against real page ids - 538 of them, all reachable.
- **Builds** - mdbook renders static HTML into `book/book/`, zero server
  runtime, readable offline and searchable by built-in static index.
- **Mirrors** - `templates/` (AI agent instruction files) is copied verbatim
  from upstream, and the CI deploys the static build to GitHub Pages on every
  push to `main`.

---

## ◆ RITUALS

**The core ceremony** - the translation pass:

1. Open a chapter in `book/src/`. The upstream `bulletproof-rust-web` repo
   sits beside it (clone `https://github.com/gruberb/bulletproof-rust-web`
   alongside `rust-web-th`) - structure is a contract.
2. Translate the prose; keep every code block and command as the original
   wrote it.
3. Consult `GLOSSARY.md` for every term that already has a canon. New terms
   get proposed in the glossary first.
4. Build, verify, check. The book builds clean, the diff is byte-exact, and
   the anchors resolve.

**The ceremony of the code block** - a translated command that is not
byte-identical to the original is a regression, not a translation. The
verifier is the conscience of the repo.

**The ceremony of the heading** - heading levels are borrowed from the
original and the text is Thai; Thai headings are read from the built HTML,
written into the source, and re-verified - a guessed heading is a broken link
waiting to happen.

---

## ◆ ECHOES

**Where this artifact is heading**

```
P1 ▸ SUMMARY + introduction, architecture ───────────────────────────── ▸ sealed
P2 ▸ core patterns, HTTP layer ──────────────────────────────────────── ▸ sealed
P3 ▸ production, advanced, reference ────────────────────────────────── ▸ sealed
P4 ▸ glossary, link verification, mdbook build, CI deploy ───────────── ▸ sealed
```

**Raising the artifact** - the honest path lives in `GLOSSARY.md`
(term canon), `scripts/` (the verification gate), and `book/book.toml`
(book config). New chapters follow the frontmatter-free contract of
the SUMMARY. Open an issue first to discuss a change.

**Status** - on every change: `mdbook build book` must pass, the
translation verifier must report byte-exact code blocks across all 31
files (30 chapters + `SUMMARY.md`), and the link checker must report
`ALL ANCHOR LINKS OK`.
[Watch the gates](scripts).

---

```
  ─────────────────────────────────────────
   Every application has its first handler
   Every book has its first page
  ─────────────────────────────────────────
```

Translated from the [Bulletproof Rust Web](https://github.com/gruberb/bulletproof-rust-web)
guide by [gruberb](https://github.com/gruberb). The upstream repository does
not declare a license; this translation ships no license files of its own.