# TES3MP-MBSP

A server-side Lua implementation of [Magicka Based Skill Progression](https://www.nexusmods.com/morrowind/mods/44973) (MBSP) slash [Magicka Mastery](https://www.nexusmods.com/morrowind/mods/45058) (MM), for [TES3MP](https://tes3mp.com/).

> This mod makes magical skill progression based on the amount of magicka used, instead of number of spells cast.
>
> -- <cite>HotFusion4</cite>

> It also refunds a portion of the magicka cost of a spell based on your skill level, effectively reducing the cost of spells as your skill increases. You still need enough magicka to cast the spell without the reduced cost, though.
>
> -- <cite>Greywander</cite>

As with all TES3MP server-side mods, this mod does not require players to install anything in order to join your server.

TES3MP-MBSP was tested with [TES3MP v0.7.0-alpha](https://github.com/TES3MP/openmw-tes3mp/releases/tag/0.7.0-alpha), commit hash: 292536439e.

Consider using TES3MP-MBSP alongside [NCGD-TES3MP](https://github.com/hristoast/ncgd-tes3mp). The two are fully compatible.


## Features

 * More expensive spells give more experience.
 * Spells cost less Magicka to cast the more skilled you are.
 * Supports custom spells made via [Spellmakers](https://en.uesp.net/wiki/Morrowind:Spellmakers).
 * Supports spells added by mods. (Requires some extra steps, see [Mod Support](#mod-support).)


## Installation

 1. Clone or download this repo into your `CoreScripts/scripts/custom/` directory.

 2. Add the following to `CoreScripts/scripts/customScripts.lua`:

    ```
    require("custom/tes3mp-mbsp/main")
    ```

 3. Create the `CoreScripts/data/custom/__data_mbsp.json` spell cost look-up file. Do one of the following:

    a. If you are running vanilla (Morrowind, Tribunal, Bloodmoon), you shouldn't need to do anything.

    b. If you are running vanilla + Tamriel Rebuilt (v18.09), copy `spells/tr-v18.09.json` into `__data_mbsp.json`.

    c. If you are running other mods that add spells, see [Mod Support](#mod-support).

 4. (Optional) Run the server once to generate `CoreScripts/data/custom/__config_mbsp.json`. See [Configuration](#configuration).


## Configuration

After installing TES3MP-MBSP, run your server once to generate `CoreScripts/data/custom/__config_mbsp.json`. Here, you can edit various settings to toggle aspects of the mod and tweak game balance.

In general, this script balances things to be easier than MBSP, but harder than MM. If you end up tweaking these settings for your own server, please consider joining the [balance discussion](https://github.com/IllyaMoskvin/tes3mp-mbsp/issues/1) to share your thoughts about reasonable defaults.

```jsonc
{
  // Set to `false` to disable spell cost reduction
  "enableMagickaRefund":true,

  // Set to `false` to disable spell cost-based skill progress reward
  "enableProgressReward":true,

  // Set to `false` to use the base spell cost for calculating skill
  // progress, instead of the adjusted spell cost.
  //
  // FYI: Magicka Mastery uses base cost, but MBSP uses adjusted cost.
  "useCostAfterRefundForProgress":true,

  // Skill progression is the magicka cost divided by 5, so casting
  // a 5-magicka spell (e.g. Fireball) gives the vanilla amount of
  // experience. Casting a 10-magicka spell (e.g. Paralysis) gives
  // twice the normal experience, and so on. Adjust this value to
  // speed up or slow down the rate of spellcaster skill leveling.
  //
  // Remember to take `useCostAfterRefundForProgress` into account.
  // You are always guaranteed at least one progress point.
  //
  // FYI: Magicka Mastery sets this to 5, and MBSP sets this to 15.
  "spellCostDivisor":5,

  // Attributes contribute to effective skill level when calculating
  // magicka refund. For every 5 points of Willpower and every 10
  // points of Luck, players gain one effective point onto every
  // skill for the purposes of calculating magicka refund.
  //
  // To disable either of these, set them to `null` (no quotes)
  //
  // FYI: MBSP sets Willpower to 8, and Luck to 16.
  "willpowerPointsPerSkillPoint":5,
  "luckPointsPerSkillPoint":10,

  // Magicka refund works on a sliding scale based on skill level.
  // Below skill level 25, you will not recieve a refund. Above 25,
  // the refund will be interpolated based on where the skill falls
  // between these thresholds. Above 300, magicka refund will be
  // capped at 87.5%
  //
  // Remember that attributes contribute to effective skill level.
  "refundScale":[{
      "skill":25,
      "refund":0
    },{
      "skill":50,
      "refund":0.125
    },{
      "skill":75,
      "refund":0.25
    },{
      "skill":100,
      "refund":0.5
    },{
      "skill":200,
      "refund":0.75
    },{
      "skill":300,
      "refund":0.875
    }]
}
```


## Mod Support

If your server is running mods that add spells, you may want to generate a custom spell cost look-up list. If you choose to skip this step, casting those spells will not result in additional experience or a magicka refund. But otherwise, assuming that your `__data_mbsp.json` contains the [vanilla spell list](spells/vanilla.json), everything will function as normal.

If you are using mods that don't add spells, you don't need to do these steps.

The requirements for generating a new spell list are as follows:

 1. Lua must be installed and accessible via the CLI.
 2. The ESP/ESM files required by your server must be reachable from wherever you choose to run the generate script.

Essentially, we need to run [generate.lua](generate.lua) to scan your ESP/ESM files and extract spell IDs and costs.

This might lead to a tricky situation: you need Lua installed to run your server, but the ESP/ESM files required by the server don't actually need to be on that system. So if you are running a dedicated server on some remote host, you will either need to copy the mod files there, or install Lua locally.

Once you've got that figured out, follow these steps:

 1. Copy `generate.example.json` to `generate.json`:

    ```bash
    cd tes3mp-mbsp
    cp generate.example.json generate.json
    ```

 2. Update the new `generate.json` with absolute paths to your mods:

    ```json
    {
        "files": [
            "/path/to/Data Files/Morrowind.esm",
            "/path/to/Data Files/Tribunal.esm",
            "/path/to/Data Files/Bloodmoon.esm",
            "/path/to/Data Files/TR_Mainland.esm"
        ]
    }
    ```

 3. Run `generate.lua` to create `spells/custom.json`:

    ```bash
    lua generate.lua
    ```

 4. Copy `spells/custom.json` into the `CoreScripts/data/custom/__data_mbsp.json` file:

    ```bash
    cp spells/custom.json ../../../data/custom/__data_mbsp.json
    ```

 5. Run your server, cast a modded spell, and check the log. You should see something like this:

     ```
     [2019-09-30 04:43:36] [INFO]: [Script]: [ mbsp ]: PID #0 cast "foobar" with base cost 42
     ```

If you see that, then the script successfully detected your modded spell. Everything will work as expected. If you want to see more info, set `logLevel = 0` in your `tes3mp-server-default.cfg` and restart the server.


## Known Issues

Please feel free to [open an issue](https://github.com/IllyaMoskvin/tes3mp-mbsp/issues) if you encounter a bug or have ideas about how to improve this mod.

 * Developed with TES3MP [v0.7.0-alpha](https://github.com/TES3MP/openmw-tes3mp/releases/tag/0.7.0-alpha), commit hash: 292536439e. Only the most recent version of TES3MP will be supported. If a new version comes out and this mod is incompatible with it, please open an issue.

 * Scripted spell mods will not be supported. There's too much variation in how scripted spells might be implemented.

 * Unlike [Magicka Mastery](https://www.nexusmods.com/morrowind/mods/45058), this mod cannot award experience for failed spells. If you can figure out a way to do this cleanly, or at least in a way that doesn't impact performance too much, please [submit a pull request](https://github.com/IllyaMoskvin/tes3mp-mbsp/pulls).

 * I haven't tested if OpenCS's `*.omwaddon` files get their spell costs extracted correctly by `generate.lua`.

Additionally, skill increases are tricky. For context, OpenMW default behavior is as follows:

 * Whenever a skill increase is triggered by using that skill (rather than training or skill books), its progress gets reset back to zero. In other words, there's no "rollover" for any extra progress beyond that which was needed to reach the progress requirement for that skill increase. It is lost.

 * The only way to trigger the game to check for whether there is sufficient progress for a skill increase is to actually use the skill. Any artificial modification of the skill progress will not trigger this check.

Practically, here's what that means for this mod:

 * When this script awards extra skill progress for an expensive spell, it's possible that the player will temporarily end up with more than 100% progress needed to trigger a skill increase. The skill increase will happen the next time the player casts a spell governed by that skill.

 * When that skill does get increased, any "extra" progress on record will be lost. As mentioned, this is expected.

 * This script contains a work-around to ensure that the spell that triggered the skill to be increased will still get its full allotment of experience and its magicka refund.

Essentially, you'll lag behind on magicka-based skill increases by one spell casting, but it shouldn't affect anything.


## Credits

This mod was "written from scratch" so to speak, but I had a lot of help, and it comes from a long line of mods like it.

Many thanks to [JakobCh](https://github.com/JakobCh) for the advice, and for the following code:

 * [espParser](https://github.com/JakobCh/tes3mp_scripts/blob/b8b79d6/espParser/scripts/espParser.lua), which he graciously allowed to be edited and bundled with this mod
 * [customSpells](https://github.com/JakobCh/tes3mp_scripts/blob/b8b79d6/customSpells/scripts/customSpells.lua) example, which was the seed for this mod

The following libraries are also bundled with this code:

 * [David Kolf's JSON module for Lua 5.1/5.2k (v2.5)](https://github.com/LuaDist/dkjson)
 * [lua-struct by Iryont](https://github.com/iryont/lua-struct)

Additional thanks to urm, johnnyhostile, and others at the [#scripting_help](https://discord.gg/SZjnYCh) channel of the TES3MP Discord.

This readme was modeled after [NCGD-TES3MP](https://github.com/hristoast/ncgd-tes3mp).

TES3MP-MBSP is an adaptation of the following mods:

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
