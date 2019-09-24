# MBSP-TES3MP

A server-side Lua implementation of [Magicka Based Skill Progression](https://www.nexusmods.com/morrowind/mods/44973) slash [Magicka Mastery](https://www.nexusmods.com/morrowind/mods/45058), for [TES3MP](https://tes3mp.com/).

> This mod makes magical skill progression based on the amount of magicka used, instead of number of spells cast.
>
> -- <cite>HotFusion4</cite>

> It also refunds a portion of the magicka cost of a spell based on your skill level, effectively reducing the cost of spells as your skill increases. You still need enough magicka to cast the spell without the reduced cost, though.
>
> -- <cite>Greywander</cite>

As with all TES3MP server-side mods, this mod does not require players to install anything in order to join your server.

MBSP-TES3MP was tested with [TES3MP v0.7.0-alpha](https://github.com/TES3MP/openmw-tes3mp/releases/tag/0.7.0-alpha), commit hash: 292536439e.

Consider using MBSP-TES3MP alongside [NCGD-TES3MP](https://github.com/hristoast/ncgd-tes3mp). The two are fully compatible.


## Features

 * Requires [DataManager](https://github.com/tes3mp-scripts/DataManager)!
 * More expensive spells give more experience.
 * Spells cost less Magicka to cast the more skilled you are.
 * Supports custom spells made via [Spellmakers](https://en.uesp.net/wiki/Morrowind:Spellmakers).
 * Supports spells added by mods. (Requires some extra steps, see below.)


## Installation

 1. Clone or download [DataManager](https://github.com/tes3mp-scripts/DataManager) into your `CoreScripts/scripts/custom/` directory.

 2. Place this repo into your `CoreScripts/scripts/custom/` directory. Clone or download it.

 3. Add the following to `CoreScripts/scripts/customScripts.lua`:

    ```
    -- DataManager must be require'd before MBSP, like this:
    DataManager = require("custom/DataManager/main")

    require("custom/mbsp-tes3mp/main")
    ```

 4. Ensure that `DataManager` loads before this mod as seen above.

 5. Create the `CoreScripts/data/custom/__data_mbsp.json` spell cost look-up file. Do one of the following:

    a. If you are running vanilla (Morrowind, Tribunal, Bloodmoon), you shouldn't need to do anything.

    b. If you are running vanilla + Tamriel Rebuilt (v18.09), copy `spells/tr-v18.09.json` into `__data_mbsp.json`.

    c. If you are running other mods that add spells, see below.

 6. (Optional) Run the server once to generate `CoreScripts/data/custom/__config_mbsp.json`. See Configuration.


## Known Issues

Please feel free to [open an issue](https://github.com/IllyaMoskvin/mbsp-tes3mp/issues) if you encounter a bug or have ideas about how to fix some of the ones in this list:

 * Developed with TES3MP [v0.7.0-alpha](https://github.com/TES3MP/openmw-tes3mp/releases/tag/0.7.0-alpha), commit hash: 292536439e. Only the most recent version of TES3MP will be supported. If a new version comes out and this mod is incompatible with it, please open an issue.

 * Scripted spell mods will not be supported. There's too much variation in how scripted spells might be implemented.

 * Unlike [Magicka Mastery](https://www.nexusmods.com/morrowind/mods/45058), this mod cannot award experience for failed spells. If you can figure out a way to do this cleanly, or at least in a way that doesn't impact performance too much, please [submit a pull request](https://github.com/IllyaMoskvin/mbsp-tes3mp/pulls).

 * When the script awards extra skill progress, it's possible that the player will end up with more than 100% progress needed to trigger a skill increase. The skill increase will happen the next time the player gains progress in that skill.

 * Extra skill progress does not roll over when the skill is increased. It gets reset back to zero.

 * If casting a spell causes the skill to be increased, that spell will not not be eligible for cost reduction and will not grant additional experience. (Unlike the two above, this bug seems fixable.)


## Credits

This mod was "written from scratch" so to speak, but I had a lot of help, and it comes from a long line of mods like it.

Many thanks to [JakobCh](https://github.com/JakobCh) for the advice, and for the following code:

 * [espParser](https://github.com/JakobCh/tes3mp_scripts/blob/b8b79d6/espParser/scripts/espParser.lua), which he graciously allowed to be edited and bundled with this mod
 * [customSpells](https://github.com/JakobCh/tes3mp_scripts/blob/b8b79d6/customSpells/scripts/customSpells.lua) example, which was the seed for this mod

The following libraries are also bundled with this code:

 * [David Kolf's JSON module for Lua 5.1/5.2k (v2.5)](https://github.com/LuaDist/dkjson)
 * [lua-struct by Iryont](https://github.com/iryont/lua-struct)

Additional thanks to urm and others at the [#scripting_help](https://discord.gg/SZjnYCh) channel of the TES3MP Discord.

This readme was modeled after [NCGD-TES3MP](https://github.com/hristoast/ncgd-tes3mp).

MBSP-TES3MP is an adaptation of the following mods:

 * [Magicka Based Skill Progression](http://mw.modhistory.com/download-35-12364) by HotFusion4, and its [ncgdMW Compatility Version](https://www.nexusmods.com/morrowind/mods/44973) by Greywander
 * [Magicka Mastery](https://www.nexusmods.com/morrowind/mods/45058) by MageKing17, and its [MWSE Lua port](https://github.com/MWSE/MWSE/issues/116#issuecomment-421794877) by Greatness7

File credits from Magicka Mastery:

 * Roughly based on Spell Cast Reduction by Aragon

File credits from MBSP via the ncgdMW Compatibility Version:

 * MBSP edits by Greywander for greater compatibility with ncgdMW
 * MBSP by HotFusion4
 * TESTool by GhostWheel
 * Readme template by Glassboy
 * Original Magicka reduction script by Horatio
 * Spell Detection script is a modified verion of Horatio's
 * Method of refunding magicka was invented by Eldar
 * Fix for multiple calls suggested by Galsiah
 * Aragorn was the first person to notice the mis-assigned spell sounds in the CS
 * All scripters owe thanks to GhanBuriGhan from his canonical Morrowind Scripting For Dummies
