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

-- https://stackoverflow.com/a/23535333
local getScriptPath = function()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*[/\\])")
end

-- https://stackoverflow.com/a/31857671
local function readfile(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
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

-- Load pre-generated list of spells from plugins
local pluginSpellFile = tes3mp.GetDataPath() .. "/" .. DataManager.getDataPath(dataName)
local pluginSpellFileFallback = getScriptPath() .. 'spells/vanilla.json'

if not tes3mp.DoesFilePathExist(pluginSpellFile) then
    warn('Missing ' .. pluginSpellFile)
    warn('Attempting fall-back to vanilla spell list...')

    if not tes3mp.DoesFilePathExist(pluginSpellFileFallback) then
        fatal('Missing ' .. pluginSpellFileFallback)
        fatal('Please see the mbsp-tes3mp readme for more info')
        tes3mp.StopServer()
    end

    local dkjson = require('dkjson')
    DataManager.saveData(dataName, dkjson.decode(readfile(pluginSpellFileFallback)))
end

local pluginSpells = DataManager.loadData('mbsp', {})

if next(pluginSpells) == nil then
    fatal('Failed to read spell data file. Please file an issue:')
    fatal('https://github.com/IllyaMoskvin/mbsp-tes3mp/issues')
    tes3mp.StopServer()
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

local getSpellCost = function(spellId)
    local spellCost

    -- Check the lookup table
    spellCost = pluginSpells[spellId]
    if spellCost ~= nil then
        return spellCost
    end

    return nil
end

customEventHooks.registerValidator("OnPlayerSkill", function(eventStatus, pid)
    local skillId, skillName, skillAmount = getSkillThatsChanged(pid)
    if skillId == nil then return end
    if skillName == nil then return end
    if skillAmount == nil then return end

    local selectedSpellId = Players[pid].data.miscellaneous.selectedSpell
    local selectedSpellCost = getSpellCost(selectedSpellId)

    info('PID #' .. pid .. ' cast "' .. selectedSpellId .. '" with base cost ' .. selectedSpellCost )
    info('PID #' .. pid .. ' raised "' .. skillName .. '" by ' .. skillAmount )
end)
