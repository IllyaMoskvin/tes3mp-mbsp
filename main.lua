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

local msg = function(pid, text)
    if text == nil then
        text = ""
    end
    tes3mp.SendMessage(pid, color.GreenYellow .. "[mbsp] " .. color.Default .. text .. "\n" .. color.Default)
end

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
