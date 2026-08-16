# Tests

Runs Socialite's actual Lua against a stubbed WoW API, outside the game.

```bash
pip install lupa
python tests/run_all.py
```

Exits `0` if everything passes, `1` if anything fails. `lupa` embeds a real
Lua interpreter in Python, so these tests execute the addon's real source
rather than reasoning about it. No other dependencies.

## Why this exists

Addons break at the seam with Blizzard's API, and that seam moves every patch.
For Socialite there is a second seam: the reshaping of Battle.net roster data
between what the API returns and what the tooltip renders. That is where this
addon has actually broken before — friends showing as **Unknown**, the wrong
character listed as active — and it is pure data-in/data-out logic, so it can
be pinned down precisely.

`test_realid.py` covers `parseRealID` and `countRealID` directly: focus
character selection, alt ordering, app-only and mobile (`BSAp`) friends, the
`filterClients` behaviour, and the empty case.

## Layout

| File | What it covers |
|---|---|
| `wow_stub.py` | The shared fake Blizzard API, `load_addon()`, assert helper |
| `socialite_stub.py` | Socialite's extra surface: Ace3, LibDataBroker, LibDBIcon, `C_BattleNet`, `C_Club`, `C_FriendList`, `C_GuildInfo` |
| `test_smoke.py` | The `.toc` parses, every listed file loads, and the addon registers its broker, options table and chat command |
| `test_realid.py` | Battle.net roster parsing |
| `test_api_contract.py` | Fails if the addon calls anything removed or renamed in the current patch |
| `run_all.py` | Runs every `test_*.py` here |

## Things specific to this addon

**Vendored libraries are stubbed, not executed.** Real Ace3 would drag in most
of the widget API, and the subject of these tests is Socialite's own code.
`socialite_stub.py` records what got registered so `test_smoke.py` can assert
the addon wired itself up. `vendor/` is excluded from the API contract scan
too — it is third-party code, not ours to fix.

**The `.toc` needs care.** `## Interface:` is a comma-separated list, not a
single build. `## Version:` is `@project-version@`, a packager substitution
token — asserting it looks like a version number would fail on a *correct*
file. And the file lists `embeds.xml` plus commented-out locale entries, so
the parser must skip comments and the loader must skip XML.

**The Interface build is reported, not asserted.** `test_smoke.py` prints a
NOTE when the newest declared build is behind current retail. Failing the
suite on it would block every other test over a value the packager can
legitimately manage — but it stays visible so it cannot rot silently.

## Writing a test

Each file is loaded as its own chunk and called with `(addonName, addon)`,
exactly as WoW does — which is what makes the `local addonName, addon = ...`
namespace idiom work. That private table is published as `_G.ADDON_NS`, so
tests can reach methods hung off it:

```python
from wow_stub import load_addon, Check
from socialite_stub import EXTRA_LUA

lua = load_addon(TOC_FILES, extra_lua=EXTRA_LUA, addon_name="Socialite")
ns = lua.globals().ADDON_NS
friends, bnets = ns.parseRealID(ns, False)     # note: explicit self
```

`g.TEST` is the control surface: `bnFriends`, `gameAccounts`, `guild`,
`clubs`, `clubMembers`, `registered`, and `prints`.

**Build fixtures the way Blizzard populates the real structures.** In section 8
of `test_realid.py`, `countRealID` reads the *account-level*
`accountInfo.gameAccountInfo` while `parseRealID` walks the per-account list.
A fixture that sets those two independently makes them disagree for reasons
the addon is not responsible for — which reads as a bug in the addon and
isn't one. `setup()` derives the account-level field from the game accounts
for exactly that reason.

## Two rules that make this worth running

1. **Model the new API behaviour in the stub, not the old one.** The stub is
   only useful if it lies the way the current patch lies.
2. **Prove the test can fail.** A guard that has never gone red is decoration.

## After a patch

Update the tables at the top of `test_api_contract.py` with what the patch
removed, renamed, or restricted. That edit is the point of the file: it turns
"read the patch notes and hope" into a check that runs.

This harness is shared with AdventureKit and SpeedTracker. `wow_stub.py` is
addon-agnostic — `ADDON_ROOT` resolves to the repo containing `tests/` — so
improvements are worth copying across all three.
