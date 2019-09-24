-- Helpers for renaming or versioning
local scriptName = 'mbsp-tes3mp' -- scripts/custom/subdir of this script
local dataName = 'mbsp' -- data/custom/__data_[dataName].json

-- Helper functions for logging
local logPrefix = "[ mbsp ]: "

local function dbg(msg)
   tes3mp.LogMessage(enumerations.log.VERBOSE, logPrefix .. msg)
end

local function fatal(msg)
   tes3mp.LogMessage(enumerations.log.FATAL, logPrefix .. msg)
end

local function warn(msg)
   tes3mp.LogMessage(enumerations.log.WARN, logPrefix .. msg)
end

local function info(msg)
   tes3mp.LogMessage(enumerations.log.INFO, logPrefix .. msg)
end

local msg = function(pid, text)
    if text == nil then
        text = ""
    end
    tes3mp.SendMessage(pid, color.GreenYellow .. "[mbsp] " .. color.Default .. text .. "\n" .. color.Default)
end

-- We only care about skills that consume magicka when used
local trackedSkillNames = {
   "Destruction",
   "Alteration",
   "Illusion",
   "Conjuration",
   "Mysticism",
   "Restoration",
}

-- Cache skill IDs for performance
local trackedSkills = {}

for i, skillName in ipairs(trackedSkillNames) do
    trackedSkills[skillName] = tes3mp.GetSkillId(skillName)
end

-- Based off JakobCh's `customSpells` example:
-- https://github.com/JakobCh/tes3mp_scripts/blob/b8b79d6/customSpells/scripts/customSpells.lua#L38
local getSkillThatsChanged = function(pid)
    local Player = Players[pid]

    if Player.data.skills == nil then return nil end

    local changedSkillId
    local changedSkillName
    local changedSkillAmount

    for skillName, skillId in pairs(trackedSkills) do
        local skillData = Player.data.skills[skillName]
        if skillData == nil then return nil end
        local baseProgress = skillData.progress
        local changedProgress = tes3mp.GetSkillProgress(pid, skillId)

        -- msg(pid, name .. ":" .. tostring(baseProgress) .. "/" .. changedProgress )

        if baseProgress < changedProgress then
            changedSkillId = skillId
            changedSkillName = skillName
            changedSkillAmount = changedProgress - baseProgress
        end
    end

    return changedSkillId, changedSkillName, changedSkillAmount
end

customEventHooks.registerValidator("OnPlayerSkill", function(eventStatus, pid)
    local skillId, skillName, skillAmount = getSkillThatsChanged(pid)
    if skillId == nil then return end
    if skillName == nil then return end
    if skillAmount == nil then return end

    local selectedSpell = Players[pid].data.miscellaneous.selectedSpell
    msg(pid, selectedSpell)

    msg(pid, skillName)
    msg(pid, skillAmount)
end)
