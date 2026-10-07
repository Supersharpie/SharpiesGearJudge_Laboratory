# Sharpie's Gear Judge [Laboratory] - Version History

## 🚀 v3.1.0

### 🔮 Level Look-Ahead
- **Score at Any Level**: A level slider under the sets scores both of them with the stat weights of another level, so you can see whether a piece is worth keeping for later. On Forever the weights come from your spec's per-level curve; on TBC from the level bracket. **Now** returns to your own level.
- **Too High to Wear**: Items that need a higher level than the one you're scoring at are tinted red, and their tooltip says the level they need.

### 🧬 A Profile for Each Set
- **Set 1 Profile / Set 2 Profile**: The single Scoring Profile menu is now one per set. Besides your raid profiles, each lists your leveling roles and, with Sharpie's Gear Judge Talents, its builds for your class. Put the same gear in both sets to see how it holds up for another spec or build.
- **Item Scores**: Each item shows its own score on its icon, using that set's profile.
- **Different Profiles**: When the two sets use different profiles, their totals are on different scales, so the Lab says so instead of calling one better. The item scores show which pieces don't suit the other build.

### 🗺️ Roadmap Picks
- **New Button**: Loads your gear with the Roadmap's recommended upgrades swapped in: the picks for the dungeon selected in the Roadmap, or the whole set built in its Chain Mode. See what finishing the Roadmap is worth.

### 🎯 Cap Check
- **Hit and Defense per Set**: Under each set's score: hit (or spell hit) for damage dealers and defense for tanks, against the same targets as the Stat Logic rings. It starts from your own live numbers (talents and race included) and adds the set's difference from what you wear. Red is short, green is there, yellow is more than 1% past it.
- **Hit Past the Cap Counts Less (Forever)**: A set's score now discounts hit past your cap, the same correction Gear Judge tooltips use. Before, every point of hit counted fully.

### ✨ Enchants
- **As Linked / Best Enchants**: Two buttons choose how enchants are scored. As Linked uses each item's own enchant; Best Enchants fills every enchantable slot with the best one for your level. Each set shows how many slots are unenchanted and what the best enchants would add.
- **Fixed: Other Players' Enchants**: With Gear Judge's enchant setting on "Current", every Lab item was scored with the enchant on *your* equipped item in that slot, not its own. Imported sets now score with their own enchants.

### 👥 Inspect Target
- **New Button**: Loads your target's gear into the active set. Their gear is scored with your profile, so the Lab warns you when they're a different class.

### 🐛 Bug Fixes
- **Refresh When Opened**: The Lab now rescores its sets each time you open it, so a level-up or talent change since you last looked is included.
- **Fixed: Shift-Click From Bag Addons**: Shift-clicking an item in Baganator, Bagnon and other bag addons didn't add it to the Lab. Those clicks now reach the active set, and an item is never added twice when more than one click path fires.
- **Fixed: Items Scored 0 Until Reopened**: Inspected or imported gear the game hadn't loaded yet scored 0 (and could show a blank icon). While the Lab is open it now rescores, and refreshes the icon, as soon as the item's data arrives.
- **Fixed: Hit Numbers at Low Levels (TBC)**: The Cap Check could show nonsense hit values at level 8 and below. It now uses the nearest level with real rating data.
- **Fixed: Hit Cap Correction at Another Level (Forever)**: With the level slider moved, set scores still applied your current level's hit cap. That correction now applies only at your own level.
- **Fixed: Roadmap Picks Slot Count**: The "(N slots changed)" message counted your shirt. It now counts only the Lab's slots.
- **Fixed: Talents Build Names Not Translated**: Build names in the set profile menus now show in your language.
- **Fixed: Help Window Text Cut Off**: The Help window's text now scrolls, so nothing is clipped (longer translations included).
- **Fixed: Characters With the Same First Name (Forever)**: WoW Forever names have two parts, and characters sharing a first name shared one list of saved sets. Each character now keeps its own; existing sets carry over.

### 🌍 Translations
- **Translated**: The Laboratory is now translated into every language WoW Forever launches with: German, Spanish (Spain and Latin America), French, Brazilian Portuguese, Russian, Korean and Traditional Chinese.

### ⚡ Best in Bag
- **Faster**: Best in Bag reuses its working tables and works out each bag item's possible slots once per pass, instead of creating new tables for every item it tries.
- **Fixed: One Item in Two Slots**: A single one-handed weapon in your bags could be placed in both the main hand and the off hand (and Shift-Click then tried to equip it twice). Each bag item now fills one slot at most; it becomes free again if a better item replaces it. Two copies of a weapon still fill both hands.
- **Fixed: Two Copies Only When Unique**: Two copies of the same ring or trinket were never suggested together, even though the game allows it, while two copies of a unique one-hander were. Now a second copy of any ring, trinket or one-hander is suggested unless the item is Unique or Unique-Equipped.
- **Fixed: Shift-Click With Two Copies**: Shift-Click equipped by item name, so two copies of one weapon could both point at the same bag item. It now equips each item from its own bag slot.
- **Fixed: Gear You Can't Wear**: Best in Bag could suggest bag items your character can't use (wrong armor type, weapon type or class), which then failed to equip. They're now skipped.
- **Fixed: Gear You Can't Wear Yet**: A Bind on Equip item above your level (a level-30 item at level 28) could be picked. Best in Bag now skips items above your level when equipping for real (Shift-Click), and above the Lab's look-ahead level when filling a set.
- **Fixed: Auto-Equip Cancelled Bind Confirmations**: Equipping several Bind on Equip upgrades at once with Shift-Click cancelled each "will bind to you" popup. Gear already bound to you is equipped as before; unbound upgrades are now listed in chat for you to equip yourself.

-------------------------------------------------------------------------

## 🚀 v3.0.8

### 🖼️ Redesigned for the Bigger Window
Gear Judge 3.2.0 makes the main window wider, and the Laboratory now uses the room in three columns.
- **Left**: the scoring profile (with the ? help button), then every action grouped by what it does: **Add to Active Set** (Equipped, Best in Bag, Import String), **Manage** (Copy Set 1 to Set 2, Export Active Set, Clear All) and **Saved Sets** (name and Save, the Load Set list and its delete button). Before, the buttons were packed into two rows along the bottom.
- **Middle**: Set 1 and Set 2 side by side under their buttons. The set that receives new items is outlined in gold. Each set's score sits under it, with the difference centred below both.
- **Right**: the stat comparison has columns for Set 1, Set 2 and the difference, with headings, and more room for stat names.
- While both sets are empty, the stat panel says to add items instead of sitting blank.

### 🐛 Bug Fixes
- **Stat Rows Follow the Panel Width**: Each row's text widths were fixed when the row was first made, so rows built before the panel had its size kept a 200-pixel fallback. The rows now stretch with the panel.
- **Right-Click Empties a Slot**: The slot code already emptied a slot on right-click, but the slots only listened for left-clicks. Right-click now works, as does shift-click.

---
## 🚀 v3.0.7

### 🐛 Bug Fixes
- **Loads on WoW Forever**: The Forever client reads the plain `.toc` file, which only listed the TBC client, so the Laboratory showed as Incompatible. It now lists both.

---

## 🚀 v3.0.6

### 🐛 Bug Fixes
- **Survives Removed Blizzard APIs**: The chat-link hook (`SetItemRef`) is only attached when the client still has that function. Equipping from the Lab falls back to `C_Item.EquipItemByName` through the core addon's polyfill, so it keeps working on clients that remove the old global.

---

## 🚀 v3.0.0

### 🧪 Core Engine Migration
- **Miner Hand-off**: The passive dataminer logic has been migrated directly into the core `SharpiesGearJudge` engine to allow global item injection into the Roadmap.
- **SavedVariables Fix**: Updated SavedVariables architecture to ensure compatibility with the WoW Forever beta client.
---
[v2.1.1]

* **Revamped the Export/Import popup: use BackdropTemplate and the DialogBox backdrop for standard borders, adjust layout and title positioning, resize the editbox/scroll area, and reposition the Import button.**
* **Added Escape handling to clear focus and close the popup, and refocus the editbox on mouse down to avoid focus issues.**
* **Minor cleanup and bugfixes around popup behavior.**

[v2.1.0]

# Feature Update: Best in Bag Scanner & In-Game Help

## Best in Bag (Smart Scanner)
* **Added "Best in Bag" Button:** A new utility on the control board that automatically scans all your bags to find the highest-scoring gear combinations based on your active stat weights.
* **Theorycrafting Mode (Normal Click):** Populates your currently active Lab Set with the best items found in your bags, allowing you to preview the score increase before committing.
* **Auto-Equip Mode (Shift-Click):** Evaluates your physical character, physically equips the best upgrades from your bags, and then automatically syncs your Lab Set to match your new reality.
* **Smart Conflict Resolution:** The scanner natively understands 2H vs. 1H/Shield conflicts and intelligently replaces the weakest of your two equipped Rings/Trinkets to avoid unique item conflicts.

## In-Game Help Menu
* **Instruction Manual:** Added a classic WoW-styled `?` button to the top right of the Lab interface.
* **Feature Discovery:** Clicking the button toggles a comprehensive help window detailing how to import gear, compare sets, and use hidden modifiers (like the Shift-Click auto-equip).

## UI & Under-the-Hood
* Adjusted the bottom control row layout to cleanly accommodate the new "Best in Bag" button alongside the Import and Load dropdowns.
* Implemented combat lockdown checks to prevent Lua errors if a user attempts to Shift-Click auto-equip while in combat.

[v2.0.0]

Initial Release: Launched the Laboratory plugin for the WoW Classic TBC Anniversary Server.
Comparison Engine: Integrated with the core SGJ scoring system to provide "Set 1 vs Set 2" score deltas.
**Import Logic: Support for SeventyUpgrades (JSON), SimC/Raidbots strings, and generic item ID lists.
**UI Components: Created a dual-doll interface with a scrollable stat comparison window.
**Database Management: Implemented local character saving/loading for theorycrafted gear sets.
**Smart Handling: Logic for 2H weapons automatically removing off-hands and intelligent ring/trinket slotting.