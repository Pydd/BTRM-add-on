local addonName, addon = ...

local ldbi = LibStub("LibDBIcon-1.0")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
ldbi:Show('test')

UIParentLoadAddOn("Blizzard_DebugTools")

local minimapButton = ldb:NewDataObject('BTRM', {
    type = "data source",
    text = "0",
    icon = "Interface\\AddOns\\BTRM\\Media\\icon",
})

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    if not BTRMLDBIconDB then BTRMLDBIconDB = {} end
    icon:Register('BTRM', minimapButton, BTRMLDBIconDB)
end)

f:RegisterEvent("PLAYER_LOGIN")

local function hexToRGB(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    return r, g, b
end

local function getNumberOfKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function parseInput(data)
    local result = {}
    local itemNeedLines = { strsplit("\n", data) }
    for _, itemNeedLine in ipairs(itemNeedLines) do
        local id, classColor, playerName, needColor, need, dpsGain = strsplit(";", itemNeedLine)
        local itemID = tonumber(id)
        if not result[itemID] then
            result[itemID] = {}
        end
        table.insert(result[itemID], {
            classColor = classColor,
            playerName = playerName,
            needColor = needColor,
            need = need,
            dpsGain = dpsGain
        })
    end

    return result
end

local function addText(_, link)
    local itemID = link['id']

    if BTRMDB and BTRMDB[itemID] then
        local upgrades = BTRMDB[itemID]
        for _, item in ipairs(upgrades) do
            local rL, gL, bL = hexToRGB(item.classColor)
            local rR, gR, bR = hexToRGB(item.needColor)
            local need = item.need
            if (item.dpsGain ~= '0') then need = need .. ' (' .. item.dpsGain .. ')' end
            GameTooltip:AddDoubleLine(item.playerName, need, rL, gL, bL, rR, gR, bR)
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addText)

local function createInputFrame()
    local f = CreateFrame("Frame", "BTRMFrame", UIParent, "DialogBoxFrame")
    f:SetSize(450, 800)
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    BTRMFrameButton:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
        edgeSize = 16,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject("GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 5, 0)

    -- scroll frame
    local sf = CreateFrame("ScrollFrame", "BTRMScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("LEFT", 16, 0)
    sf:SetPoint("RIGHT", -32, 0)
    sf:SetPoint("TOP", 0, -32)

    -- edit box
    local eb = CreateFrame("EditBox", "BTRMEditBox", sf)
    eb:SetSize(sf:GetSize())
    eb:SetMultiLine(true)
    eb:SetAutoFocus(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:HighlightText()
    sf:SetScrollChild(eb)


    eb:SetScript("OnTextChanged", function()
        local status, itemNeedsData = pcall(parseInput, eb:GetText())
        if status then
            if not BTRMDB then BTRMDB = {} end
            BTRMDB = itemNeedsData
            f:Hide()
            print('[BTRM] : '..getNumberOfKeys(itemNeedsData)..' items imported!')
        end
    end)
    return f
end

local input = createInputFrame()

function minimapButton.OnClick(self, button)
    if button == "LeftButton" then
        if (input:IsShown()) then
            input:Hide()
        else
            BTRMEditBox:SetText("")
            input:Show()
        end
    end

    if button == "RightButton" then
        BTRMDB = {}
    end

    if button == "MiddleButton" then
        SendChatMessage("Reloading!", "RAID")
        ReloadUI()
    end
end
