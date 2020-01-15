tkATC
-----

Air Traffic Controller for [Tcl/Tk](http://www.tcl.tk).
Based on the [ATC Game](https://github.com/vattam/BSDGames/tree/master/atc) from the [BSDGames](https://github.com/vattam/BSDGames) package.

![Map](https://github.com/oliverbacsi/tkATC/blob/master/_help/Map.png)

I always enjoyed playing the ATC game from BSDGames on a curses capable terminal.
Although after some time I was not satisfied any more with some details of the game:
* It did not have color. (I know it has to work on all terminals, but I todays terminals all support colors)
* There were no flight direction vectors so it was hard to see which plane flies which direction
* etc

So I upgraded it to a colorful and informative version. See it [here](https://github.com/oliverbacsi/BSDGames). It requires a color terminal to run but still uses curses.

Later on I stumbled upon the [Next Generation ATC](https://github.com/quasipedia/atc-ng), it's much more realistic, the gameplay is not that basic but tries to imitate real life ATC to a certain level. Although this was the reason I started to dislike it as I am just a casual gamer and did not want to learn more complex rules, I rather prefer simple and easy-to-learn rules and fast gameplay.
So I needed some kind of ATC game that still uses the _(slightly upgraded)_ old and basic game logic _(adding some features and eliminating some weak points)_ but already has a nice GUI.
As there was none, so I decided to rewrite the game in Tcl/Tk.
This is the result of it.

###Differences between BSD/ATC and tkATC
-----------------------------------------

Here are some differences related to the logic and gameplay between the two games.
_(differences between a mono curses terminal and the features of a graphic GUI are obvious, so just skip these)_

 |BSDGames/ATC|tkATC
-|------------|-----
Plane heading|Flight directions not indicated on map|Flight directions indicated by plane icon (on map and in plane list) as well as numerically within the plane details field
Fuel gauge|No way to determine exact amount of fuel, there is only a "low fuel" warning|Actual fuel is shown as a bar gauge in the plane list as well as with numbers in the plane details
Itinerary|You can only specify either a direct command or a delayed command to be executed at a beacon|You can set up an arbitrary long itinerary list to be executed during flight: either immediately/sequentially/or delayed: before or at a certain point
Correct mistakes|You can only write a new itinerary for a certain plane in case of a mistake|You can recall and edit the full itinerary of each plane
Delayed commands|You can only execute delayed commands at beacons|All airports and exits can be used as beacons, and You can execute a command **before** and **upon reaching** such a map feature
Realistic turns|When turning at a beacon (turn towards something) You can turn any arbitrary degrees within one step|You can only turn 45 degrees in one step
Circling|Possibility to circle the plane|Currently not possible to circle, checking if it makes sense at all
Object identification|Planes are identified by letters, while map features are identified by single digit numbers. (I guess to spare space on the map)|Planes are identified by letters, but all map features have unique names (based on the city name they are at) and can be referred to as a three-letter abbreviations
Landings|One of the challenges was to "catch" a certain plane right before landing and give landing command, otherwise You missed the airport. This is not realistic as pilots are not idiots, they will be able to land even without an ATC telling them to|There is a possibility for a delayed command to be executed before reaching a certain object, so the landing command can be delayed right in front of the airport, so automated landing is possible: `+PRA:A0` = "Before reaching Prague Airport set the target altitude to zero"
Pause|No way to pause the game. The logic behind it: If You are able to pause the game, You have the chance to cheat, giving You any time You need to think about the situation, while in real life You can not pause the planes mid-air, waiting for You to figure out how You want to control them. This is true, but during a game there might be situations where You have to interrupt for some minutes (phone call / toilet break) and it is very annoying loosing a game because You needed to talk to someone for half a minute... In real life someone jumps in and takes over the control if the ATC needs a break. |Possibility to pause the game with the little red "P" button in the bottom-right of the map. If You are a hardcore gamer, and want to simulate real life situations, and You want to prove for Yourself, then simply don't click it. That's so easy. You can claim that people who pause the game are cheating. OK, but who are they cheating? Themselves? They know that they have reached a higher score by pausing the game. So...? As there is no trophy and there is no prize for high scores, I see no reason why the pause button should be banned from the game.


###Gameplay
-----------
Basics are the same as BSDGames/ATC.
On the left side the big area is the game field ("Arena" in BSDGames). On the right side there is the plane list.
Below the map there is the "Details" field (dark blue). Click on anything (Plane, Airport, etc) to see its details.
At the very bottom there is a dark green bar: this is the command field, here You can type and set up the itinerary of each plane.
>**Syntax is:**
>`plane id` `task1` `task2` `task3/1`,`task3/2` `...`
>* Tasks are carried out sequentially one after the other, one in each step. `task2` is carried out in the next step after `task1`.
>* Tasks are separated by **spaces**, therefore there should not be any space within one single task.
>* If multiple actions are required within one single game step, then they should be separated by **commas**. See above: `task3/1` and `task3/2` are executed in the same step
>* Uninterpretable tasks are silently ignored, so this way You can add "empty" steps where the plane just carries out flying not receiving new orders, so You can delay Your next command by 1-2 steps:
>`Q` `45` `x` `x` `A1` = "For Plane Q : New target direction is 45 degrees, next step do nothing, next step do nothing, next step Set target altitude to 1000ft"
>* Delayed tasks can be also added, these will pause the execution of the whole itinerary until the certain map feature is reached:
>	* Execute **at** a certain map point:
>	  **@** `name` **:** `task` , where **name** is the 3-letter abbreviation of a map feature, and task is a usual task (commands separated with commas)
>	  Using this syntax the plane will reach the certain map feature, will fly above it, and once it is **already over it**, then carries out the desired command
>	  Example1: `Z` `@ZUR:A6,315` = "For Plane Z : Do nothing until reaching Zurich. When being over Zurich set the target altitude to 6000ft and at the same time set the target direction to 315 degrees"
>	  Example2: `X` `@ZUR:A6` `315` = "For Plane X : Do nothing until reaching Zurich. When being over Zurich set the target altitude to 6000ft, and in the following step set the target direction to 315 degrees"
>	  
>	* Ececute **before** a certain map point:
>	  **+** `name` **:** `task` , so "plus" sign instead of "at" sign, but same as above.
>	  Using this syntax the plane will carry out the desired command **just before** reaching the specified object, even if this means not reaching it actually. (turning away)
>	  Example3: `W` `+PRA:A0` = "For Plane W : Just before reaching Prague set the target altitude to zero" - this is basically how to land without watching - although it only works if the current altitude was 1000ft, as the plane can only descend 1000ft per step, so You will hit the ground somewhere behind the airport.
>
> ++A complex itinerary would look like:++
> `G` `A7` `x` `x` `R` `@BEL:A3` `x` `315` `A1` `+VIE:A0`
> For Plane G the above itinerary reads as following:
>	* Take off from airport with target altitude 7000ft (climb 1000ft each step)
>	* 3 steps later turn right (by 45 degrees) (continue climbing)
>	* Carry on flying until Belgrade
>	* When being over Belgrade set new target altitude to 3000ft and start descending step by step
>	* 2 steps later set new target flight direction to 315 degrees (northwest)
>	* in the next step start descending until You reach 1000ft stable altitude
>	* Right before stepping into the map cell of Vienna set the target altitude to zero
>	* In the next step the plane steps into the cell of Vienna and descends to zero (lands)

###Controls
-----------

**Left click** on a **plane or map object** lists its details at the bottom of the map.
**Right click on a plane** shows its fuel range _(white square)_ as well as planned flight path _(thick blue line)_, considering all data and itierary, pre-warning possible crashes. Lightness of the blue path indicates flight level.
**Right click on a map feature** (airport, beacon) appends its name into the itinerary with the appropriate syntax. Like: clicking on "BUD" will append: " +BUD:"
Clicking on a **plane in the plane list** will (possibly) center the plane on the map and select it, offering its current itinerary for further editing.
The background colors in the plane list have no specific meaning, they are just trying to match the airplane colors, to be able to distinguish planes better.
The color of the fuel bar shows how critical the situation is: green bar = plenty of fuel, yellow bar = start thinking about optimizing the route, red bar = fuel is critical, take immediate actions.

#####For each plane in the plane list:

* On the left side there is the plane icon.
	* Icon direction matches actual flight direction
	* Plane type (propeller or jet) can be figured out by the icon
	* Plane color is just decorative/fun but has no meaning. It's to distinguish easier between planes
* Top text row is the Plane ID (one letter) and flight level (one number), the flight level number is shifted towards right when increasing, so it's easier to see with one glance which planes are on the same level
* Second text row is Departure and Destination with the three-letter abbreviations. Green letters mean airports, blue letters mean exits, so You can see the destination type (whether to set flight level to 9 or 0)
* Third text row with black text is the actual itinerary, melting away word by word as the plane carries out the tasks
* The bottom horizontal bar is the fuel gauge, green over 50 units, yellow over 25, and red under 25

> This screen shot shows an example for the plane list:
> ![Details](https://github.com/oliverbacsi/tkATC/blob/master/_help/Details.png)
> * The red propeller plane is called "H", flying on 5000ft towards southwest. Coming from Belgrade airport, heading to Tunis airport. At the moment it is not following any orders, just keeps flying until the fuel runs out or it leaves the map or it crashes into something. So it will still need some further attention later on. It still has some fuel, no need to worry.
> * The red jet plane is called "I", flying towards north on 9000ft. It won't land on the covered area, it came in from Niger and wants to leave the covered area towards Moscow. When reaching the beacon of Pescara it will turn right. It has plenty of fuel.
> * The yellow propeller airplane is "J", standing on the ground (alt=0) at the airport of Lviv. It wants to take off and leave the map towards Cairo. So it received the instructions to set flight level to 5000ft first (basically take off and start climbing), and after take off at the next step start turning towards south. It is also filled with fuel.



###Maps and configurability
---------------------------

Just like for BSDGames/ATC, tkATC can be also extended with further maps (or as BSDGames calls them: "games").
For each additional map/game You want, You have to put a new subfolder into the "games" folder. The subfolder's name will be the name of the new game.
Within each such subfolder two files have to be put:
* **BaseMap.jpg** : This jpeg picture will be the map _(the game field's background)_ You are playing over. As all planes and map icons are currently fixed 46pixel, so at the moment there is only a way to use such BaseMap.jpg pictures for which the width and the height is a multiplicant of 46. The Map file provided with the game (CentralEU) is 2300x2300 pixel, giving You a play field of 50x50 squares (when divided by 46x46). May be later on icons and game elements could be resized dynamically, giving You a scalable game map. But currently everything is a multiplicant of 46.
* **Config.txt** : This simple text file configures all the map elements and the game properties. For each non-empty text row the following syntax has to be followed: The row begins with a single letter command, followed by the parameters, everything separated by spaces. Valid commands are:
	* `W` `pixels` : Specifies the map width in pixels.
Example: `W` `2300` = The map is 2300pixels wide.
	* `H` `pixels` : Specifies the map height in pixels.
Example: `H` `2300` = The map is 2300pixels high.
	* `D` `secs` : Sets the game pace. This many seconds will pass between two steps.
Example: `D` `10` = Between two game steps 10 seconds waiting time will be provided for You to do typing.
Jet planes move every step, Propeller planes are slower, they only move every second game step. Increase this number to slow down the game.
	* `M` `pieces` : Maximum number of planes in game. If reaching this number no new plane will enter the map or appear at any airport until a currently flying plane has landed or left the map.
Example: `M` `15` = Maximum 15 planes are allowed simultaneously.
Increase this number to allow a busy air traffic.
	* `F` `randmax` : This specifies the frequency a new airplane is sent into the game. A random number is generated between 1 and "randmax" to define the number of steps that pass between two new airplane arrivals.
Example: `F` `12` = Between two airplane arrivals 1 .. 12 steps will happen (randomly).
Decrease this number to make planes appear more frequently.
	* `A` `abbrev` `xpos` `ypos` `direction` `fullname` : Define a new airport on the map. "abbrev" will be the short identifier (this will appear on the map as well as in the itiner). "xpos" and "ypos" is the location on the map specified in cells (not pixels), direction is the landing/starting direction in degrees, must be multiplicant of 45 degrees, "fullname" is the Complete name of the airport.
Example: `A` `BUD` `29` `15` `315` `Budapest` = New Airport, short reference is "BUD", it will be in the cell 29,15 on the map, the landing/starting direction is 315 (towards northwest), and the full name is "Budapest" as it will appear in the descriptions.
	* `E` `abbrev` `xpos` `ypos` `direction` `fullname` : Same as above, but this creates exit points on the map. (Let's say endpoints of flight corridors). Theoretically there is no limitation where and how to put exits but the only thing that makes sense is to put them on the edge of the map, pointing outwards.
Example: `E` `MOS` `49` `0` `45` `Moscow` = The exit towards Moscow is at position 49,0 (so on the edge of the map), planes have to leave the map flying towards 45 (northeast), and You can refer to the exit as "MOS" in the itiners.
	* `B` `abbrev` `xpos` `ypos` `fullname` : This command defines a new beacon (orientation point) on the map. Similar to above items, but this has no direction as it is just a reference point on the map (represented as a radio tower). You can choose an arbitrary location for the beacons but to make use of them put them into the intersection points of the theoretical direction lines of the airports and exits.
Example: `B` `PES` `19` `30` `Pescara` = The beacon of Pescara is at x=19,y=30 and You can refer it as "PES"

---


####Some more Itinerary Examples for practicing:
------------------------------------------------
`K L A1 X R,A3 270 @BUD:R R +WAR:90,A7`

Interpretation: **Itinerary for Plane "K"**
* At the very next possible step turn 45 degrees **left** compared to the actual flight direction
* At the next step change **target altitude to 1** (even if it takes several steps to actually reach it)
* At the next step "X" is uninterpretable, so **ignore** and carry on with the latest orders for one more step
* At the next step **turn right** by 45 degrees and simultaneously in the same step set the **target altitude to 3**
* At the next step set the **target flight direction** to the absolute **270** degrees on the map (West), which will not be immediately the actual flight direction of the plane, but it will be reached by 45 degrees steps towards the "closer" side, so the plane will fly a curved path to reach this.
* Now keep the last orders and carry on flying until You **reach** the airport of **BUD**apest and if You are already there, then turn right
* After leaving BUDapest in the next step turn **right** again
* Keep on flying and if You are **about to enter** the area of the **WAR**saw airport, then before the airport set new **flight direction** to absolute **90** degrees (East) and simultaneously change the target flight level to 7
* No more instructions, keep on flying
> note: the last instruction will also cause that the plane will never actually reach Warsaw, as it has turned away right before entering it. So appending an additional `@WAR:` task will *never* be executed!

---

Example to make a 90 degree turn at a beacon but still remaining over the perpendicular flight corridors: (this is how You can substitute the immediate 90degree turns at beacons in BSDGames)
`H +PRA:L L`
Interpretation: **Itinerary for Plane "H"**
* One step before beacon **PRA**gue turn **left** 45 degrees
* In the next step turn **left** again 45 degrees
> This way the plane will never actually fly over Prague, but makes two 45degree turns so that both flight paths (before and after Prague) will be in-line with Prague
> Writing `H @PRA:90` will result that the plane will only start turning over Prague, causing that after the turn the flight path will be not in-line with Prague

---

Same example as above, but You only want to turn total 45 degrees at the beacon, remaining over the flight corridors: Then You have to start the turning exactly over the orientation point:
`H @PRA:L`
> So it's not a `+` but an `@` because the simple 45 degree left turn can be executed immediately so You are OK to do it flying already **over** the beacon.

---

Example for automatic landing:
`B A1 x x x x x +VIE:A0`
Interpretation: **Itinerary for Plane "B"**
* Change target flight level to 1
* Dummy commands give the plane some spare steps to reduce altitude to actually 1
* Right before Vienna airport the target altitude is changed to 0
* So at the next step when the plane is actually stepping into the cell of Vienna, the actual altitude will be 0, so the plane is landed


###Bugs, ToDo:
-------------------
* [ ] When drawing airplane route, crash is detected between the future position of the current plane and the current positions of the other planes (so other planes are not animated towards future)
* [ ] Regarding crash condition detection: A plane needs to actually leave the play field (disappearing) to detect that it has left and initiate a crash report. By this time You won't see the plane any more, not knowing where it actually left...
* [ ] May be a "Show past flight trail" feature could be added /just like at [FlightRadar24](https://flightradar24.com)/, to be able to review the flown path, and to somewhat solve the previous "ToDo" item
