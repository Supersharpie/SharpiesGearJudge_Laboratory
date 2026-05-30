## [v2.1.1]

* **Revamped the Export/Import popup: use BackdropTemplate and the DialogBox backdrop for standard borders, adjust layout and title positioning, resize the editbox/scroll area, and reposition the Import button.**
* **Added Escape handling to clear focus and close the popup, and refocus the editbox on mouse down to avoid focus issues.**
* **Minor cleanup and bugfixes around popup behavior.**


## [v2.1.0]

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
