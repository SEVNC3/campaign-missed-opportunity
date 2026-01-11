---@diagnostic disable: undefined-global
-- Missed Opportunity v1.0.0
-- Counterattack on critical misses
-- Uses Grimoire library for utilities

local PASSIVE = "Passive_MissedOpportunity"
local STATUS = "MISSED_OPPORTUNITY"

-- Main critical miss handler
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(attacker, status, defender, _)
    if status ~= STATUS then return end
    
    -- Verify attacker is alive and has the status
    if Osi.IsDead(attacker) == 1 then return end
    if Osi.HasActiveStatus(attacker, STATUS) ~= 1 then return end
    
    -- Check if defender can retaliate (using Grimoire)
    if not Grimoire.Conditions:CanRetaliate(defender) then
        Osi.RemoveStatus(attacker, status, defender)
        return
    end
    
    local distance = Grimoire.Combat:GetDistance(defender, attacker)
    local hasAttacked = false
    
    -- Melee range retaliation (within 2 meters)
    if distance <= Grimoire.Combat.MELEE_RANGE then
        
        -- Try blade cantrips first (if can cast)
        if Grimoire.Conditions:CanCastCantrip(defender) then
            local hasCantrip, spell = Grimoire.Spells:HasBladeCantrip(defender)
            if hasCantrip then
                Osi.UseSpell(defender, spell, attacker)
                hasAttacked = true
            end
        end
        
        -- Try melee weapons
        if not hasAttacked and Grimoire.Combat:HasMeleeWeapon(defender, "Mainhand") then
            Grimoire.Combat:UseMainHandAttack(defender, attacker)
            hasAttacked = true
        end
        
        if not hasAttacked and Grimoire.Combat:HasMeleeWeapon(defender, "Offhand") then
            Grimoire.Combat:UseOffHandAttack(defender, attacker)
            hasAttacked = true
        end
        
        -- Try natural melee attacks
        if not hasAttacked then
            local hasMelee, spell = Grimoire.Spells:HasMeleeAttack(defender)
            if hasMelee then
                Osi.UseSpell(defender, spell, attacker)
                hasAttacked = true
            end
        end
        
        -- Fallback: unarmed attack
        if not hasAttacked then
            Grimoire.Combat:UseUnarmedAttack(defender, attacker)
        end
    
    -- Ranged retaliation (2-18 meters)
    elseif distance <= Grimoire.Combat.RANGED_MAX then
        
        -- Try ranged weapons first
        if Grimoire.Combat:HasRangedWeapon(defender, "Mainhand") then
            Grimoire.Combat:UseRangedMainHandAttack(defender, attacker)
            hasAttacked = true
        elseif Grimoire.Combat:HasRangedWeapon(defender, "Offhand") then
            Grimoire.Combat:UseRangedOffHandAttack(defender, attacker)
            hasAttacked = true
        end
        
        -- Try cantrips if no ranged weapon and can cast
        if not hasAttacked and Grimoire.Conditions:CanCastCantrip(defender) then
            for _, spell in ipairs(Grimoire.Spells.Cantrips) do
                if Osi.HasSpell(defender, spell) == 1 then
                    local canCast = true
                    
                    -- Check special range cantrips
                    local specialRange = Grimoire.Spells:GetCantripRange(spell)
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

_P("[Missed Opportunity] Loaded - using Grimoire library")
