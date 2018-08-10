# nZombies Unlimited
nZombies Unlimited is an experimental idea of breaking the [original nZombies](https://github.com/Zet0rz/nzombies) free from its limits. It is a complete recreation built from the ground up with the idea of modularizing _everything_ and supporting full toolkits for Config creation.

**Status:** Early development (not playable)

**How to follow progress:** View progress in the [Projects tab](https://github.com/Zet0rz/nZombies-Unlimited/projects). Read about each entry by clicking it.

**How to have an influence:** Comment on the Issues shown in the current Project with suggestions around that part.

## What's different?
nZombies Unlimited bases itself on a series of ideas:
- Sandbox-based Config Creation
- Logic System
- Powerful, rich Config structure
- Modularized Extension system

### Unlimited Creation
Using Sandbox for creating Configs breaks nZombies free from its prior Creative Mode limits. It will work with _everything_. Ropes, ragdolls, custom entities, _anything_. Any and all tools will also be available (though some less useful in an nZombies context), and most of the known nZombies Tools will appear here as well. Config Saves will be based on the same system Garry's Mod uses to save entire Sandbox games; That means _everything_ will be saved. There will be no limits.

### Powerful Logic System
Interact with the Logic Map which shows a top-down view of all Logic-enabled entities in the map. Connect them to Logic units to created complicated and interesting mechanics. Want a limited-time Pack-a-Punch room? Hook up a Button Logic unit to a door, and connect that to a Timer which will trigger a Zone to teleport all players in it to a specific location. Want buildables? Hook up a Randomizer to a series of Item Spawners that spawn parts of your buildable. Even hook up a Soul Collector to a Game Win unit for full game-ending Easter Eggs! Even control the spawners themselves!

### Rich Config Structure
Like mentioned, Configs will save _everything_ in the world. However it will also save metadata, such as a custom thumbnail, name, description, and list of authors. It will even be able to detect installed Workshop addons and let you checkmark those used for the Config, prompting the player loading it to install those if not already. Configs will be easy to move into an Addon folder and uploaded to the Workshop.

### Modularized Extension System
Addons can take the form of Extensions, letting the game detect and load them as the users enables them in their Configs. They will only load when Configs specify them, or when otherwise manually enabled by an Admin as a Config Override. Extensions can do anything the main gamemode does: Add new perks, powerups, logic units, or even entire new systems like the Perk system itself. Almost all visuals can be added to, including HUD Packs and Zombie Model packs. Extensions can also add new Zombies and Bosses. All while giving the power to the user; Extensions are only loaded when the Config enables it in its settings.

## What else?
Other than these core ideas, the whole gamemode will be built up from scratch. New lobby screen/menu, new modularized systems, new and more robust Zombie NPCs. All Zombie Models come with Animation-only rigs allowing you to compile any Valve-based model into one with all necessary animations using $includemodel. Overall, this will be the definitive nZombies. The one that breaks free from all the limits.
