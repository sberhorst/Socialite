local
---@class string
addonName,
---@class ns
addon = ...

local L = addon.L
local tooltip = addon.tooltip

local BNGetFriendGameAccountInfo = C_BattleNet.GetFriendGameAccountInfo;
local BNGetFriendInfo = C_BattleNet.GetFriendAccountInfo;
local playerRealmName = GetRealmName()

local MOBILE_HERE_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:0:0:0:0:16:16:0:16:0:16:73:177:73|t"
local MOBILE_BUSY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-BusyMobile:0:0:0:0:16:16:0:16:0:16|t"
local MOBILE_AWAY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-AwayMobile:0:0:0:0:16:16:0:16:0:16|t"
local CHECK_ICON = "|TInterface\\Buttons\\UI-CheckBox-Check:0:0|t"

local function ternary(cond, a, b)
  if cond then return a end
  return b
end

local function normal(text)
  if not text then return "" end
  return NORMAL_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE;
end

local function highlight(text)
  if not text then return "" end
  return HIGHLIGHT_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE;
end

local function muted(text)
  if not text then return "" end
  return DISABLED_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE;
end

local function IsOfficerNoteVisible(...)
  if (not addon.db.ShowGuildONote) then return false end
  if (type(CanViewOfficerNote) == "function") then
    return CanViewOfficerNote(...)
  end
  return C_GuildInfo.CanViewOfficerNote(...)
end

-- Class support
local Classes = {}
for i = 1, _G.GetNumClasses() do
  local name, className, classId = _G.GetClassInfo(i)
  Classes[_G.LOCALIZED_CLASS_NAMES_MALE[className]] = className
  Classes[_G.LOCALIZED_CLASS_NAMES_FEMALE[className]] = className
end

local function addDoubleLine(indented, left, right)
  if indented then
    return tooltip:AddLine(nil, nil, left, right)
  else
    return tooltip:AddColspanLine(3, "LEFT", left, 1, "RIGHT", right)
  end
end

local clickHeader
local function addHeader(header, color, online, total, collapsed, collapseVar)
  header = header..":"
  local left = normal(header)
  if collapsed then
    left = left.." |cff808080"..L.TOOLTIP_COLLAPSED.."|r"
  end
  if color then color = "|cff"..color end
  local right = (color or "")..(online or "")..(color and "|r")..normal("/"..total)
  local y = addDoubleLine(false, left, right)
  tooltip:SetLineScript(y, "OnMouseDown", clickHeader, collapseVar)
  return y
end

clickHeader = function(frame, collapseVar)
  addon.db[collapseVar] = not addon.db[collapseVar]
  if addon._tooltipAnchorFrame then
    addon:updateTooltip(addon._tooltipAnchorFrame)
  end
end

local function colorText(text, className)
  local class = Classes[className]
  local color
  if class == nil then
    color = "ffcccccc"
  else
    color = RAID_CLASS_COLORS[class].colorStr
  end
  return "|c"..color..text.."|r"
end

local function getStatusIcon(status)
  if addon.db.ShowStatus == "icon" then
    if status == CHAT_FLAG_AFK then
      return "|T"..FRIENDS_TEXTURE_AFK..":0|t"
    elseif status == CHAT_FLAG_DND then
      return "|T"..FRIENDS_TEXTURE_DND..":0|t"
    end
  end
  return ""
end

local function getStatusText(status)
  if addon.db.ShowStatus == "text" then
    if status ~= "" then
      return "|cffFFFFFF"..tostring(status).."|r "
    end
  end
  return ""
end

-- 12.x right-click context menu via MenuUtil (UIDropDownMenuTemplate removed in TWW)
local function showGuildRightClick(player, isMobile)
  -- "none" strips the realm suffix for display regardless of cross-realm status.
  -- The full Name-Realm string is kept for API calls that require it.
  local displayName = Ambiguate(player, "none")
  MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
    rootDescription:CreateTitle(displayName)
    rootDescription:CreateButton(WHISPER, function()
      ChatFrame_SendTell(displayName)
    end)
    if not isMobile then
      rootDescription:CreateButton(INVITE, function()
        C_PartyInfo.InviteUnit(player)
      end)
    end
    rootDescription:CreateDivider()
    rootDescription:CreateButton(WHO, function()
      C_FriendList.SendWho("n-" .. displayName)
    end)
  end)
end

-- 12.x right-click context menu for community members (UIDropDownMenuTemplate removed in TWW)
local function showCommunityRightClick(player)
  local displayName = Ambiguate(player, "none")
  MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
    rootDescription:CreateTitle(displayName)
    rootDescription:CreateButton(WHISPER, function()
      ChatFrame_SendTell(displayName)
    end)
    rootDescription:CreateButton(INVITE, function()
      C_PartyInfo.InviteUnit(player)
    end)
    rootDescription:CreateDivider()
    rootDescription:CreateButton(WHO, function()
      C_FriendList.SendWho("n-" .. displayName)
    end)
  end)
end

-- memberType distinguishes which right-click menu / left-click behavior to use:
--   "guild"     -> guild member dropdown
--   "community" -> community member dropdown (added: communities weren't clickable before)
--   nil/other   -> character friend dropdown (default, preserves old behavior)
local function clickPlayer(frame, info, button)
  local player, memberType, isMobile = unpack(info)
  if player ~= "" then
    if button == "LeftButton" then
      if IsAltKeyDown() then
        C_PartyInfo.InviteUnit(player)
      else
        ChatFrame_SendTell(Ambiguate(player, "none"))
      end
    elseif button == "RightButton" then
      if memberType == "guild" then
        showGuildRightClick(player, isMobile)
      elseif memberType == "community" then
        showCommunityRightClick(player)
      else
        local info = C_FriendList.GetFriendInfo(player);
        FriendsFrame_ShowDropdown(info.name, info.connected, nil, nil, nil, 1);
      end
    end
  end
end

local function sendBattleNetInvite(bnetAccountID)
  local playerFactionGroup = UnitFactionGroup("player")
  local index = BNGetFriendIndex(bnetAccountID)
  if index then
    local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(index)
    if numGameAccounts > 1 then
      local validGameAccountID = nil
      for i = 1, numGameAccounts do
        local _, _, client, _, realmID, faction, _, _, _, _, _, _, _, _, _, bnetIDGameAccount = BNGetFriendGameAccountInfo(index, i)
        if client == BNET_CLIENT_WOW and faction == playerFactionGroup and realmID ~= 0 then
          if validGameAccountID and validGameAccountID ~= bnetIDGameAccount then
            validGameAccountID = nil
            break
          else
            validGameAccountID = bnetIDGameAccount
          end
        end
      end
      if validGameAccountID then
        BNInviteFriend(validGameAccountID)
        return
      end
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
      local dropDown = TravelPassDropDown
      if dropDown.index ~= index then Lib_CloseDropDownMenus() end
      dropDown.index = index
      Lib_ToggleDropDownMenu(1, nil, dropDown, "cursor", 1, -1)
    else
      local bnetIDGameAccount = select(6, BNGetFriendInfo(index))
      if bnetIDGameAccount then BNInviteFriend(bnetIDGameAccount) end
    end
  end
end

local function clickRealID(frame, info, button)
  local accountName, bnetAccountID = unpack(info)
  if button == "LeftButton" then
    if IsAltKeyDown() then
      if CanGroupWithAccount(bnetAccountID) then
        sendBattleNetInvite(bnetAccountID)
      end
    else
      ChatFrameUtil.SendBNetTell(accountName)
    end
  elseif button == "RightButton" then
    FriendsFrame_ShowBNDropdown(accountName, true, nil, nil, nil, 1, bnetAccountID);
  end
end

local function spacer(width, count)
  if not width then width = 0 end
  if not count then count = 1 end
  local height = (width == 0) and 0 or 1
  return ("|T:"..height..":"..width.."|t"):rep(count)
end

local function getGroupIndicator(info)
  if not addon.db.ShowGroupMembers or not IsInGroup() then return "" end
  local name
  if info.focus then
    if info.focus.realmName and info.focus.realmName ~= playerRealmName then
      name = info.focus.name.."-"..info.focus.realmName
    else
      name = info.focus.name
    end
  elseif info.realmName then
    name = info.name.."-"..info.realmName
  else
    name = info.name
  end
  if UnitInParty(name) or UnitInRaid(name) then return CHECK_ICON end
  return spacer()
end

function addon:parseRealID(filterClients)
  local function getLocation(ai)
    if ai.clientProgram == BNET_CLIENT_WOW and ai.realmName == playerRealmName then
      return ai.areaName
    end
    return ai.richPresence
  end

  local _, numOnline = BNGetNumFriends()
  local friends, bnets = {}, {}

  for i=1, numOnline do
    local accountInfo = C_BattleNet.GetFriendAccountInfo(i);
    local toons, focus, bnet = {}, nil, nil

    for j=1, C_BattleNet.GetFriendNumGameAccounts(i) do
      local ai = C_BattleNet.GetFriendGameAccountInfo(i, j)
      local toon = {
        name = ai.characterName,
        client = ai.clientProgram,
        realmName = ai.realmName,
        realmID = ai.realmID,
        faction = ai.factionName,
        race = ai.raceName,
        class = ai.className,
        zone = ai.areaName,
        level = ai.characterLevel,
        location = getLocation(ai),
      }
      if ai.clientProgram == BNET_CLIENT_APP or ai.clientProgram == "BSAp" then
        if not bnet then bnet = toon end
      elseif ai.hasFocus then
        if focus ~= nil then table.insert(toons, 1, focus) end
        focus = toon
      else
        table.insert(toons, toon)
      end
    end

    if focus == nil and #toons > 0 then
      focus = toons[1]
      table.remove(toons, 1)
    end

    if focus ~= nil or bnet ~= nil then
      local friend = {
        bnetAccountID = accountInfo.bnetAccountID,
        accountName = accountInfo.accountName,
        battleTag = ternary(accountInfo.isBattleTagFriend, accountInfo.battleTag, accountInfo.accountName),
        isAFK = accountInfo.gameAccountInfo.isAFK,
        isDND = accountInfo.gameAccountInfo.isDND,
        broadcastText = accountInfo.broadcastText,
        note = accountInfo.note,
        focus = focus,
        alts = toons,
        bnet = bnet
      }
      if focus ~= nil then table.insert(friends, friend) end
      if bnet ~= nil and (not filterClients or focus == nil) then table.insert(bnets, friend) end
    end
  end

  return friends, bnets
end

function addon:countRealID(filterClients)
  local friends, bnet = 0, 0
  local _, numOnline = BNGetNumFriends()
  for i=1, numOnline do
    local ai = C_BattleNet.GetFriendAccountInfo(i);
    local ga = ai and ai.gameAccountInfo
    if (ga and ga.clientProgram == BNET_CLIENT_APP) or (ga and ga.clientProgram == "BSAp") then
      bnet = bnet + 1
    else
      if (ga and ga.clientProgram ~= "") then
        friends = friends + 1
      end
    end
  end
  return friends, bnet
end

function addon:renderBattleNet(tooltip, friends, isBnetClient, collapseVar)
  local function getFactionIndicator(faction, client)
    if addon.db.ShowRealIDFactions then
      if client == BNET_CLIENT_WOW then
        if faction == "Horde" or faction == "Alliance" then
          return "|TInterface\\PVPFrame\\PVP-Currency-"..faction..":0|t"
        elseif faction == "Neutral" then
          return "|TInterface\\FriendsFrame\\Battlenet-WoWicon:0|t"
        end
      elseif client and client ~= "" then
        return BNet_GetClientEmbeddedAtlas(client)
      end
      return spacer()
    end
    return ""
  end

  addon.tooltip:AddLine()
  local numTotal = BNGetNumFriends()
  local header = isBnetClient and L.TOOLTIP_REALID_APP or L.TOOLTIP_REALID
  local collapsed = addon.db[collapseVar]
  addHeader(header, "00A2E8", #friends, numTotal, collapsed, collapseVar)
  if collapsed then return end

  for _, friend in ipairs(friends) do
    local left = ""
    local focus = isBnetClient and friend.bnet or friend.focus
    local check = getGroupIndicator(friend)
    local playerStatus = ""
    if friend.isAFK then
      playerStatus = CHAT_FLAG_AFK
    elseif friend.isDND then
      playerStatus = CHAT_FLAG_DND
    end

    local level = friend.level
    do
      local name
      if focus.client == BNET_CLIENT_WOW then
        level = "|cffFFFFFF"..focus.level.."|r"
        name = focus.name and colorText(focus.name, focus.class) or "|cffFFFFFFUnknown|r"
      else
        local clientname = focus.client
        if clientname == BNET_CLIENT_WTCG then clientname = "HS"
        elseif clientname == "App" then clientname = "BN" end
        level = "|cffFFFFFF"..(clientname or "??").."|r"
        name = "|cffCCCCCC"..(focus.name or "").."|r"
      end
      left = left..getFactionIndicator(focus.faction, focus.client).." "
      left = left..getStatusIcon(playerStatus)
      left = left..name.." "
    end

    left = left.."[|cff00A2E8"..friend.battleTag.."|r] "
    left = left..getStatusText(playerStatus).." "

    local broadcastText = friend.broadcastText
    if addon.db.ShowRealIDNotes then
      local note = friend.note
      if note and note ~= "" then
        left = left.."|cffFFFFFF"..note.."|r"
        if broadcastText and broadcastText ~= "" then
          broadcastText = "\n"..broadcastText
        end
      end
    end

    local extraLines
    if addon.db.ShowRealIDBroadcasts then
      if broadcastText and broadcastText ~= "" then
        local color = "|cff00A2E8"
        local firstLine = broadcastText:match("^([^\n]*)\n")
        if firstLine then
          extraLines = {}
          for line in broadcastText:gmatch("\n([^\n]*)") do
            extraLines[#extraLines+1] = color..line.."|r"
          end
          broadcastText = firstLine
        end
        if broadcastText ~= "" then
          left = left..color..broadcastText.."|r"
        end
      end
    end

    local right = focus.location and focus.location ~= "" and ("|cffFFFFFF"..focus.location.."|r") or ""
    local y = addon.tooltip:AddLine(check, level, left, right)
    addon.tooltip:SetLineScript(y, "OnMouseDown", clickRealID, { friend.accountName, friend.bnetAccountID })

    if extraLines then
      for _, line in ipairs(extraLines) do
        addDoubleLine(true, line)
      end
    end

    if friend.alts ~= nil then
      local playerFactionGroup = UnitFactionGroup("player")
      for _, toon in ipairs(friend.alts) do
        local left, right
        if toon.client == BNET_CLIENT_WOW then
          local cooperateLabel = ""
          if toon.realmName ~= playerRealmName or toon.faction ~= playerFactionGroup then
            cooperateLabel = _G.CANNOT_COOPERATE_LABEL
          end
          left = _G.FRIENDS_TOOLTIP_WOW_TOON_TEMPLATE:format(tostring(toon.name)..cooperateLabel, tostring(toon.level), tostring(toon.race), tostring(toon.class))
        else
          left = toon.name
        end
        left = getFactionIndicator(toon.faction, toon.client).."|cffFEE15C"..FRIENDS_LIST_PLAYING.."|cffFFFFFF "..(left or "Unknown").."|r"
        right = "|cffFFFFFF"..(toon.location or "").."|r"
        addDoubleLine(true, left, right)
      end
    end
  end
end

function addon:renderFriends(tooltip, collapseVar)
  addon.tooltip:AddLine()
  local numTotal = C_FriendList.GetNumFriends()
  local numOnline = C_FriendList.GetNumOnlineFriends()
  local collapsed = addon.db[collapseVar]
  addHeader(L.TOOLTIP_FRIENDS, "FFFFFF", numOnline, numTotal, collapsed, collapseVar)
  if collapsed then return end

  for i=1, numOnline do
    local left = ""
    local info = C_FriendList.GetFriendInfoByIndex(i)
    local playerStatus = nil
    if info.afk == true then
      playerStatus = _G.CHAT_FLAG_AFK
    elseif info.dnd == true then
      playerStatus = _G.CHAT_FLAG_DND
    end

    local check = getGroupIndicator(info)
    local level = "|cffFFFFFF"..info.level.."|r"
    left = left..getStatusIcon(playerStatus)
    left = left..colorText(info.name, info.className).." "
    left = left..getStatusText(playerStatus).." "

    if addon.db.ShowFriendsNote then
      if info.notes and info.notes ~= "" then
        left = left.."|cffFFFFFF"..info.notes.."|r "
      end
    end

    local right = ""
    if info.area ~= nil then
      right = "|cffFFFFFF"..info.area.."|r"
    end

    local y = addon.tooltip:AddLine(check, level, left, right)
    addon.tooltip:SetLineScript(y, "OnMouseDown", clickPlayer, { info.name, nil, false })
  end
end

function addon:renderGuild(tooltip, collapseGuildVar)
  -- FIX: bail immediately if not in a guild — prevents nil errors on
  -- GetNumGuildMembers(), SetGuildRosterShowOffline(), GetGuildRosterInfo()
  if not IsInGuild() then return end

  -- Built while iterating the roster below; used by renderCommunities to
  -- backfill class/level for community members who are also guildmates
  -- (the Club API itself has no class/level data — see renderCommunities).
  addon._guildRosterByGUID = addon._guildRosterByGUID or {}
  table.wipe(addon._guildRosterByGUID)

  local function processGuildMember(i, tooltip)
    local left = ""
    local name, rank, rankIndex, level, class, zone, note, officerNote, online, playerStatus, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
    local origname = name

    if guid then
      addon._guildRosterByGUID[guid] = { class = class, level = level }
    end

    name = Ambiguate(name, "guild")
    local check = getGroupIndicator({ name = name })

    if name == "" then name = "Unknown" end

    if playerStatus == 1 then
      playerStatus = CHAT_FLAG_AFK
    elseif playerStatus == 2 then
      playerStatus = CHAT_FLAG_DND
    else
      playerStatus = ""
    end

    if isMobile then
      if playerStatus == CHAT_FLAG_DND then
        name = MOBILE_BUSY_ICON..name
      elseif playerStatus == CHAT_FLAG_AFK then
        name = MOBILE_AWAY_ICON..name
      else
        name = MOBILE_HERE_ICON..name
      end
    end

    local level = "|cffFFFFFF"..level.."|r"

    if not isMobile then
      left = left..getStatusIcon(playerStatus)
    end

    left = left..colorText(name, class).." "
    left = left..getStatusText(playerStatus).." "
    left = left..rank.." "

    if addon.db.ShowGuildNote then
      if note and note ~= "" then
        left = left.."|cffFFFFFF"..note.."|r "
      end
    end

    if IsOfficerNoteVisible() then
      if officerNote and officerNote ~= "" then
        left = left.."|cffAAFFAA"..officerNote.."|r "
      end
    end

    local right = ""
    if zone and zone ~= "" then
      right = "|cffFFFFFF"..zone.."|r"
    end

    local y = addon.tooltip:AddLine(check, level, left, right)
    addon.tooltip:SetLineScript(y, "OnMouseDown", clickPlayer, { origname, "guild", isMobile })
  end

  local function collectGuildRosterInfo(sortKey, sortAscending)
    SetGuildRosterShowOffline(false)
    -- FIX: nil-coalesce in case API returns nil while roster is loading
    local guildTotal, guildOnline = GetNumGuildMembers()
    guildTotal  = guildTotal  or 0
    guildOnline = guildOnline or 0

    local onlineTable = {}
    for i = 1, guildOnline do
      onlineTable[i] = i
    end

    if sortKey then
      local function sortFunc(a, b)
        local aname, _, arankIndex, alevel, aclass, azone, anote = GetGuildRosterInfo(a)
        local bname, _, brankIndex, blevel, bclass, bzone, bnote = GetGuildRosterInfo(b)
        if sortKey == "rank" and arankIndex ~= brankIndex then
          return ternary(sortAscending, arankIndex > brankIndex, arankIndex < brankIndex)
        end
        if sortKey == "level" and alevel ~= blevel then
          return ternary(sortAscending, alevel < blevel, alevel > blevel)
        end
        if sortKey == "class" and aclass ~= bclass then
          return ternary(sortAscending, aclass < bclass, aclass > bclass)
        end
        if sortKey == "zone" and azone ~= bzone then
          if azone == nil then azone = "" end
          if bzone == nil then bzone = "" end
          return ternary(sortAscending, azone < bzone, azone > bzone)
        end
        if sortKey == "note" and anote ~= bnote then
          return ternary(sortAscending, anote < bnote, anote > bnote)
        end
        aname = string.lower(aname or "Unknown")
        bname = string.lower(bname or "Unknown")
        if sortAscending or sortKey ~= "name" then
          return aname < bname
        else
          return aname > bname
        end
      end
      table.sort(onlineTable, sortFunc)
    end

    return onlineTable, guildTotal, guildOnline
  end

  addon.tooltip:AddLine()

  local wasOffline = GetGuildRosterShowOffline()
  if wasOffline then SetGuildRosterShowOffline(false) end

  local sortKey = addon.db.GuildSort and addon.db.GuildSortKey or nil
  local roster, numTotal, numOnline = collectGuildRosterInfo(sortKey, addon.db.GuildSortAscending or false)

  local collapseGuild = addon.db[collapseGuildVar]
  addHeader(L.TOOLTIP_GUILD, "00FF00", numOnline, numTotal, collapseGuild, collapseGuildVar)

  -- FIX: only render members when section is not collapsed
  if not collapseGuild then
    for i, guildIndex in ipairs(roster) do
      processGuildMember(guildIndex, tooltip)
    end
  end

  if wasOffline then SetGuildRosterShowOffline(wasOffline) end
end

-- Renders one community block per subscribed Character-type club (in-game Community),
-- showing online/away/busy members. Excludes the player's guild (handled separately).
function addon:renderCommunities(frame)
  if not addon.db.ShowCommunities then return end

  -- C_Club.GetSubscribedClubs() returns all clubs the player belongs to.
  -- Confirmed via Blizzard's EnumerationTables.lua:
  --   Enum.ClubType.BattleNet = 0  (Battle.net-account-wide clubs — rare, not what players call "Communities")
  --   Enum.ClubType.Character = 1  (in-game Communities created via Guild & Communities panel — this is what we want)
  --   Enum.ClubType.Guild     = 2  (the player's guild, already handled by renderGuild)
  --   Enum.ClubType.Other     = 3
  local clubs = C_Club.GetSubscribedClubs()
  if not clubs or #clubs == 0 then return end

  local communityClubs = {}
  for _, club in ipairs(clubs) do
    if club.clubType == Enum.ClubType.Character then
      table.insert(communityClubs, club)
    end
  end
  if #communityClubs == 0 then return end

  -- Sort communities alphabetically by name for consistent ordering
  table.sort(communityClubs, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  for _, club in ipairs(communityClubs) do
    local clubId    = club.clubId
    local clubName  = club.name or L.TOOLTIP_COMMUNITY
    -- collapseVar is per-club so each can be collapsed independently
    local collapseVar = "CollapseComm_" .. clubId

    -- Ensure the per-club collapse key is initialised
    if addon.db[collapseVar] == nil then
      addon.db[collapseVar] = false
    end

    -- Enumerate members and filter to those currently online,
    -- skipping the player's own entry (isSelf).
    local memberIds = C_Club.GetClubMembers(clubId)
    local online, total = {}, 0

    for _, memberId in ipairs(memberIds) do
      local info = C_Club.GetMemberInfo(clubId, memberId)
      if info and not info.isSelf then
        total = total + 1
        -- Matches Blizzard's own CommunitiesMemberListMixin:UpdateMemberCount,
        -- which counts Online, Away, and Busy as "online" (just AFK/DND variants).
        local presence = info.presence
        if presence == Enum.ClubMemberPresence.Online
          or presence == Enum.ClubMemberPresence.OnlineMobile
          or presence == Enum.ClubMemberPresence.Away
          or presence == Enum.ClubMemberPresence.Busy then
          table.insert(online, info)
        end
      end
    end

    -- Sort online members alphabetically
    table.sort(online, function(a, b)
      return (a.name or "") < (b.name or "")
    end)

    addon.tooltip:AddLine()
    local collapsed = addon.db[collapseVar]
    -- Reuse gold colour (FFD200) to distinguish communities from guild (green)
    addHeader(clubName, "FFD200", #online, total, collapsed, collapseVar)

    if not collapsed then
      for _, memberInfo in ipairs(online) do
        local name = memberInfo.name or "Unknown"
        local isMobile = (memberInfo.presence == Enum.ClubMemberPresence.OnlineMobile)

        -- Map club presence to the same playerStatus values used by
        -- getStatusIcon/getStatusText for guild and friends, so the
        -- AFK/DND icon and group-check column line up visually.
        local playerStatus = ""
        if memberInfo.presence == Enum.ClubMemberPresence.Away then
          playerStatus = CHAT_FLAG_AFK
        elseif memberInfo.presence == Enum.ClubMemberPresence.Busy then
          playerStatus = CHAT_FLAG_DND
        end

        local check = getGroupIndicator({ name = Ambiguate(name, "none") })

        -- C_Club.GetMemberInfo doesn't include class/level directly, but it
        -- does give us memberInfo.guid. GetPlayerInfoByGUID(guid) works for
        -- ANY character GUID (online, offline, any realm) with no inspect or
        -- group/guild requirement — it's how Blizzard's own Communities panel
        -- class-colors names. This is the primary path for class color.
        --
        -- Character level isn't returned by GetPlayerInfoByGUID, so for level
        -- specifically we fall back to cross-referencing the guild roster
        -- (addon._guildRosterByGUID, built in renderGuild) when this member
        -- also happens to be a guildmate. If neither source has data, the
        -- member renders with no class color / no level — there's nothing
        -- further to query.
        local localizedClass = nil
        if memberInfo.guid then
          local ok, result = pcall(GetPlayerInfoByGUID, memberInfo.guid)
          if ok then localizedClass = result end
        end

        local rosterMatch = memberInfo.guid and addon._guildRosterByGUID and addon._guildRosterByGUID[memberInfo.guid]
        local levelText = nil
        if rosterMatch and rosterMatch.level then
          levelText = "|cffFFFFFF"..rosterMatch.level.."|r"
        end

        local left = ""
        if isMobile then
          left = left..MOBILE_HERE_ICON
        else
          left = left..getStatusIcon(playerStatus)
        end

        if localizedClass then
          left = left..colorText(name, localizedClass).." "
        else
          left = left.."|cffFFFFFF"..name.."|r "
        end
        left = left..getStatusText(playerStatus)

        local right = ""

        local y = addon.tooltip:AddLine(check, levelText, left, right)
        -- name is in "Name-Realm" format, same as guild roster — clickPlayer
        -- and the right-click menu already handle stripping the realm for display.
        addon.tooltip:SetLineScript(y, "OnMouseDown", clickPlayer, { name, "community", isMobile })
      end
    end
  end
end
