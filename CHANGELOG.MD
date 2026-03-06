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