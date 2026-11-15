# XbiGold: credits and third-party notices

XbiGold is written by Xbi and released under the GNU General Public License v3
(see `LICENSE`).

## Quest data (`Data_Quests.lua`)

`Data_Quests.lua` lists the tradeable items that World of Warcraft: Forever quests ask for:
how many quests, the quantity, the level range, the faction, the quest titles and where the
item drops. It was generated from:

- **Polestar_QuestDB** and **Polestar_frFR**, by the Polestar authors, GNU General Public
  License v3 (`GPL-3.0-only`). Only the facts XbiGold needs were kept (quest objectives,
  drop sources, French names) and recombined per item.
- Polestar_QuestDB was itself generated from **pfQuest** by Eric Mauser (Shagu),
  https://github.com/shagu/pfQuest, MIT License (notice below), and from
  **Questie / QuestieDB**, https://github.com/Questie/Questie, GNU General Public License v3.
- The map ids come from the World of Warcraft client tables (via wago.tools).

Names and texts of the game belong to Blizzard Entertainment.

### pfQuest MIT notice

```
MIT License

Copyright (c) 2017-2021 Eric Mauser (Shagu)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Thanks

- **Mastercraft** by Shadowblade: the safe way to fill the auction house search box without
  switching the auction house page (which would block later bag clicks).
- **TradeSkillMaster** and **Auctionator**: XbiGold can read their prices when they are
  installed (optional, nothing of theirs is bundled). The market value is computed the
  way TSM describes its own (mean of the cheapest listings, outliers removed).

World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of
Blizzard Entertainment, Inc. XbiGold is not affiliated with or endorsed by Blizzard
Entertainment.
