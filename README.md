# ShowMyMythicKeystone

**The Mythic+ tab shows everything except which key you have. Now it does.**

Your rating, your affixes, your best runs. All right there, and not one word
about the keystone in your bags. ShowMyMythicKeystone puts it under your rating:

```
[Magisters' Terrace +14]
```

Hover it for the keystone's own tooltip. Shift-click it to link the key into
chat, exactly like clicking it in your bags.

## Your alts' keys too

Down the right-hand side of the tab, opposite the weekly best block:

```
Boonkerz
Magisters' Terrace +14

Hydrospanners
Ara-Kara, City of Echoes +8
```

Text only — no window, no border, nothing to move out of the way. Hover an
entry for that keystone's own tooltip; shift-click to link it into chat, both
exactly as if you were on that character.

**It only covers this week.** The list empties at the weekly reset and fills
back in as you play each character. A character you have not logged into since
reset simply is not there. That is the honest answer: the game gives no way to
read a key off a character while it is offline, so an entry left over from last
week would be a guess dressed up as a fact.

Realms are hidden unless two of your characters share a name. There is a setting
if you would rather always see them.

## What it shows

| Your situation | What appears |
|----------------|--------------|
| You have a key | `[Dungeon +Level]` |
| No key, but you have a Mythic+ vault reward waiting | Claim your vault to get a key |
| No key, vault already claimed | Talk to Lindormi for a key |
| No key and no Mythic+ score this season | Nothing at all |

That last row is deliberate. A character who has never run a Mythic+ dungeon
does not need to be told where keystones come from, so the addon stays out of
the way until it has something worth saying.

## Options

Interface options, under *Show My Mythic Keystone*:

| Setting | Default | |
|---------|---------|---|
| Enable alt's keystones | on | The list on the right. Off leaves just your own line. |
| Force server name | off | Always show realms, not only when names collide. |
| Clear saved variables | — | Forget every stored character. Rebuilds as you play them. |

## Commands

- `/smk` toggles the line. `/smk show` and `/smk hide` to be explicit.
- `/smk alts` toggles the alt list.
- `/smk clear` empties the stored characters.

Settings are saved.

## Honest limitations

The two hint lines are English only. On a non-English client the keystone line
itself works fine, but the hints stay in English, and the NPC is described
generically instead of being given a name your client does not use.

Shift-click needs the key in your bags. A keystone in your bank still shows up
in the line, but there is no item link to share, so nothing happens.

The keystone NPC gets rechecked each season. If Blizzard moves or renames them,
[open an issue](../../issues).

## Installation

- **CurseForge:** search for *ShowMyMythicKeystone* in the CurseForge app.
- **Manual:** download the latest zip from [Releases](../../releases/latest)
  and extract the `ShowMyMythicKeystone` folder into
  `World of Warcraft\_retail_\Interface\AddOns\`, then restart the game.

Requires World of Warcraft Retail (Midnight, 12.x).

## License

MIT license, see [LICENSE](LICENSE).
