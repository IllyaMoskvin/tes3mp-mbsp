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

-- Track recently used spells for performance
local recentSpells = {}

-- Load custom spells from TES3MP's recordstore
local customSpells = {}
local customSpellData = jsonInterface.load('recordstore/spell.json')

if customSpellData ~= nil then
    for spellId, spellData in pairs(customSpellData['generatedRecords']) do
        customSpells[spellId] = spellData['cost']
    end
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
    if Players[pid].data.skills == nil then return nil end

    local changedSkillId
    local changedSkillName
    local changedSkillProgress
    local changedSkillProgressDelta

    for skillName, skillId in pairs(trackedSkills) do
        local skillData = Players[pid].data.skills[skillName]
        if skillData == nil then return nil end
        local oldProgress = skillData.progress
        local newProgress = tes3mp.GetSkillProgress(pid, skillId)

        if oldProgress < newProgress then
            changedSkillId = skillId
            changedSkillName = skillName
            changedSkillProgress = newProgress
            changedSkillProgressDelta = newProgress - oldProgress
        end
    end

    return changedSkillId, changedSkillName, changedSkillProgress, changedSkillProgressDelta
end

local addRecentSpell = function(spellId, spellCost)
    if recentSpells[spellId] == nil then
        recentSpells[spellId] = spellCost
    end
end

local getSpellCost = function(spellId)
    local spellCost

    -- Check recently used spells
    spellCost = recentSpells[spellId]
    if spellCost ~= nil then
        return spellCost
    end

    -- Check custom spells
    spellCost = customSpells[spellId]
    if spellCost ~= nil then
        addRecentSpell(spellId, spellCost)
        return spellCost
    end

    -- Check the lookup table
    spellCost = pluginSpells[spellId]
    if spellCost ~= nil then
        addRecentSpell(spellId, spellCost)
        return spellCost
    end

    return nil
end

customEventHooks.registerValidator("OnPlayerSkill", function(eventStatus, pid)
    local skillId, skillName, skillProgress, skillProgressDelta = getSkillThatsChanged(pid)
    if skillId == nil then return end
    if skillName == nil then return end
    if skillProgress == nil then return end
    if skillProgressDelta == nil then return end

    local selectedSpellId = Players[pid].data.miscellaneous.selectedSpell
    local selectedSpellCost = getSpellCost(selectedSpellId)

    if selectedSpellCost == nil then return end

    info('PID #' .. pid .. ' cast "' .. selectedSpellId .. '" with base cost ' .. selectedSpellCost )
    info('PID #' .. pid .. ' raised "' .. skillName .. '" by ' .. skillProgressDelta )

    -- Calculate how much additional progress to give
    -- TODO: Make the `5` configurable!
    local extraProgress = math.ceil(selectedSpellCost / 5 * skillProgressDelta) - skillProgressDelta
    local newProgess = skillProgress + extraProgress

    info('PID #' .. pid .. ' is owed ' .. extraProgress .. ' more progress')

    tes3mp.SetSkillProgress(pid, skillId, newProgess) -- save to memory
    Players[pid].data.skills[skillName].progress = newProgess -- save to disk
    tes3mp.SendSkills(pid) -- send to all clients

    info('PID #' .. pid .. ' progress bumped from ' .. skillProgress .. ' to ' .. tes3mp.GetSkillProgress(pid, skillId))
end)
