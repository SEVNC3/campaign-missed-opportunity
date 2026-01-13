---@diagnostic disable: undefined-global
-- Missed Opportunity v2.1.0
-- Counterattack on critical misses
-- Uses Mods.Grimoire library for utilities

local PASSIVE = "Passive_MissedOpportunity"
local STATUS = "MISSED_OPPORTUNITY"

-- Retaliation limiting for force critical miss mode
local retaliationCounts = {}  -- Track retaliations per character per round
local MAX_RETALIATIONS_PER_ROUND = 1  -- Limit to 1 retaliation per character per round

-- Reset retaliation counter at start of combat round
Ext.Osiris.RegisterListener("CombatRoundStarted", 2, "after", function(combat, round)
    retaliationCounts = {}  -- Clear all counters for new round
end)

-- Main critical miss handler
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(attacker, status, defender, _)
    if status ~= STATUS then return end

    -- Verify attacker is alive and has the status
    if Osi.IsDead(attacker) == 1 then return end
    if Osi.HasActiveStatus(attacker, STATUS) ~= 1 then return end

    -- Check MCM critical miss chance configuration
    if not Mods.Grimoire.ShouldTriggerCriticalMiss() then
        Osi.RemoveStatus(attacker, status, defender)
        return
    end

    -- Check if defender can retaliate (using Mods.Grimoire)
    if not Mods.Grimoire.Conditions:CanRetaliate(defender) then
        Osi.RemoveStatus(attacker, status, defender)
        return
    end

    -- Check retaliation limit (for force critical miss mode)
    retaliationCounts[defender] = retaliationCounts[defender] or 0
    if retaliationCounts[defender] >= MAX_RETALIATIONS_PER_ROUND then
        Osi.RemoveStatus(attacker, status, defender)
        return
    end

    -- Increment retaliation counter
    retaliationCounts[defender] = retaliationCounts[defender] + 1

    local distance = Mods.Grimoire.Combat:GetDistance(defender, attacker)
    local hasAttacked = false
    
    -- Melee range retaliation (within 2 meters)
    if distance <= Mods.Grimoire.Combat.MELEE_RANGE then

        -- Try blade cantrips first (if can cast AND has melee weapon equipped)
        if Mods.Grimoire.Conditions:CanCastCantrip(defender) and
           (Mods.Grimoire.Combat:HasMeleeWeapon(defender, "Mainhand") or
            Mods.Grimoire.Combat:HasMeleeWeapon(defender, "Offhand")) then
            local hasCantrip, spell = Mods.Grimoire.Spells:HasBladeCantrip(defender)
            if hasCantrip then
                Osi.UseSpell(defender, spell, attacker)
                hasAttacked = true
            end
        end
        
        -- Try melee weapons
        if not hasAttacked and Mods.Grimoire.Combat:HasMeleeWeapon(defender, "Mainhand") then
            Mods.Grimoire.Combat:UseMainHandAttack(defender, attacker)
            hasAttacked = true
        end
        
        if not hasAttacked and Mods.Grimoire.Combat:HasMeleeWeapon(defender, "Offhand") then
            Mods.Grimoire.Combat:UseOffHandAttack(defender, attacker)
            hasAttacked = true
        end
        
        -- Try natural melee attacks
        if not hasAttacked then
            local hasMelee, spell = Mods.Grimoire.Spells:HasMeleeAttack(defender)
            if hasMelee then
                Osi.UseSpell(defender, spell, attacker)
                hasAttacked = true
            end
        end
        
        -- Fallback: unarmed attack
        if not hasAttacked then
            Mods.Grimoire.Combat:UseUnarmedAttack(defender, attacker)
        end
    
    -- Ranged retaliation (2-18 meters)
    elseif distance <= Mods.Grimoire.Combat.RANGED_MAX then
        
        -- Try ranged weapons first
        if Mods.Grimoire.Combat:HasRangedWeapon(defender, "Mainhand") then
            Mods.Grimoire.Combat:UseRangedMainHandAttack(defender, attacker)
            hasAttacked = true
        elseif Mods.Grimoire.Combat:HasRangedWeapon(defender, "Offhand") then
            Mods.Grimoire.Combat:UseRangedOffHandAttack(defender, attacker)
            hasAttacked = true
        end
        
        -- Try cantrips if no ranged weapon and can cast
        if not hasAttacked and Mods.Grimoire.Conditions:CanCastCantrip(defender) then
            for _, spell in ipairs(Mods.Grimoire.Spells.Cantrips) do
                if Osi.HasSpell(defender, spell) == 1 then
                    local canCast = true
                    
                    -- Check special range cantrips
                    local specialRange = Mods.Grimoire.Spells:GetCantripRange(spell)
                    if specialRange and distance > specialRange then
                        canCast = false
                    end
                    
                    -- Handle Produce Flame conversion
                    if spell == "Shout_ProduceFlame" then
                        Osi.UseSpell(defender, "Projectile_ProduceFlame_Hurl", attacker)
                        hasAttacked = true
                        break
                    elseif canCast then
                        Osi.UseSpell(defender, spell, attacker)
                        hasAttacked = true
                        break
                    end
                end
            end
        end
    end
    
    -- Clean up status
    Osi.RemoveStatus(attacker, status, defender)
end)

-- Apply passive to all combatants when combat starts
Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combat)
    for _, row in pairs(Osi.DB_Is_InCombat:Get(nil, combat)) do
        local combatant = row[1]
        if combatant and Osi.IsDead(combatant) == 0 then
            Osi.AddPassive(combatant, PASSIVE)
        end
    end
end)

-- Apply to entities that join combat later
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(combatant, combat)
    if combatant and Osi.IsDead(combatant) == 0 then
        Osi.AddPassive(combatant, PASSIVE)
    end
end)

-- Remove passive when combat ends
Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function(combat)
    for _, row in pairs(Osi.DB_Is_InCombat:Get(nil, combat)) do
        local combatant = row[1]
        if combatant then
            Osi.RemovePassive(combatant, PASSIVE)
        end
    end
end)

-- Debug/Testing: Force all attacks to be treated as critical misses
-- This listener applies the MISSED_OPPORTUNITY status on every attack when the debug option is enabled
Ext.Osiris.RegisterListener("AttackedBy", 7, "after", function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
    -- Only proceed if force critical miss is enabled
    if not Mods.Grimoire.IsForceCriticalMissEnabled() then
        return
    end

    -- Get the actual attacker
    local actualAttacker = attackerOwner or attacker2
    if not actualAttacker then return end

    -- Verify this is a valid attack in combat
    if Osi.IsDead(actualAttacker) == 1 then return end
    if Osi.IsDead(defender) == 1 then return end

    -- Check if attacker has the passive (is in combat)
    if Osi.HasPassive(actualAttacker, PASSIVE) ~= 1 then return end

    -- Apply the status to trigger retaliation
    -- The status will be handled by the normal StatusApplied listener above
    Osi.ApplyStatus(actualAttacker, STATUS, -1, 1, defender)
end)

_P("[Missed Opportunity] Loaded - using Mods.Grimoire library")
