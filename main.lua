local msg = function(pid, text)
    if text == nil then
        text = ""
    end
    tes3mp.SendMessage(pid, color.GreenYellow .. "[mbsp] " .. color.Default .. text .. "\n" .. color.Default)
end

local getSkillThatsChanged = function(pid)
    local Player = Players[pid]
    local changedSkill
    local skillAmount

    if Player.data.skills == nil then return nil end

    for name, value in pairs(Player.data.skills) do
        local skillId = tes3mp.GetSkillId(name)
        local baseProgress = value.progress
        local changedProgress = tes3mp.GetSkillProgress(pid, skillId)
        -- msg(pid, name .. ":" .. tostring(baseProgress) .. "/" .. changedProgress )
        if baseProgress < changedProgress then
            changedSkill = name
            skillAmount = changedProgress - baseProgress
        end
    end

    return changedSkill, skillAmount
end

customEventHooks.registerValidator("OnPlayerSkill", function(eventStatus, pid)
    local changedSkill, skillAmount = getSkillThatsChanged(pid)
    if changedSkill == nil then return end
    if skillAmount == nil then return end

    local selectedSpell = Players[pid].data.miscellaneous.selectedSpell
    msg(pid, selectedSpell)

    msg(pid, changedSkill)
    msg(pid, skillAmount)
end)
