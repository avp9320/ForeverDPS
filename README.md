# Forever DPS v0.1.4

A deliberately simple DPS meter for **World of Warcraft: Forever**.

The goal is not to replace a full combat-analysis suite. Forever DPS answers one question quickly:

> **How am I doing compared with the rest of the group?**

## What it shows

- Live DPS ranking from Forever's server-side `C_DamageMeter` data.
- Class-colored bars with legible light labels.
- Your own row highlighted.
- A `YOU: #x/y` ranking only when there are at least two damage sources; a simpler solo DPS row.
- After group combat: your DPS and your percentage of the #1 player's DPS; solo combat omits meaningless rank percentages.
- `Current` and `Overall` views.
- In groups with more than 10 damage dealers, the top 9 plus your row if you are outside the top 10.

## Chat behavior

**Forever DPS posts nothing to chat by default.**

Optional chat features are opt-in only:

- `/fdps chat on` — print your finished-fight summary only to your own chat window.
- `/fdps announce party` — automatically post finished-fight summaries to party chat.
- `/fdps announce raid` — automatically post finished-fight summaries to raid chat.
- `/fdps announce instance` — automatically post finished-fight summaries to instance chat.
- `/fdps announce off` — disable automatic group posting (default).
- `/fdps report` — manually post the most recent finished-fight summary to your current group.

## Install

### Recommended: WowUp

Once the first GitHub release exists, install this repository through **WowUp → Get Addons → Install from URL** using:

`https://github.com/avp9320/ForeverDPS`

Future tagged releases can then be picked up by WowUp automatically.

### Manual

1. Download the latest release ZIP.
2. Extract the `ForeverDPS` folder into the WoW: Forever AddOns directory.
3. The final folder should contain `ForeverDPS.toc`, `ForeverDPS_Camelot.toc`, and `Core.lua` directly inside `ForeverDPS`.
4. Launch/reload WoW: Forever and enable **Forever DPS** in the AddOns list.

Forever's pre-launch client reports Interface `16001`; both standard and `_Camelot.toc` manifests are included for compatibility.

## Commands

- `/fdps` — show/hide the meter.
- `/fdps show`
- `/fdps hide`
- `/fdps current`
- `/fdps overall`
- `/fdps lock`
- `/fdps unlock`
- `/fdps scale 0.7-1.5`
- `/fdps reset`
- `/fdps chat on|off`
- `/fdps announce off|party|raid|instance`
- `/fdps report`
- `/fdps debug on|off|status` — local troubleshooting only; never posts to group chat.

## Forever API note

WoW: Forever blocks third-party addons from using the traditional combat log. Forever DPS instead reads Blizzard's server-side `C_DamageMeter` API. During combat, some returned values are protected/secret, so Forever DPS displays what the client permits live and waits until combat ends before doing comparison math.

## Launch-day status

v0.1.4 includes a first-pass layout cleanup based on the live Forever client, but the new visual layout still requires in-game verification. Verify:

1. The addon loads without Lua errors.
2. Player names/ranks populate during group combat.
3. The local player's row is identified and highlighted.
4. DPS values update without protected-value errors.
5. Post-combat rank and `% of #1` calculations appear correctly.
6. No chat messages are sent unless explicitly enabled.
