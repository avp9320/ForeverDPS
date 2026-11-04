local ADDON_NAME = ...

local FDPS = CreateFrame("Frame")
local UI
local rows = {}
local MAX_ROWS = 10
local lastFightSummary
local lastFightData

local SESSION_OVERALL = (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall) or 0
local SESSION_CURRENT = (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current) or 1
local METER_DPS = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.Dps) or 1

local defaults = {
    shown = true,
    locked = false,
    view = "current",
    scale = 1.0,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 330,
    y = 20,
    chatSummary = false,
    announce = "OFF",
    debug = false,
}

local function ApplyDefaults(db, src)
    for key, value in pairs(src) do
        if db[key] == nil then
            db[key] = value
        end
    end
end

local function DB()
    ForeverDPSDB = ForeverDPSDB or {}
    ApplyDefaults(ForeverDPSDB, defaults)
    return ForeverDPSDB
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function SafeSetText(fontString, value)
    if value == nil then
        fontString:SetText("")
        return
    end

    local ok = pcall(fontString.SetText, fontString, value)
    if not ok then
        fontString:SetText("?")
    end
end

local function FormatInteger(value)
    if value == nil or IsSecret(value) then
        return nil
    end

    local n = tonumber(value)
    if not n then
        return nil
    end

    n = math.floor(n + 0.5)
    local sign = n < 0 and "-" or ""
    local s = tostring(math.abs(n))
    local out = s

    while true do
        local replaced, count = out:gsub("^(%d+)(%d%d%d)", "%1,%2")
        out = replaced
        if count == 0 then
            break
        end
    end

    return sign .. out
end

local function ClassColor(classFilename)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if color then
        return color.r, color.g, color.b
    end
    return 0.35, 0.55, 0.85
end

local function GetSession(view)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromType then
        return nil
    end

    local sessionType = view == "overall" and SESSION_OVERALL or SESSION_CURRENT
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, METER_DPS)
    if not ok then
        return nil
    end
    return session
end

-- C_DamageMeter can return secret combat data on Forever. If the client
-- restricts iterating a session, fail quietly until the data is accessible.
local function PlayerSources(session)
    local ok, sources = pcall(function()
        local out = {}
        if not session or not session.combatSources then return out end
        for _, source in ipairs(session.combatSources) do
            local classFilename = source.classFilename
            if source.isLocalPlayer or (classFilename and classFilename ~= "") then
                out[#out + 1] = source
            end
        end
        return out
    end)
    if not ok or type(sources) ~= "table" then return {} end
    return sources
end

local function FindPlayerRank(sources)
    for i, source in ipairs(sources) do
        if source.isLocalPlayer then
            return i
        end
    end
    return nil
end

local function BuildVisibleSources(sources)
    if #sources <= MAX_ROWS then
        return sources
    end

    local visible = {}
    local playerRank = FindPlayerRank(sources)

    if playerRank and playerRank > MAX_ROWS then
        for i = 1, MAX_ROWS - 1 do
            visible[#visible + 1] = sources[i]
        end
        visible[#visible + 1] = sources[playerRank]
    else
        for i = 1, MAX_ROWS do
            visible[#visible + 1] = sources[i]
        end
    end

    return visible
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(21)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -36 - ((index - 1) * 23))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -36 - ((index - 1) * 23))

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints()
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)

    row.barBG = row:CreateTexture(nil, "BACKGROUND")
    row.barBG:SetAllPoints()
    row.barBG:SetColorTexture(0.08, 0.08, 0.08, 0.92)

    row.you = row:CreateTexture(nil, "BORDER")
    row.you:SetPoint("TOPLEFT", -1, 1)
    row.you:SetPoint("BOTTOMRIGHT", 1, -1)
    row.you:SetColorTexture(1, 0.82, 0.12, 0.24)
    row.you:Hide()

    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rank:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.rank:SetWidth(26)
    row.rank:SetJustifyH("LEFT")
    row.rank:SetTextColor(0.88, 0.88, 0.88)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.rank, "RIGHT", 1, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.name:SetJustifyH("LEFT")

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.value:SetWidth(72)
    row.value:SetJustifyH("RIGHT")
    row.value:SetTextColor(1, 1, 1)

    row:Hide()
    return row
end

local function SavePosition()
    if not UI then return end
    local db = DB()
    local point, _, relativePoint, x, y = UI:GetPoint(1)
    db.point = point or "CENTER"
    db.relativePoint = relativePoint or "CENTER"
    db.x = x or 0
    db.y = y or 0
end

local function SetLocked(locked)
    local db = DB()
    db.locked = locked and true or false
    if UI and UI.lockText then
        UI.lockText:SetText(db.locked and "LOCKED" or "")
    end
end

local function CreateUI()
    if UI then return end

    local db = DB()
    UI = CreateFrame("Frame", "ForeverDPSFrame", UIParent, "BackdropTemplate")
    UI:SetSize(285, 92)
    UI:SetScale(db.scale)
    UI:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    UI:SetMovable(true)
    UI:SetClampedToScreen(true)
    UI:EnableMouse(true)
    UI:RegisterForDrag("LeftButton")
    UI:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    UI:SetBackdropColor(0.025, 0.025, 0.035, 0.93)
    UI:SetBackdropBorderColor(0.22, 0.22, 0.28, 1)

    UI:SetScript("OnDragStart", function(self)
        if not DB().locked then
            self:StartMoving()
        end
    end)

    UI:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.title:SetPoint("TOPLEFT", UI, "TOPLEFT", 9, -8)
    UI.title:SetText("Forever DPS")

    UI.lockText = UI:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.lockText:SetPoint("LEFT", UI.title, "RIGHT", 7, 0)
    UI.lockText:SetText(db.locked and "LOCKED" or "")

    UI.modeButton = CreateFrame("Button", nil, UI, "UIPanelButtonTemplate")
    UI.modeButton:SetSize(68, 20)
    UI.modeButton:SetPoint("TOPRIGHT", UI, "TOPRIGHT", -8, -6)
    UI.modeButton:SetText(db.view == "overall" and "Overall" or "Current")
    UI.modeButton:SetScript("OnClick", function()
        local currentDB = DB()
        currentDB.view = currentDB.view == "overall" and "current" or "overall"
        UI.modeButton:SetText(currentDB.view == "overall" and "Overall" or "Current")
        FDPS:Refresh()
    end)

    UI.footer = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.footer:SetPoint("BOTTOMLEFT", UI, "BOTTOMLEFT", 9, 8)
    UI.footer:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -9, 8)
    UI.footer:SetJustifyH("CENTER")
    UI.footer:SetText("Waiting for combat")

    for i = 1, MAX_ROWS do
        rows[i] = CreateRow(UI, i)
    end

    if db.shown then
        UI:Show()
    else
        UI:Hide()
    end
end

local function SetFrameHeight(rowCount)
    if not UI then return end
    local count = math.max(1, rowCount)
    UI:SetHeight(64 + (count * 23))
end

local function UpdateRow(row, source, actualRank, topSource, postCombat)
    row.rank:SetText(actualRank .. ".")

    SafeSetText(row.name, source.name)

    local r, g, b = ClassColor(source.classFilename)
    row.bar:SetStatusBarColor(r, g, b, source.isLocalPlayer and 0.82 or 0.62)
    row.name:SetTextColor(r, g, b)
    row.you:SetShown(source.isLocalPlayer == true)

    local dps = source.amountPerSecond
    local topDPS = topSource and topSource.amountPerSecond

    if topDPS ~= nil then
        local ok = pcall(row.bar.SetMinMaxValues, row.bar, 0, topDPS)
        if not ok then
            row.bar:SetMinMaxValues(0, 1)
        end
    else
        row.bar:SetMinMaxValues(0, 1)
    end

    if dps ~= nil then
        local ok = pcall(row.bar.SetValue, row.bar, dps)
        if not ok then
            row.bar:SetValue(0)
        end
    else
        row.bar:SetValue(0)
    end

    if postCombat and not IsSecret(dps) then
        row.value:SetText(FormatInteger(dps) or "0")
    else
        SafeSetText(row.value, dps)
    end

    row:Show()
end

local function CalculateFightSummary(sources)
    if not sources or #sources == 0 then return nil end

    local playerRank = FindPlayerRank(sources)
    if not playerRank then return nil end

    local player = sources[playerRank]
    local leader = sources[1]
    if not player or not leader then return nil end

    local playerDPS = player.amountPerSecond
    local leaderDPS = leader.amountPerSecond

    if IsSecret(playerDPS) or IsSecret(leaderDPS) then
        return nil
    end

    playerDPS = tonumber(playerDPS)
    leaderDPS = tonumber(leaderDPS)
    if not playerDPS or not leaderDPS then
        return nil
    end

    local percentOfLeader = leaderDPS > 0 and math.floor((playerDPS / leaderDPS) * 100 + 0.5) or 0
    local summary = {
        rank = playerRank,
        count = #sources,
        dps = playerDPS,
        percentOfLeader = percentOfLeader,
    }

    return summary
end

local function SummaryText(summary, prefix)
    if not summary then return nil end
    local text = string.format(
        "#%d/%d - %s DPS - %d%% of #1",
        summary.rank,
        summary.count,
        FormatInteger(summary.dps) or tostring(math.floor(summary.dps + 0.5)),
        summary.percentOfLeader
    )
    if prefix then
        return prefix .. text
    end
    return text
end

local function AnnounceChannel(setting)
    if setting == "PARTY" then
        return IsInGroup(LE_PARTY_CATEGORY_HOME) and "PARTY" or nil
    elseif setting == "RAID" then
        return IsInRaid() and "RAID" or nil
    elseif setting == "INSTANCE_CHAT" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or nil
    end
    return nil
end

local function HandleFightEnded()
    C_Timer.After(0.6, function()
        local session = GetSession("current")
        local sources = PlayerSources(session)
        local summary = CalculateFightSummary(sources)
        if not summary then
            FDPS:Refresh()
            return
        end

        lastFightData = summary
        lastFightSummary = SummaryText(summary, "Forever DPS: ")

        local db = DB()
        if db.chatSummary then
            print(lastFightSummary)
        end

        local channel = AnnounceChannel(db.announce)
        if channel and SendChatMessage then
            SendChatMessage(lastFightSummary, channel)
        end

        FDPS:Refresh()
    end)
end

function FDPS:Refresh()
    if not UI then return end

    local db = DB()
    local session = GetSession(db.view)
    local sources = PlayerSources(session)
    local visibleSources = BuildVisibleSources(sources)
    local playerRank = FindPlayerRank(sources)
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")

    for i = 1, MAX_ROWS do
        rows[i]:Hide()
    end

    if #sources == 0 then
        SetFrameHeight(1)
        UI.footer:SetText("Waiting for combat")
        return
    end

    local topSource = sources[1]
    local postCombat = not inCombat

    for visibleIndex, source in ipairs(visibleSources) do
        local actualRank = visibleIndex
        if #sources > MAX_ROWS and source.isLocalPlayer and playerRank and playerRank > MAX_ROWS then
            actualRank = playerRank
        end
        UpdateRow(rows[visibleIndex], source, actualRank, topSource, postCombat)
    end

    SetFrameHeight(#visibleSources)

    if playerRank then
        if postCombat then
            local summary = CalculateFightSummary(sources)
            if summary then
                UI.footer:SetText("YOU: " .. SummaryText(summary))
            else
                UI.footer:SetText(string.format("YOU: #%d / %d", playerRank, #sources))
            end
        else
            UI.footer:SetText(string.format("YOU: #%d / %d", playerRank, #sources))
        end
    else
        UI.footer:SetText(string.format("%d players", #sources))
    end
end

local function PrintHelp()
    print("|cffd9b93eForever DPS|r commands:")
    print("/fdps show | hide | toggle")
    print("/fdps current | overall")
    print("/fdps lock | unlock")
    print("/fdps scale 0.7-1.5")
    print("/fdps chat on|off  - personal fight summary; default OFF")
    print("/fdps announce off|party|raid|instance  - automatic group post; default OFF")
    print("/fdps report  - manually post the last fight to your current group")
    print("/fdps debug on|off|status  - local troubleshooting only")
end

local function DebugStatus()
    local db = DB()
    local api = C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and "available" or "missing"
    local session = GetSession(db.view)
    local sources = PlayerSources(session)
    local playerRank = FindPlayerRank(sources)
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false

    print("|cffd9b93eForever DPS debug:|r API " .. api .. ", view=" .. tostring(db.view) .. ", combat=" .. tostring(inCombat))
    print("|cffd9b93eForever DPS debug:|r sources=" .. tostring(#sources) .. ", playerRank=" .. tostring(playerRank or "not found"))

    local player = playerRank and sources[playerRank] or nil
    if player then
        print("|cffd9b93eForever DPS debug:|r localPlayer=true, class=" .. tostring(player.classFilename or "unknown") .. ", dpsProtected=" .. tostring(IsSecret(player.amountPerSecond)))
    end
end

local function ManualReport()
    if not lastFightSummary then
        print("|cffd9b93eForever DPS:|r No finished fight to report yet.")
        return
    end

    local channel
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    end

    if channel and SendChatMessage then
        SendChatMessage(lastFightSummary, channel)
    else
        print(lastFightSummary)
    end
end

SLASH_FOREVERDPS1 = "/fdps"
SlashCmdList.FOREVERDPS = function(msg)
    local command, arg = msg:match("^(%S*)%s*(.-)$")
    command = command and command:lower() or ""
    arg = arg and arg:lower() or ""

    local db = DB()

    if command == "" or command == "toggle" then
        db.shown = not UI:IsShown()
        UI:SetShown(db.shown)
    elseif command == "show" then
        db.shown = true
        UI:Show()
    elseif command == "hide" then
        db.shown = false
        UI:Hide()
    elseif command == "lock" then
        SetLocked(true)
        print("|cffd9b93eForever DPS:|r window locked.")
    elseif command == "unlock" then
        SetLocked(false)
        print("|cffd9b93eForever DPS:|r window unlocked.")
    elseif command == "current" then
        db.view = "current"
        UI.modeButton:SetText("Current")
        FDPS:Refresh()
    elseif command == "overall" then
        db.view = "overall"
        UI.modeButton:SetText("Overall")
        FDPS:Refresh()
    elseif command == "scale" then
        local scale = tonumber(arg)
        if scale and scale >= 0.7 and scale <= 1.5 then
            db.scale = scale
            UI:SetScale(scale)
            print(string.format("|cffd9b93eForever DPS:|r scale set to %.2f.", scale))
        else
            print("|cffd9b93eForever DPS:|r scale must be between 0.7 and 1.5.")
        end
    elseif command == "chat" then
        if arg == "on" then
            db.chatSummary = true
            print("|cffd9b93eForever DPS:|r personal chat summaries ON.")
        elseif arg == "off" then
            db.chatSummary = false
            print("|cffd9b93eForever DPS:|r personal chat summaries OFF.")
        else
            print("|cffd9b93eForever DPS:|r /fdps chat on|off")
        end
    elseif command == "announce" then
        local map = {
            off = "OFF",
            party = "PARTY",
            raid = "RAID",
            instance = "INSTANCE_CHAT",
        }
        if map[arg] then
            db.announce = map[arg]
            print("|cffd9b93eForever DPS:|r automatic group posting: " .. arg:upper() .. ".")
        else
            print("|cffd9b93eForever DPS:|r /fdps announce off|party|raid|instance")
        end
    elseif command == "report" then
        ManualReport()
    elseif command == "debug" then
        if arg == "on" then
            db.debug = true
            print("|cffd9b93eForever DPS:|r debug mode ON. Debug output is local only.")
            DebugStatus()
        elseif arg == "off" then
            db.debug = false
            print("|cffd9b93eForever DPS:|r debug mode OFF.")
        elseif arg == "status" or arg == "" then
            DebugStatus()
        else
            print("|cffd9b93eForever DPS:|r /fdps debug on|off|status")
        end
    elseif command == "reset" then
        UI:ClearAllPoints()
        UI:SetPoint("CENTER", UIParent, "CENTER", 330, 20)
        db.point = "CENTER"
        db.relativePoint = "CENTER"
        db.x = 330
        db.y = 20
        db.scale = 1.0
        UI:SetScale(1.0)
        print("|cffd9b93eForever DPS:|r window position and scale reset.")
    else
        PrintHelp()
    end
end

FDPS:SetScript("OnEvent", function(self, event, ...)
    if event ~= "ADDON_LOADED" and ForeverDPSDB and ForeverDPSDB.debug then
        if event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" or event == "DAMAGE_METER_RESET" then
            -- Intentionally quiet: use /fdps debug status for a snapshot rather than spamming on every meter update.
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            print("|cffd9b93eForever DPS debug:|r " .. event)
        end
    end

    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON_NAME then return end
        DB()
        CreateUI()
        self:Refresh()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_IN_COMBAT_CHANGED" then
        self:Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        HandleFightEnded()
    elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        self:Refresh()
    elseif event == "DAMAGE_METER_RESET" then
        lastFightSummary = nil
        lastFightData = nil
        self:Refresh()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        self:Refresh()
    end
end)

local events = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_IN_COMBAT_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED",
    "DAMAGE_METER_RESET",
}

for _, event in ipairs(events) do
    pcall(FDPS.RegisterEvent, FDPS, event)
end
