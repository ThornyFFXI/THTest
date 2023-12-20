## THTest
This addon, for Ashita4, tracks TH data as measured by proc rate per round, sorted by current mob TH level.  To use:<br>
- Copy the entire repo to `Ashita/Addons/THTest/` (you may need to create this folder).
- Edit line 27 to reflect your current TH.  Don't forget traits.  Save the file.  Do not change your gear while running the test, this does not track equipment.
- Load the addon with `/addon load THTest`.
- Kill some stuff, ensuring that nobody else is applying or upgrading TH.  You should probably not use SA/TA/Feint, they will skew data.
- Addon assumes every new target has reset back to your base TH level(or 8, if it is higher than 8), so don't change targets until they die.

## Output
Files will be automatically created in `Ashita/logs/thtest/`.  If you open the CSV in excel while the addon is running, it will interfere with the addon, as excel claims exclusive access.  Any data created while the file cannot be accessed will go to a seperate file with the `_missed` added to the filename.  If you open both at once, logging will fail entirely.  It's best to open in notepad++, make a copy of the file, etc.. if you need to look at the raw data while the addon is running.  Each line represents one attack round.  The headings are:
- Timestamp (UTC stamp of when the attack round occured)
- Mob TH Level
- Player TH Level (sourced from line 27 of the addon, make sure to update this and reload addon when changing tests!!)
- Proc Index (The attack within the round that a proc occured, 0 if no proc.  Should always be 1 if procs only occur on first hit.)
- Proc Crit (1 if the proc was on a crit, 0 if not.)
- First Hit Crit (1 if the first hit of the round was a crit, 0 if not)
- First Hit Land (1 if the first hit of the round landed, 0 if it missed)
- First Hit Damage (damage from first hit of round)


## Display
The addon also displays a real time display for verifying behavior/user satisfaction.  It looks like this:<br>
![Alt text](images/screenshot.png?raw=true "Display")<br>
It can be dragged with shift-click-drag.
