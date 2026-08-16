"""
Smoke test: the .toc is well-formed and every Lua file it lists loads.

Socialite differs from the other two addons in three ways this has to
handle, and each one is a place a naive check would give a false green:

  * `## Interface:` carries a comma-separated list, not a single build.
  * `## Version:` is `@project-version@`, a packager substitution token.
    Asserting it looks like a version number would fail on a correct file;
    asserting nothing would miss a broken one. So we check it is either a
    real version or a recognised token.
  * The .toc lists embeds.xml and commented-out locale files. XML entries
    are skipped (the libraries are stubbed), comments must not be loaded.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_stub import load_addon, Check, ADDON_ROOT  # noqa: E402
from socialite_stub import EXTRA_LUA  # noqa: E402

ADDON = "Socialite"
TOC = os.path.join(ADDON_ROOT, f"{ADDON}.toc")

# Interface builds Socialite is expected to declare. 12.1.0 is 120100.
CURRENT_RETAIL_TOC = 120100


def parse_toc(path):
    directives, files = {}, []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith("##"):
                key, _, value = line[2:].partition(":")
                directives[key.strip()] = value.strip()
            elif not line.startswith("#"):
                files.append(line)
    return directives, files


def main():
    c = Check(f"{ADDON} :: smoke")

    c.section("TOC")
    directives, files = parse_toc(TOC)

    raw_interface = directives.get("Interface", "")
    builds = [b.strip() for b in raw_interface.split(",") if b.strip()]
    c.ok("Interface declares at least one build", builds)
    c.ok(
        "every Interface build is a 6-digit number",
        builds and all(re.fullmatch(r"\d{6}", b) for b in builds),
    )
    print(f"        Interface: {', '.join(builds)}")

    # Reported, not asserted -- see tests/README.md. Failing the suite on a
    # stale TOC would block every other test from running over a value the
    # packager can legitimately manage.
    newest = max(int(b) for b in builds) if builds else 0
    if newest < CURRENT_RETAIL_TOC:
        print(
            f"        NOTE: newest declared build {newest} is behind current "
            f"retail {CURRENT_RETAIL_TOC} (patch 12.1.0)"
        )

    version = directives.get("Version", "")
    c.ok(
        "Version is a real version or a packager token",
        bool(re.fullmatch(r"@[\w-]+@", version) or re.match(r"\d+\.\d+", version)),
    )
    print(f"        Version: {version}")

    c.ok("Title present", directives.get("Title"))
    c.ok("SavedVariables declared", directives.get("SavedVariables"))

    c.section("Declared files")
    c.ok("declares at least one file", files)
    c.ok(
        "no commented-out entry leaked into the file list",
        not any(f.startswith("#") for f in files),
    )
    for f in files:
        rel = f.replace("\\", os.sep)
        c.ok(f"{f} exists on disk", os.path.exists(os.path.join(ADDON_ROOT, rel)))

    lua_files = [f for f in files if f.lower().endswith(".lua")]
    c.ok("at least one Lua file to load", lua_files)

    c.section("Lua loads")
    try:
        lua = load_addon(files, extra_lua=EXTRA_LUA, addon_name=ADDON)
        c.ok("all TOC Lua files loaded under the stub", True)
    except Exception as exc:  # noqa: BLE001
        c.ok(f"all TOC Lua files loaded under the stub -- {exc}", False)
        return c.summary()

    c.section("Addon wired itself up")
    reg = lua.globals().TEST.registered
    c.ok("registered a LibDataBroker data object", reg.ldb["Socialite"] is not None)
    c.ok("registered an Ace options table", reg.options["Socialite"] is not None)
    c.ok("registered the /socialite chat command", reg.commands["socialite"] is not None)

    return c.summary()


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
