local
---@class string
addonName,
---@class ns
addon = ...

local L = addon.L
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local ldbi = LibStub:GetLibrary('LibDBIcon-1.0')

local function print(...) _G.print("|c259054ffSocialite:|r", ...) end

local function showConfig()
  Settings.OpenToCategory(addon.optionsFrame)
end

local function normal(text)
  if not text then return "" end
  return NORMAL_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE;
end

local function muted(text)
  if not text then return "" end
  return DISABLED_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE;
end

-- Init & config panel
do
  local eventFrame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
  eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    if type(SocialiteSettings) ~= "table" then SocialiteSettings = {
      minimap={hide=true},
      showInAddonCompartment=true,
      DisableUsageText=false,
      TooltipWidth=0,
    } end

    local sv = SocialiteSettings
    if type(sv.minimap) ~= "table" then sv.minimap = {hide=true} end
    if type(sv.showInAddonCompartment) ~= "boolean" then sv.showInAddonCompartment = true end
    if type(sv.DisableUsageText) ~= "boolean" then sv.DisableUsageText = false end
    if type(sv.ShowLabel) ~= "boolean" then sv.ShowLabel = true end
    if type(sv.ShowRealID) ~= "boolean" then sv.ShowRealID = true end
    if type(sv.ShowRealIDApp) ~= "boolean" then sv.ShowRealIDApp = false end
    if type(sv.ShowRealIDBroadcasts) ~= "boolean" then sv.ShowRealIDBroadcasts = true end
    if type(sv.ShowRealIDFactions) ~= "boolean" then sv.ShowRealIDFactions = true end
    if type(sv.ShowRealIDNotes) ~= "boolean" then sv.ShowRealIDNotes = true end
    if type(sv.ShowFriends) ~= "boolean" then sv.ShowFriends = true end
    if type(sv.ShowFriendsNote) ~= "boolean" then sv.ShowFriendsNote = true end
    if type(sv.ShowGuild) ~= "boolean" then sv.ShowGuild = true end
    if type(sv.ShowGuildLabel) ~= "boolean" then sv.ShowGuildLabel = true end
    if type(sv.ShowGuildNote) ~= "boolean" then sv.ShowGuildNote = true end
    if type(sv.ShowGuildONote) ~= "boolean" then sv.ShowGuildONote = true end
    if type(sv.GuildSort) ~= "boolean" then sv.GuildSort = false end
    if type(sv.GuildSortAscending) ~= "boolean" then sv.GuildSortAscending = false end
    if type(sv.GuildSortKey) ~= "string" then sv.GuildSortKey = "rank" end
    if type(sv.ShowGroupMembers) ~= "boolean" then sv.ShowGroupMembers = true end
    if type(sv.ShowStatus) ~= "string" then sv.ShowStatus = "icon" end
    if type(sv.TooltipInteraction) ~= "string" then sv.TooltipInteraction = "always" end
    if type(sv.TooltipWidth) ~= "number" then sv.TooltipWidth = 0 end
    if type(sv.ShowCommunities) ~= "boolean" then sv.ShowCommunities = true end

    addon.db = sv

    ldbi:Register(addonName, addon.dataobj, addon.db.minimap)
    if sv.showInAddonCompartment then ldbi:AddButtonToCompartment(addonName) end
    self:SetScript("OnEvent", nil)
  end)
  eventFrame:RegisterEvent("ADDON_LOADED")
  addon.frame = eventFrame
end

-- data text
do
  local f = CreateFrame("frame")

  local dataobj = ldb:NewDataObject("Socialite", {
    type = "data source",
    icon = "Interface\\FriendsFrame\\BroadcastIcon",
    text = "..loading..",
    OnEnter = function(frame)
      addon.tooltip:Clear("LEFT", 0, "RIGHT", "LEFT", "RIGHT")
      addon.tooltip:SetAutoHideDelay(0.2, frame)
      addon:updateTooltip(frame)
      addon.tooltip:SmartAnchorTo(frame)
      addon.tooltip:Show()
    end,
    OnLeave = function()
      local i = addon.db.TooltipInteraction
      if i == "never" or (i == "outofcombat" and InCombatLockdown()) then
        addon.tooltip:Hide()
      end
    end,
    OnClick = function(self, button)
      if button == "RightButton" or self == nil then
        showConfig()
      else
        if addon.db.ShowFriends or addon.db.ShowRealID then ToggleFriendsFrame(1) end
        -- FIX: only call ToggleGuildFrame when actually in a guild
        if addon.db.ShowGuild and IsInGuild() then ToggleGuildFrame(1) end
      end
    end
  })

  addon.dataobj = dataobj

  local function updateText()
    -- Guard: DB not yet initialised (fires before ADDON_LOADED in some edge cases)
    if not addon.db then return end

    local text = ""
    local comps = {}

    -- Prefix/guild label
    if addon.db.ShowLabel then
      if addon.db.ShowGuildLabel and addon.db.ShowGuild and IsInGuild() then
        local guildName = GetGuildInfo("player") or "<unknown>"
        text = normal(tostring(guildName)..": ")
      else
        text = L['Socialite']..': '
      end
    end

    -- Battle.net Friends
    local showRealID    = addon.db.ShowRealID
    local showRealIDApp = addon.db.ShowRealIDApp
    if showRealID then
      local friendsInGames, friendsInApps = addon:countRealID(showRealID)
      table.insert(comps, "|cff00A2E8"..friendsInGames.."|r")
      if showRealIDApp then
        table.insert(comps, "|cffcccccc"..friendsInApps.."|r")
      end
    end

    -- Character Friends
    if addon.db.ShowFriends then
      table.insert(comps, "|cffFFFFFF"..C_FriendList.GetNumOnlineFriends().."|r")
    end

    -- Guild Members — only when actually in a guild (FIX)
    if addon.db.ShowGuild and IsInGuild() then
      local _, online = GetNumGuildMembers()
      table.insert(comps, "|cff00FF00"..(online or 0).."|r")
    end

    dataobj.text = text..table.concat(comps, " |cffffd200/|r ")

    -- FIX: re-render tooltip in-place if it is already open
    if addon.tooltip:IsShown() and addon._tooltipAnchorFrame then
      addon:updateTooltip(addon._tooltipAnchorFrame)
    end
  end

  function addon:updateTooltip(frame)
    if not frame then return end

    -- Store anchor so live refresh and section-collapse clicks can re-use it
    addon._tooltipAnchorFrame = frame

    local ok, message = pcall(function()
      addon.tooltip:Clear("LEFT", 0, "RIGHT", "LEFT", "RIGHT")
      addon.tooltip:AddColspanHeader(3, "LEFT", L["Socialite"])

      if not addon.db.DisableUsageText then
        addon.tooltip:AddColspanLine(3, "LEFT", muted(L["usageDescription"]))
      end

      local showRealID    = addon.db.ShowRealID
      local showRealIDApp = addon.db.ShowRealIDApp
      if showRealID or showRealIDApp then
        local friends, bnet = addon:parseRealID(showRealID)
        if showRealID then
          addon:renderBattleNet(frame, friends, false, "CollapseRealID")
          if showRealIDApp then
            addon:renderBattleNet(frame, bnet, true, "CollapseRealIDApp")
          end
        end
      end

      if addon.db.ShowFriends then addon:renderFriends(frame, "CollapseFriends") end

      -- Guard renderGuild — prevents crash when unguilded
      if addon.db.ShowGuild and IsInGuild() then
        addon:renderGuild(frame, "CollapseGuild")
      else
        -- renderCommunities cross-references this table to backfill class/level
        -- for community members who are also guildmates; clear it when guild
        -- data isn't being scanned this refresh so stale entries can't leak in.
        if addon._guildRosterByGUID then table.wipe(addon._guildRosterByGUID) end
      end

      -- Communities (Character-type clubs, excludes guild)
      addon:renderCommunities(frame)
    end)

    if not ok then
      print("error: "..message)
      error(message, 0)
    end
  end

  -- Wrap tooltip:Hide to clear the anchor reference when the tooltip closes
  local _tooltipHide = addon.tooltip.Hide
  addon.tooltip.Hide = function(self)
    addon._tooltipAnchorFrame = nil
    _tooltipHide(self)
  end

  function addon:setDB(key, value)
    addon.db[key] = value
    updateText()
  end

  -- Debounce helper: coalesces rapid-fire events into a single updateText()
  -- call 0.5s later. Handles bursts like multiple guildmates logging in
  -- simultaneously each triggering their own GUILD_ROSTER_UPDATE.
  local debounceTimer = nil
  local function scheduleUpdate()
    if debounceTimer then
      debounceTimer:Cancel()
    end
    debounceTimer = C_Timer.NewTimer(0.5, function()
      debounceTimer = nil
      updateText()
    end)
  end

  -- Event registration
  -- NOTE: In TWW (12.x) GUILD_MEMBER_ONLINE and GUILD_MEMBER_OFFLINE no
  -- longer exist. GUILD_ROSTER_UPDATE is the single event Blizzard fires
  -- for all guild state changes including member logins and logouts.
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("GUILD_ROSTER_UPDATE")
  f:RegisterEvent("CLUB_MEMBER_UPDATED") -- community member presence change (confirmed in Blizzard_Communities source)
  f:RegisterEvent("CLUB_ADDED")          -- fires when club subscription data is ready after login
  f:RegisterEvent("FRIENDLIST_UPDATE")
  f:RegisterEvent("CHAT_MSG_BN_INLINE_TOAST_BROADCAST")
  f:RegisterEvent("BN_FRIEND_INFO_CHANGED")
  f:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
  f:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")

  f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
      -- On login, request a fresh roster from the server so
      -- GUILD_ROSTER_UPDATE fires with current data.
      if IsInGuild() then C_GuildInfo.GuildRoster() end

      -- Force-populate ClubMemberInfo structs for all communities.
      -- C_Club.GetMemberInfo() returns "Unknown" for name/guid until
      -- Blizzard's Communities UI opens, because member detail data is
      -- lazy-loaded server-side. C_Club.SetClubPresenceSubscription(clubId)
      -- is the call that triggers the server to push that data to the client
      -- (it's what Blizzard's own panel calls when it opens). Constraint:
      -- only 0 or 1 club can be subscribed for presence at a time, so we
      -- cycle through each community club in sequence with a short delay
      -- between each, then clear the subscription when done so we don't
      -- interfere with Blizzard's own Communities frame if the player opens it.
      local clubs = C_Club.GetSubscribedClubs()
      if clubs and #clubs > 0 then
        local communityClubs = {}
        for _, club in ipairs(clubs) do
          if club.clubType == Enum.ClubType.Character then
            table.insert(communityClubs, club)
          end
        end
        if #communityClubs > 0 then
          local i = 0
          local function subscribeNext()
            i = i + 1
            if i <= #communityClubs then
              C_Club.SetClubPresenceSubscription(communityClubs[i].clubId)
              -- 0.5s per club gives the server time to push member data
              -- before we move to the next. Adjust if needed for large communities.
              C_Timer.After(0.5, subscribeNext)
            else
              -- Done cycling — clear the subscription so Blizzard's
              -- own Communities frame can manage it without conflict.
              C_Club.SetClubPresenceSubscription(0)
            end
          end
          -- Small initial delay to let the club system finish initialising
          -- before we start subscribing (clubs may not all be CLUB_ADDED yet).
          C_Timer.After(1.0, subscribeNext)
        end
      end

      -- Update non-guild parts of the display immediately.
      updateText()

    elseif event == "GUILD_ROSTER_UPDATE" then
      -- Fires automatically for ALL guild changes in TWW: logins,
      -- logouts, rank changes, note edits, etc. Data is ready to read.
      -- Debounce to handle bursts of simultaneous member events.
      scheduleUpdate()

    elseif event == "CLUB_ADDED" then
      -- CLUB_ADDED fires as each club subscription becomes ready after login,
      -- often AFTER PLAYER_LOGIN — so the subscription cycle above may have
      -- run against an empty or partial club list. Re-subscribe to this
      -- specific club now that its data is confirmed available.
      local clubId = ...
      if clubId then
        C_Club.SetClubPresenceSubscription(clubId)
        C_Timer.After(0.5, function()
          C_Club.SetClubPresenceSubscription(0)
          scheduleUpdate()
        end)
      end

    else
      -- FRIENDLIST_UPDATE, BN_FRIEND_*, CHAT_MSG_BN_*, CLUB_MEMBER_UPDATED —
      -- data is immediately available for these.
      scheduleUpdate()
    end
  end)
end
