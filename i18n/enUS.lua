local
---@class string
addonName,
---@class ns
addon = ...

local L = {}
addon.L = L

-- Core
L["Socialite"]                      = "Socialite"
L["usageDescription"]               = "Left-click to open Friends/Guild. Right-click to configure. Alt+Left-click a name to invite."

-- Tooltip section headers
L["TOOLTIP_REALID"]                 = "Battle.net Friends"
L["TOOLTIP_REALID_APP"]             = "Battle.net App"
L["TOOLTIP_FRIENDS"]                = "Friends"
L["TOOLTIP_GUILD"]                  = "Guild"
L["TOOLTIP_COLLAPSED"]              = "(collapsed)"

-- Config panel — top-level toggles
L["Show minimap button"]            = "Show Minimap Button"
L["Show the Socialite minimap button"] = "Show or hide the Socialite minimap button."
L["showInAddonCompartment"]         = "Show in Addon Compartment"
L["showInAddonCompartmentDescription"] = "Show Socialite in the addon compartment button area."
L["DisableUsageText"]               = "Hide Usage Text"
L["DisableUsageTextDescription"]    = "Hide the usage hint line from the top of the tooltip."

-- Config panel — Battle.net section
L["Battle.net Friends"]             = "Battle.net Friends"
L["ShowRealID"]                     = "Show Battle.net Friends"
L["ShowRealIDDescription"]          = "Show online Battle.net friends in the tooltip."
L["ShowRealIDBroadcasts"]           = "Show Broadcasts"
L["ShowRealIDBroadcastsDescription"] = "Show Battle.net friend broadcast messages."
L["ShowRealIDFactions"]             = "Show Factions"
L["ShowRealIDFactionsDescription"]  = "Show faction icons next to Battle.net friends."
L["ShowRealIDNotes"]                = "Show Notes"
L["ShowRealIDNotesDescription"]     = "Show friend notes next to Battle.net friends."
L["ShowRealIDApp"]                  = "Show Battle.net App Friends"
L["ShowRealIDAppDescription"]       = "Show friends who are in the Battle.net App (not in a game)."

-- Config panel — Character Friends section
L["Character Friends"]              = "Character Friends"
L["ShowFriends"]                    = "Show Character Friends"
L["ShowFriendsDescription"]         = "Show online character friends in the tooltip."
L["ShowFriendsNote"]                = "Show Friend Notes"
L["ShowFriendsNoteDescription"]     = "Show notes next to character friends."

-- Config panel — Data text section
L["Data text"]                      = "Data Text"
L["ShowLabel"]                      = "Show Label"
L["ShowLabelDescription"]           = "Show the guild name or 'Socialite' label in the data text."

-- Config panel — Tooltip section
L["Tooltip Settings"]               = "Tooltip Settings"
L["Tooltip Width"]                  = "Extra Tooltip Width"
L["MENU_STATUS"]                    = "Show Status As"
L["MENU_STATUS_ICON"]               = "Icon"
L["MENU_STATUS_TEXT"]               = "Text"
L["MENU_STATUS_NONE"]               = "None"
L["MENU_INTERACTION"]               = "Tooltip Interaction"
L["MENU_INTERACTION_ALWAYS"]        = "Always"
L["MENU_INTERACTION_OOC"]           = "Out of Combat"
L["MENU_INTERACTION_NEVER"]         = "Never"
L["ShowGroupMembers"]               = "Highlight Group Members"
L["ShowGroupMembersDescription"]    = "Show a checkmark next to friends or guild members who are in your current group."

-- Config panel — Guild section
L["Guild Members"]                  = "Guild Members"
L["ShowGuild"]                      = "Show Guild Members"
L["ShowGuildDescription"]           = "Show online guild members in the tooltip."
L["ShowGuildLabel"]                 = "Show Guild Name in Label"
L["ShowGuildLabelDescription"]      = "Show your guild name instead of 'Socialite' in the data text label."
L["ShowGuildNote"]                  = "Show Guild Notes"
L["ShowGuildNoteDescription"]       = "Show public guild notes next to guild members."
L["ShowGuildONote"]                 = "Show Officer Notes"
L["ShowGuildONoteDescription"]      = "Show officer notes next to guild members (requires officer rank)."
L["Guild Sorting"]                  = "Guild Sorting"
L["GuildSort"]                      = "Enable Guild Sorting"
L["GuildSortDescription"]           = "Sort the guild member list."
L["GuildSortAscending"]             = "Sort Ascending"
L["GuildSortAscendingDescription"]  = "Sort guild members in ascending order."
L["MENU_GUILD_SORT"]                = "Sort By"
L["MENU_GUILD_SORT_NAME"]           = "Name"
L["MENU_GUILD_SORT_RANK"]           = "Rank"
L["MENU_GUILD_SORT_CLASS"]          = "Class"
L["MENU_GUILD_SORT_NOTE"]           = "Note"
L["MENU_GUILD_SORT_LEVEL"]          = "Level"
L["MENU_GUILD_SORT_ZONE"]           = "Zone"

-- Communities
L["Communities"]                    = "Communities"
L["ShowCommunities"]                = "Show Communities"
L["ShowCommunitiesDescription"]     = "Show online members of your BattleNet communities in the tooltip."
L["TOOLTIP_COMMUNITY"]              = "Community"
