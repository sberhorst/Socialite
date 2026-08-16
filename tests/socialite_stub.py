"""
Socialite-specific additions to the shared WoW stub.

Socialite is a data broker for friends, Battle.net and guild rosters, so it
touches a much wider slice of the API than the other addons: Ace3,
LibDataBroker, LibDBIcon, and the C_BattleNet / C_Club / C_FriendList /
C_GuildInfo namespaces.

The vendored libraries under vendor/ are stubbed rather than executed. Real
Ace3 would drag in most of the widget API, and the point of these tests is
Socialite's own code, not Ace's. The stubs record what the addon registered
so a test can assert on it.

TEST additions:
    TEST.bnFriends      list of Battle.net friend account tables
    TEST.gameAccounts   bnetAccountID -> list of game account tables
    TEST.guild          list of guild roster rows
    TEST.clubs          list of club (community) tables
    TEST.clubMembers    clubId -> list of member tables
    TEST.registered     what got registered with LibDataBroker/DBIcon/Ace
"""

EXTRA_LUA = r"""
TEST.bnFriends    = {}
TEST.gameAccounts = {}
TEST.guild        = {}
TEST.clubs        = {}
TEST.clubMembers  = {}
TEST.registered   = { ldb = {}, minimap = {}, options = {}, commands = {} }

-- --- Font / colour globals -------------------------------------------------
NORMAL_FONT_COLOR_CODE   = "|cffffd200"
DISABLED_FONT_COLOR_CODE = "|cff7f7f7f"
FONT_COLOR_CODE_CLOSE    = "|r"
HIGHLIGHT_FONT_COLOR     = { r = 1, g = 1, b = 1 }
RAID_CLASS_COLORS = setmetatable({}, {__index = function()
  return { r = 1, g = 1, b = 1, colorStr = "ffffffff" }
end})
LOCALIZED_CLASS_NAMES_MALE   = setmetatable({}, {__index = function(_, k) return k end})
LOCALIZED_CLASS_NAMES_FEMALE = setmetatable({}, {__index = function(_, k) return k end})

InterfaceOptionsFramePanelContainer = stubframe()
Settings = { OpenToCategory = function() end }

-- --- LibStub ---------------------------------------------------------------
-- Returns a stub for any library name asked for. Registration calls record
-- into TEST.registered so tests can assert the addon wired itself up.
local libs = {}

libs["LibDataBroker-1.1"] = {
  NewDataObject = function(self, name, tbl)
    TEST.registered.ldb[name] = tbl
    return tbl
  end,
}

libs["LibDBIcon-1.0"] = {
  Register = function(self, name, obj, db) TEST.registered.minimap[name] = true end,
  Hide     = function() end,
  Show     = function() end,
}

libs["AceConfig-3.0"] = {
  RegisterOptionsTable = function(self, name, tbl)
    TEST.registered.options[name] = tbl
  end,
}

libs["AceConfigDialog-3.0"] = {
  AddToBlizOptions = function(self, name, title)
    return nil, stubframe()
  end,
}

libs["AceConsole-3.0"] = {
  RegisterChatCommand = function(self, cmd, fn)
    TEST.registered.commands[cmd] = fn
  end,
}

LibStub = setmetatable({
  GetLibrary = function(self, name, silent)
    libs[name] = libs[name] or {}
    return libs[name]
  end,
}, {
  __call = function(self, name, silent)
    libs[name] = libs[name] or {}
    return libs[name]
  end,
})

-- --- Social / roster APIs --------------------------------------------------
BNET_CLIENT_WOW = "WoW"
BNET_CLIENT_APP = "App"
GetRealmName            = function() return "TestRealm" end
GetNumClasses           = function() return 13 end
GetClassInfo            = function(i) return "Warrior", "WARRIOR", i end
GetPlayerInfoByGUID     = function() return "Human", "WARRIOR", "Warrior" end
GetGuildInfo            = function() return "Test Guild", "Member", 1 end
GetGuildRosterShowOffline = function() return true end
GetNumGuildMembers      = function() return #TEST.guild, #TEST.guild end
GetGuildRosterInfo      = function(i)
  local g = TEST.guild[i]
  if not g then return nil end
  return g.name, g.rank, g.rankIndex, g.level, g.class, g.zone, g.note,
         g.officerNote, g.online, g.status, g.classFileName, nil, nil,
         g.isMobile, nil, nil, g.guid
end

BNInviteFriend    = function() end
BNGetFriendIndex  = function() return 1 end
BNGetNumFriends   = function() return #TEST.bnFriends, #TEST.bnFriends end

C_AddOns    = { IsAddOnLoaded = function() return true end }
C_PartyInfo = { InviteUnit = function() end }
C_UIColor   = { GetColors = function() return {} end }

C_Timer = {
  After    = function() end,
  NewTimer = function() return { Cancel = function() end } end,
}

C_BattleNet = {
  GetFriendAccountInfo = function(i) return TEST.bnFriends[i] end,
  GetFriendNumGameAccounts = function(i)
    local f = TEST.bnFriends[i]
    if not f then return 0 end
    local ga = TEST.gameAccounts[f.bnetAccountID]
    return ga and #ga or 0
  end,
  GetFriendGameAccountInfo = function(i, j)
    local f = TEST.bnFriends[i]
    if not f then return nil end
    local ga = TEST.gameAccounts[f.bnetAccountID]
    return ga and ga[j] or nil
  end,
}

C_FriendList = {
  GetNumFriends       = function() return 0 end,
  GetNumOnlineFriends = function() return 0 end,
  GetFriendInfo       = function() return nil end,
  GetFriendInfoByIndex = function() return nil end,
  SendWho             = function() end,
}

C_GuildInfo = {
  GuildRoster         = function() end,
  CanViewOfficerNote  = function() return true end,
}

C_Club = {
  GetSubscribedClubs = function() return TEST.clubs end,
  GetClubMembers     = function(clubId) return TEST.clubMembers[clubId] or {} end,
  GetMemberInfo      = function(clubId, memberId)
    local members = TEST.clubMembers[clubId] or {}
    for _, m in ipairs(members) do
      if m.memberId == memberId then return m end
    end
    return nil
  end,
  SetClubPresenceSubscription = function() end,
}
"""
