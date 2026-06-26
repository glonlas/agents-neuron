# Neuron

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet.svg)]()

**Your AI reads everything you save, keeps only what matters to you, and turns it into a personal wiki that gets smarter over time.**

---

## The problem

You read a lot. Articles, threads, docs, your own notes.

You forget almost all of it.

Note apps don't help. They just become a graveyard. The work of keeping notes linked, tidy, and findable is so tedious that everyone gives up. The knowledge never compounds.

## The idea

Let the AI do the boring part.

You save things. Neuron's AI files them, links them, removes duplicates, and writes clean wiki pages, all inside your own [Obsidian](https://obsidian.md/) vault. The maintenance cost drops to zero, so your knowledge actually grows.

One more thing makes it personal: **Neuron knows who you are.** It scores everything you save against *your* interests and goals. Important stuff becomes a wiki page. Noise stays out of the way. And the filter learns from what you actually use, so it gets sharper every week.

> Same things go in. Only what matters to *you* comes out.

---

## Install it

You don't install Neuron by hand. Your AI agent does it for you.

Open your AI coding agent (Claude Code, Codex, or OpenCode) and paste this:

```text
Install the Agents Neuron skill for me. Clone https://github.com/glonlas/agents-neuron
(skip if it's already on disk), then read its docs/ai-install.md and follow that runbook
step by step on this machine. Ask me for my Obsidian vault path when you reach that step,
and run the doctor script at the end to confirm the install succeeded.
```

It handles everything: clone, setup, config, and a final check. It pauses once to ask for your Obsidian vault path. Two minutes, done.

> Prefer to do it yourself? The full steps live in the [AI Install Guide](docs/ai-install.md).

---

## The four things you'll actually use

Type these to your AI agent in plain English.

| Command | What it does |
|---------|--------------|
| `neuron add <url\|text>` | Save anything: a link, a note, pasted text. |
| `neuron ingest` | Turn what you saved into wiki pages. Keeps what matters to you, archives the rest. |
| `neuron lint` | Monthly health check. Catches broken links, duplicates, and stale pages. |
| `neuron filter evolve` | Monthly tune-up. Sharpens what Neuron keeps, based on what you actually use. |

That's the whole loop: **add → ingest**, and once a month **lint + filter evolve**.

---

## Ask it anything

Once your wiki has content, ask questions and get answers that link back to where you read it:

```
neuron query what have I saved about sleep and focus?
```

---

## Want it on autopilot?

Neuron can run on a schedule: ingest your reading every morning, tidy up and sharpen the filter every week. See [Commands](docs/commands.md) for the one-line setup.

---

## Learn more

| Doc | What's inside |
|-----|---------------|
| [AI Install Guide](docs/ai-install.md) | The step-by-step runbook your AI agent follows to install Neuron |
| [Commands](docs/commands.md) | Every command, daily routines, automation |
| [Configuration](docs/configuration.md) | Your vault, your identity filter, scoring |
| [Filter Weights](docs/filter-weights.md) | How scoring works and how `neuron filter evolve` re-tunes it |
| [Architecture](docs/architecture.md) | How it works under the hood |
| [Troubleshooting](docs/troubleshooting.md) | When something breaks |
| [Contributing](CONTRIBUTING.md) | Add to the project |

---

## Credits

Built on two great ideas:

- [Andrej Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): the personal wiki the AI maintains for you
- [Baljanak](https://gist.github.com/baljanak/f233d3e321d353d34f2f6663369b3105): the filter that knows who you are and learns over time

## License

[MIT](LICENSE)
