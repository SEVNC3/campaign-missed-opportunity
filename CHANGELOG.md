# Changelog - Campaign: Missed Opportunity

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-01-14

### Fixed
- Fixed "Not Found" tooltips in combat log and reactions panel
  - Corrected double single quote syntax in Interrupt.txt (`''STATUS''` → `'STATUS'`)
  - Removed conflicting vanilla `AttackOfOpportunity` passive override from Passive.txt
  - Moved Localization folder to correct root-level location (was incorrectly nested inside `Mods/`)
- Interrupt now properly displays "Retaliation" with description "Attack an enemy when they Critically Miss."

### Changed
- Simplified Passive.txt to only contain hidden `Passive_MissedOpportunity`
- Cleaned up localization file with only required entries

### Technical
- **Critical Discovery**: Localization folder must be at mod root level (`Localization/`), NOT inside `Mods/ModName/`
- Stat file string syntax: Use single quotes `'STATUS'`, NOT double single quotes `''STATUS''`
- Build tool: BG3 Modders Multitool CLI (`-s source -d output.pak -c 2`)

## [2.1.0] - 2026-01-13

### Fixed
- Fixed MCM UUID in meta.lsx (was using Auto Send Food to Camp UUID instead of MCM)
  - Updated meta.lsx line 13 to correct MCM UUID: `755a8a72-407f-4f0d-9a33-274ac0f0b53d`
- Fixed infinite retaliation loop when force critical miss toggle enabled
  - Added retaliation counter system (max 1 retaliation per character per round)
  - Counter resets at start of each combat round
  - Prevents A→B→A→B infinite attack chains
- Fixed Booming Blade casting on unarmed attacks
  - Added weapon check before blade cantrip attempts
  - Now requires melee weapon equipped in mainhand or offhand
  - Only casts blade cantrips when both: can cast cantrip AND has melee weapon

### Changed
- Force critical miss debug toggle now properly rate-limited
  - Retaliations respect MAX_RETALIATIONS_PER_ROUND limit
  - More usable for testing without breaking combat flow

### Technical
- Missed Opportunity UUID: `a7f3e2d1-9c4b-4e8a-b5f6-3d2c1a8e7b9f`
- Requires Grimoire v1.2.0+ for Mods.Grimoire.Combat:HasMeleeWeapon() checks
- Build tool: BG3 Modders Multitool

## [2.0.0] - Previous version
- Retaliation on critical misses
- MCM configuration for trigger chance
- Force critical miss debug toggle

---
*Maintained by SEVNCE*
*Requires Campaign: Grimoire (Core Library)*
