"""
Battle.net roster parsing.

parseRealID turns the flat (account, game account) pairs Blizzard hands back
into the shape the tooltip renders: one "focus" character per friend, their
alts underneath, and app-only friends in a separate bucket.

That reshaping is where this addon has actually broken before -- friends
showing as Unknown, the wrong character listed as active. It is also pure
logic over API return values, which makes it exactly the kind of thing worth
pinning down: no frames, no rendering, just data in and data out.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_stub import load_addon, Check  # noqa: E402
from socialite_stub import EXTRA_LUA  # noqa: E402

TOC_FILES = ["i18n\\enUS.lua", "tooltip.lua", "functions.lua", "Socialite.lua", "config.lua"]


def account(lua, bnet_id, name, tag=None, battletag_friend=True, client="WoW"):
    return lua.table_from({
        "bnetAccountID": bnet_id,
        "accountName": name,
        "battleTag": tag or (name + "#1234"),
        "isBattleTagFriend": battletag_friend,
        "broadcastText": "",
        "note": "",
        "gameAccountInfo": lua.table_from({
            "isAFK": False, "isDND": False, "clientProgram": client,
        }),
    })


def game_account(lua, char, client="WoW", has_focus=False, realm="TestRealm", level=80):
    return lua.table_from({
        "characterName": char,
        "clientProgram": client,
        "realmName": realm,
        "realmID": 1,
        "factionName": "Alliance",
        "raceName": "Human",
        "className": "Warrior",
        "areaName": "Stormwind City",
        "characterLevel": level,
        "richPresence": "In Stormwind City",
        "hasFocus": has_focus,
    })


def setup(lua, friends_spec):
    """friends_spec: list of (accountName, [game_account, ...])

    accountInfo.gameAccountInfo is derived from the game accounts rather than
    hardcoded, because that is what Blizzard does: it reflects the account the
    friend is currently active on. countRealID reads that account-level field
    while parseRealID walks the per-account list, so a fixture that sets them
    independently makes the two disagree for reasons the addon is not
    responsible for.
    """
    g = lua.globals()
    accounts, per_account = [], {}
    for idx, (name, gas) in enumerate(friends_spec, start=1):
        wow = next((ga for ga in gas if ga["clientProgram"] == "WoW"), None)
        active = wow or (gas[0] if gas else None)
        client = active["clientProgram"] if active is not None else ""
        accounts.append(account(lua, idx, name, client=client))
        per_account[idx] = lua.table_from(gas)
    g.TEST.bnFriends = lua.table_from(accounts)
    g.TEST.gameAccounts = lua.table_from(per_account)
    return g


def lua_len(tbl):
    return len(list(tbl.values())) if tbl is not None else 0


def main():
    c = Check("Socialite :: Battle.net roster parsing")

    lua = load_addon(TOC_FILES, extra_lua=EXTRA_LUA, addon_name="Socialite")
    ns = lua.globals().ADDON_NS
    c.ok("addon namespace exposed", ns is not None)
    c.ok("parseRealID present", ns.parseRealID is not None)

    c.section("1. One friend on one character")
    g = setup(lua, [("Alice", [game_account(lua, "Alicewarrior", has_focus=True)])])
    friends, bnets = ns.parseRealID(ns, False)
    c.eq("one friend parsed", lua_len(friends), 1)
    c.eq("no app-only entries", lua_len(bnets), 0)
    c.eq("focus character is the one in game", friends[1].focus.name, "Alicewarrior")
    c.eq("account name carried through", friends[1].accountName, "Alice")
    c.eq("no alts", lua_len(friends[1].alts), 0)

    c.section("2. Focus character is chosen over alts")
    setup(lua, [("Bob", [
        game_account(lua, "Bobalt1", has_focus=False),
        game_account(lua, "Bobmain", has_focus=True),
        game_account(lua, "Bobalt2", has_focus=False),
    ])])
    friends, _ = ns.parseRealID(ns, False)
    c.eq("the hasFocus character is the focus", friends[1].focus.name, "Bobmain")
    c.eq("the other two become alts", lua_len(friends[1].alts), 2)

    c.section("3. No hasFocus flag: first character is promoted")
    setup(lua, [("Cara", [
        game_account(lua, "Caraone", has_focus=False),
        game_account(lua, "Caratwo", has_focus=False),
    ])])
    friends, _ = ns.parseRealID(ns, False)
    c.eq("first character promoted to focus", friends[1].focus.name, "Caraone")
    c.eq("promoted character not also an alt", lua_len(friends[1].alts), 1)

    c.section("4. App-only friend goes to the Battle.net bucket")
    setup(lua, [("Dan", [game_account(lua, "", client="App")])])
    friends, bnets = ns.parseRealID(ns, False)
    c.eq("not counted as an in-game friend", lua_len(friends), 0)
    c.eq("counted as an app friend", lua_len(bnets), 1)

    c.section("5. Mobile client (BSAp) treated as app, not as a character")
    setup(lua, [("Erin", [game_account(lua, "", client="BSAp")])])
    friends, bnets = ns.parseRealID(ns, False)
    c.eq("not an in-game friend", lua_len(friends), 0)
    c.eq("is an app friend", lua_len(bnets), 1)

    c.section("6. filterClients hides the app entry when they are also in game")
    spec = [("Fay", [
        game_account(lua, "", client="App"),
        game_account(lua, "Faymain", has_focus=True),
    ])]
    setup(lua, spec)
    friends, bnets = ns.parseRealID(ns, False)
    c.eq("unfiltered: appears in both buckets", (lua_len(friends), lua_len(bnets)), (1, 1))
    setup(lua, spec)
    friends, bnets = ns.parseRealID(ns, True)
    c.eq("filtered: in-game only", (lua_len(friends), lua_len(bnets)), (1, 0))

    c.section("7. Nobody online")
    setup(lua, [])
    friends, bnets = ns.parseRealID(ns, False)
    c.eq("no friends", lua_len(friends), 0)
    c.eq("no app friends", lua_len(bnets), 0)

    c.section("8. countRealID agrees with parseRealID")
    setup(lua, [
        ("Gil", [game_account(lua, "Gilmain", has_focus=True)]),
        ("Hal", [game_account(lua, "Halmain", has_focus=True)]),
        ("Ivy", [game_account(lua, "", client="App")]),
    ])
    n_friends, n_bnet = ns.countRealID(ns, False)
    c.eq("counts two in-game friends", n_friends, 2)
    c.eq("counts one app friend", n_bnet, 1)

    return c.summary()


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
