# AutoShowKeystone

**The Mythic+ tab shows everything except which key you have. Now it does.**

Your rating, your affixes, your best runs. All right there, and not one word
about the keystone in your bags. AutoShowKeystone puts it under your rating:

```
[Magisters' Terrace +14]
```

Hover it for the keystone's own tooltip. Shift-click it to link the key into
chat, exactly like clicking it in your bags.

There is no options panel and no minimap button.

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

## Command

- `/ak` toggles the line. `/ak show` and `/ak hide` if you prefer to be
  explicit. The setting is saved.

## Honest limitations

The two hint lines are English only. On a non-English client the keystone line
itself works fine, but the hints stay in English, and the NPC is described
generically instead of being given a name your client does not use.

Shift-click needs the key in your bags. A keystone in your bank still shows up
in the line, but there is no item link to share, so nothing happens.

The keystone NPC gets rechecked each season. If Blizzard moves or renames them,
[open an issue](../../issues).

## Installation

- **CurseForge:** search for *AutoShowKeystone* in the CurseForge app.
- **Manual:** download the latest zip from [Releases](../../releases/latest)
  and extract the `AutoShowKeystone` folder into
  `World of Warcraft\_retail_\Interface\AddOns\`, then restart the game.

Requires World of Warcraft Retail (Midnight, 12.x).

## License

MIT license, see [LICENSE](LICENSE).
