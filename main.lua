--[[-------------------------------------------------------------------

TES3MP-MBSP v1.1.1 by Illya Moskvin

SOURCE:
    https://github.com/IllyaMoskvin/tes3mp-mbsp

DESCRIPTION:
    This mod makes magical skill progression be based on the amount of
    Magicka used, rather than the number of spells cast. Additionally,
    it refunds a portion of the Magicka cost of each spell based on the
    player's skill level.

LICENSE:
    Copyright (c) 2022 Illya Moskvin <https://github.com/IllyaMoskvin>

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
    BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
    ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

HISTORY:
    2019-09-30 - v1.0.0 - Initial release
    2019-12-14 - v1.1.0 - Fix awarding of "base" skill progress
    2019-12-25 - v1.1.1 - No code changes, added spells/tr-v19.12.json

]]---------------------------------------------------------------------
local skillIdCACHE, skillNameCACHE, skillProgressCACHE, skillProgressDeltaCACHE = nil
-- Paths to config and data files
local dataPath = 'custom/__data_mbsp.json'
local configPath = 'custom/__config_mbsp.json'

-- Load config with default fallback
local defaultConfig = {
    enableMagickaRefund = true,
    enableProgressReward = true,
    useCostAfterRefundForProgress = true,
    spellCostDivisor = 5,
    willpowerPointsPerSkillPoint = 5,
    luckPointsPerSkillPoint = 10,
    refundScale = {
        {
            skill = 25,
            refund = 0,
        },
        {
            skill = 50,
            refund = 0.125,
        },
        {
            skill = 75,
            refund = 0.25,
        },
        {
            skill = 100,
            refund = 0.5,
        },
        {
            skill = 200,
            refund = 0.75,
        },
        {
            skill = 300,
            refund = 0.875,
        },
    },
}

local config = jsonInterface.load(configPath)

if config == nil then
    config = defaultConfig

    jsonInterface.save(configPath, defaultConfig, {
        'enableMagickaRefund',
        'enableProgressReward',
        'useCostAfterRefundForProgress',
        'spellCostDivisor',
        'willpowerPointsPerSkillPoint',
        'luckPointsPerSkillPoint',
        'refundScale',
        'skill',
        'refund',
    })
end

-- Ensure `refundScale` is sorted by skill level
table.sort(config['refundScale'], function (v1, v2)
    return v1['skill'] < v2['skill']
end)

-- Helper functions for logging
local logPrefix = '[ mbsp ]: '

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
   local str = debug.getinfo(2, 'S').source:sub(2)
   return str:match('(.*[/\\])')
end

-- https://stackoverflow.com/a/31857671
local function readfile(path)
    local file = io.open(path, 'rb') -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read '*a' -- *a or *all reads the whole file
    file:close()
    return content
end

-- Cache attribute ids for performance
local willpowerAttributeId = tes3mp.GetAttributeId('Willpower')
local luckAttributeId = tes3mp.GetAttributeId('Luck')

-- We only care about skills that consume magicka when used
local trackedSkillNames = {
   'Destruction',
   'Alteration',
   'Illusion',
   'Conjuration',
   'Mysticism',
   'Restoration',
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

local setCustomSpells = function()
    local customSpellData = jsonInterface.load('recordstore/spell.json')

    if customSpellData ~= nil then
        for spellId, spellData in pairs(customSpellData['generatedRecords']) do
            customSpells[spellId] = spellData['cost']
        end
    end
end

setCustomSpells()

-- Update custom spell cost list whenever a player creates a new spell
customEventHooks.registerHandler('OnRecordDynamic', function(eventStatus, pid)
    local recordNumericalType = tes3mp.GetRecordType(pid)
    local storeType = string.lower(tableHelper.getIndexByValue(enumerations.recordType, recordNumericalType))
    if storeType == 'spell' then
        setCustomSpells()
    end
end)

-- Load pre-generated list of spells from plugins
local pluginSpellFile = tes3mp.GetDataPath() .. '/' .. dataPath
local pluginSpellFileFallback = getScriptPath() .. 'spells/vanilla.json'

if not tes3mp.DoesFilePathExist(pluginSpellFile) then
    warn('Missing ' .. pluginSpellFile)
    warn('Attempting fall-back to vanilla spell list...')

    if not tes3mp.DoesFilePathExist(pluginSpellFileFallback) then
        fatal('Missing ' .. pluginSpellFileFallback)
        fatal('Please see the TES3MP-MBSP readme for more info.')
        tes3mp.StopServer()
    end

    -- Copy spells/vanilla.json into data/custom/__data_mbsp.json
    local pluginSpellFileHandle = io.open(pluginSpellFile, 'w+b')

    if pluginSpellFileHandle == nil then
        fatal('Cannot open ' .. pluginSpellFile .. ' for writing.')
        fatal('Try creating it manually? Check TES3MP-MBSP readme.')
        tes3mp.StopServer()
    end

    pluginSpellFileHandle:write(readfile(pluginSpellFileFallback))
    pluginSpellFileHandle:close()
end

local pluginSpells = jsonInterface.load(dataPath)

if next(pluginSpells) == nil then
    fatal('Failed to read spell data file. Please file an issue:')
    fatal('https://github.com/IllyaMoskvin/tes3mp-mbsp/issues')
    tes3mp.StopServer()
end

-- Based off JakobCh's `customSpells` example:
-- https://github.com/JakobCh/tes3mp_scripts/blob/b8b79d6/customSpells/scripts/customSpells.lua#L38
local getSkillThatsChanged = function(pid)
    if Players[pid].data.skills == nil then return nil end

    local skillData = {}

    for skillName, skillId in pairs(trackedSkills) do
        local oldProgress = Players[pid].data.skills[skillName].progress
        local newProgress = tes3mp.GetSkillProgress(pid, skillId)

        if oldProgress+0.1 < newProgress then
            return skillId, skillName, oldProgress, (newProgress - oldProgress)
        end

        skillData[skillName] = {
            oldProgress = oldProgress,
            newProgress = newProgress,
        }
    end

    -- Check if the skill increased
    for skillName, skillId in pairs(trackedSkills) do
        local oldSkill = Players[pid].data.skills[skillName].base
        local newSkill = tes3mp.GetSkillBase(pid, skillId)

        -- Here, we assume that all spellcasting skills progress by one point
        -- See OpenCS -> Skills -> [Skill] -> Use value 1
        -- Progress only gets reset to zero with actual use, not training or skill books
        if oldSkill < newSkill and skillData[skillName].newProgress == 0 then
            return skillId, skillName, 0, 1
        end
    end
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

-- Your effective skill level is affected by your attributes. For every [5] points of Willpower
-- and for every [10] points of Luck, you gain one effective point onto every skill for purposes
-- of calculating your magicka refund. -- HotFusion4, MBSP v2.1 README
local runRefundMagicka = function(pid, skillId, baseSpellCost)
    local effectiveSkillLevel = tes3mp.GetSkillBase(pid, skillId) +
            tes3mp.GetSkillModifier(pid, skillId) -
            tes3mp.GetSkillDamage(pid, skillId)

    -- Willpower's contribution to effective skill level
    if config['willpowerPointsPerSkillPoint'] ~= nil then
        local currentWillpower = tes3mp.GetAttributeBase(pid, willpowerAttributeId) +
            tes3mp.GetAttributeModifier(pid, willpowerAttributeId) -
            tes3mp.GetAttributeDamage(pid, willpowerAttributeId)

        dbg('PID #' .. pid .. ' current Willpower is ' .. currentWillpower)

        effectiveSkillLevel = effectiveSkillLevel + currentWillpower / config['willpowerPointsPerSkillPoint']
    end

    -- Lucks's contribution to effective skill level
    if config['luckPointsPerSkillPoint'] ~= nil then
        local currentLuck = tes3mp.GetAttributeBase(pid, luckAttributeId) +
            tes3mp.GetAttributeModifier(pid, luckAttributeId) -
            tes3mp.GetAttributeDamage(pid, luckAttributeId)

        dbg('PID #' .. pid .. ' current Luck is ' .. currentLuck)

        effectiveSkillLevel = effectiveSkillLevel + currentLuck / config['luckPointsPerSkillPoint']
    end

    effectiveSkillLevel = math.max(0, effectiveSkillLevel)

    dbg('PID #' .. pid .. ' effective skill level is ' .. effectiveSkillLevel)

    -- Figure out where we fall within the refund thresholds
    local prevSkillThreshold
    local prevRefundProportion

    local nextSkillThreshold
    local nextRefundProportion

    for _, skillPair in pairs(config['refundScale']) do
        local currentSkillThreshold = skillPair['skill']
        local currentRefundProportion = skillPair['refund']

        if (currentSkillThreshold < effectiveSkillLevel) then
            prevSkillThreshold = currentSkillThreshold
            prevRefundProportion = currentRefundProportion
        elseif (nextSkillThreshold == nil) then
            nextSkillThreshold = currentSkillThreshold
            nextRefundProportion = currentRefundProportion
            break
        end
    end

    -- Determine what proportion of the spell cost to refund
    local effectiveRefundProportion

    if prevSkillThreshold == nil then
        -- Skill level is below the lowest defined in config
        dbg('PID #' .. pid .. ' skill too low for refund')
        return baseSpellCost
    else
        if nextSkillThreshold == nil then
            -- Skill level is above the highest defined in config
            effectiveRefundProportion = prevSkillThreshold
        else
            -- Skill level is between two thresholds
            local progressTowardsNextThreshold = (effectiveSkillLevel - prevSkillThreshold) / (nextSkillThreshold - prevSkillThreshold)
            effectiveRefundProportion = prevRefundProportion + (nextRefundProportion - prevRefundProportion) * progressTowardsNextThreshold
        end
    end

    dbg('PID #' .. pid .. ' effective refund proportion is ' .. effectiveRefundProportion)

    local refundedSpellCost = baseSpellCost * effectiveRefundProportion

    dbg('PID #' .. pid .. ' should be refunded ' .. refundedSpellCost .. ' magicka')

    -- All spells should cost at least one magicka
    if baseSpellCost - refundedSpellCost < 1 then
        dbg('PID #' .. pid .. ' was refused magicka refund for cantrip')
        return baseSpellCost
    end

    local newMagicka = tes3mp.GetMagickaCurrent(pid) + refundedSpellCost
    local maxMagicka = tes3mp.GetMagickaBase(pid)

    if newMagicka > maxMagicka then
        dbg('PID #' .. pid .. ' had refund capped to max magicka of ' .. maxMagicka)
        newMagicka = maxMagicka
    end

    tes3mp.SetMagickaCurrent(pid, newMagicka) -- save to memory
    Players[pid].data.stats.magickaCurrent = newMagicka -- save to disk
    tes3mp.SendStatsDynamic(pid) -- send to all clients

    return baseSpellCost - refundedSpellCost
end

local runAwardProgress = function(pid, spellCost, skillId, skillName, skillProgress, skillProgressDelta)
    local extraProgress = spellCost / config['spellCostDivisor'] * skillProgressDelta - skillProgressDelta

    dbg('PID #' .. pid .. ' is owed ' .. extraProgress .. ' more progress for spell cost ' .. spellCost)

    if extraProgress > 0 then
        local newProgess = skillProgress + skillProgressDelta + extraProgress

        tes3mp.SetSkillProgress(pid, skillId, newProgess) -- save to memory
        Players[pid].data.skills[skillName].progress = newProgess -- save to disk
        tes3mp.SendSkills(pid) -- send to all clients

        dbg('PID #' .. pid .. ' progress bumped from ' .. skillProgress .. ' to ' .. tes3mp.GetSkillProgress(pid, skillId))
    else
        dbg('PID #' .. pid .. ' progress naturally rose to from ' .. skillProgress .. ' to ' .. tes3mp.GetSkillProgress(pid, skillId))
    end
end

customEventHooks.registerValidator('OnPlayerSkill', function(eventStatus, pid)
    local skillId, skillName, skillProgress, skillProgressDelta = getSkillThatsChanged(pid)
	skillIdCACHE, skillNameCACHE, skillProgressCACHE, skillProgressDeltaCACHE = skillId, skillName, skillProgress, skillProgressDelta
    if skillId == nil then return end
    if skillName == nil then return end
    if skillProgress == nil then return end
    if skillProgressDelta == nil then return end
end)

customEventHooks.registerHandler('OnPlayerSkill', function(eventStatus, pid)
	local skillId, skillName, skillProgress, skillProgressDelta = skillIdCACHE, skillNameCACHE, skillProgressCACHE, skillProgressDeltaCACHE
    if skillId == nil then return end
    if skillName == nil then return end
    if skillProgress == nil then return end
    if skillProgressDelta == nil then return end
    local selectedSpellId = Players[pid].data.miscellaneous.selectedSpell
    local selectedSpellCost = getSpellCost(selectedSpellId)

    if selectedSpellCost == nil then return end

    info('PID #' .. pid .. ' cast "' .. selectedSpellId .. '" with base cost ' .. selectedSpellCost )
    dbg('PID #' .. pid .. ' raised "' .. skillName .. '" by ' .. skillProgressDelta )

    -- Might change from base to adjusted depending on config
    local spellCostForProgress = selectedSpellCost

    -- Calculate how much magicka to refund
    if config['enableMagickaRefund'] then
        local adjustedSpellCost = runRefundMagicka(pid, skillId, selectedSpellCost)

        if config['useCostAfterRefundForProgress'] then
            spellCostForProgress = adjustedSpellCost
        end
    end

    -- Calculate how much additional progress to give
    if config['enableProgressReward'] then
        runAwardProgress(pid, spellCostForProgress, skillId, skillName, skillProgress, skillProgressDelta)
    end
end)
