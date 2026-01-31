local FPS_Mover = LibStub("AceAddon-3.0"):NewAddon("FPS_Mover", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-- Store original frame methods before any hooking to bypass hooks later
local refFrame = CreateFrame("Frame")
local OrigSetPoint = refFrame.SetPoint
local OrigClearAllPoints = refFrame.ClearAllPoints

local anchorFrame
local sessionState = { showAnchor = false }

local defaults = {
    profile = {
        enabled = false,
        point = "CENTER",
        relativePoint = "CENTER",
        anchorX = 0,
        anchorY = 0,
    },
}

local function HasFPSFrame()
    return FramerateFrame ~= nil
end

local function PositionAnchor()
    if not anchorFrame then return end
    local p = FPS_Mover.db.profile
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint(p.point, UIParent, p.relativePoint, p.anchorX, p.anchorY)
end

local options = {
    name = "FPS Mover",
    handler = FPS_Mover,
    type = "group",
    args = {
        enabled = {
            type = "toggle",
            name = "Enable Moving",
            desc = "Move the FPS counter to the saved position. Uncheck to return to default.",
            get = function(info) return FPS_Mover.db.profile.enabled end,
            set = function(info, value)
                FPS_Mover.db.profile.enabled = value
                FPS_Mover:ApplySettings()
            end,
            order = 1,
        },
        showAnchor = {
            type = "toggle",
            name = "Show Anchor",
            desc = "Show the draggable anchor to set position. Drag it, then uncheck to hide.",
            get = function(info) return sessionState.showAnchor end,
            set = function(info, value)
                sessionState.showAnchor = value
                FPS_Mover:UpdateAnchorVisibility()
            end,
            order = 2,
        },
    },
}

function FPS_Mover:CreateAnchorFrame()
    if anchorFrame then return end

    anchorFrame = CreateFrame("Frame", "FPS_MoverAnchor", UIParent, "BackdropTemplate")
    anchorFrame:SetSize(86, 25)
    anchorFrame:SetMovable(true)
    anchorFrame:EnableMouse(true)
    anchorFrame:RegisterForDrag("LeftButton")
    anchorFrame:SetClampedToScreen(true)

    anchorFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    anchorFrame:SetBackdropColor(0.1, 0.1, 0.8, 0.8)
    anchorFrame:SetBackdropBorderColor(0.4, 0.4, 0.9, 1)

    local label = anchorFrame:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(SystemFont_Shadow_Med1)
    label:SetPoint("CENTER")
    label:SetText("FPS")
    label:SetTextColor(1, 0.82, 0)

    anchorFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    anchorFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        FPS_Mover.db.profile.point = point
        FPS_Mover.db.profile.relativePoint = relativePoint
        FPS_Mover.db.profile.anchorX = x
        FPS_Mover.db.profile.anchorY = y
        if FPS_Mover.db.profile.enabled then
            FPS_Mover:ApplyFPSPosition()
        end
    end)

    anchorFrame:SetFrameStrata("HIGH")
    anchorFrame:Hide()
end

function FPS_Mover:UpdateAnchorVisibility()
    if not anchorFrame then
        self:CreateAnchorFrame()
    end

    if sessionState.showAnchor then
        PositionAnchor()
        anchorFrame:Show()
    else
        anchorFrame:Hide()
    end
end

function FPS_Mover:ApplyFPSPosition()
    if not HasFPSFrame() then return end
    if not anchorFrame then
        self:CreateAnchorFrame()
    end

    PositionAnchor()

    OrigClearAllPoints(FramerateFrame)
    OrigSetPoint(FramerateFrame, "LEFT", anchorFrame, "LEFT", 4, 0)
end

function FPS_Mover:ResetFPS()
    if not HasFPSFrame() then return end

    -- Restore to Blizzard default position
    OrigClearAllPoints(FramerateFrame)
    OrigSetPoint(FramerateFrame, "TOP", UIParent, "TOP", -15, -10)
end

function FPS_Mover:ApplySettings()
    if not HasFPSFrame() then return end

    -- Hook once to override Blizzard's micro-menu anchoring; handles both enabled and disabled states
    if not self.hooksApplied then
        hooksecurefunc(FramerateFrame, "UpdatePosition", function(frame)
            if FPS_Mover.db.profile.enabled and anchorFrame then
                OrigClearAllPoints(frame)
                OrigSetPoint(frame, "LEFT", anchorFrame, "LEFT", 4, 0)
            else
                OrigClearAllPoints(frame)
                OrigSetPoint(frame, "TOP", UIParent, "TOP", -15, -10)
            end
        end)
        self.hooksApplied = true
    end

    if FPS_Mover.db.profile.enabled then
        self:ApplyFPSPosition()
    else
        self:ResetFPS()
    end
end

function FPS_Mover:OnInitialize()
    self.db = AceDB:New("FPS_MoverDB", defaults, true)
    AceConfig:RegisterOptionsTable("FPS_Mover", options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("FPS_Mover", "FPS Mover")
    self:CreateAnchorFrame()
end

function FPS_Mover:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
end

function FPS_Mover:OnPlayerEnteringWorld()
    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)
end
