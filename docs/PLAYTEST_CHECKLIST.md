# Developer panel playtest checklist

Studio Play only. Confirm the output starts with `StudioMemory` and `[DevTest] Studio memory panel authorized`. The red **TEST MODE** label should be visible. The **Dev panel** button opens a 320-pixel frame on the left. Close it again and confirm the world is unobstructed.

Stop Play when finished. The temporary session is discarded.

## Player

- [ ] Set Power to 1K. The readout and leaderstats show 1000.
- [ ] Add Power, then Reset Power.
- [ ] Set a speed override of 22. Unloaded speed becomes 22.
- [ ] Turn Slow Mode on. Effective speed becomes 16. Turn it off.
- [ ] Clear the override. Speed returns to the Power milestone.
- [ ] Cash for next trainer raises cash to the next tier price. Reset Cash afterward if income has already added some.

## Pets and items

- [ ] First Evolution scenario. The pet is a ProtoRex near the first branch and Raw Meat is carried.
- [ ] Feed preview, then confirm. Growth increases and the meat is consumed.
- [ ] Apply the eligible evolution and confirm the form changed.
- [ ] Give Ancient Bone, Bog Marrow, and Primal Catalyst on a pet that can carry them.
- [ ] Reset resources and confirm the carried test item is gone.

## Trainers

- [ ] Set trainer tier 4. The Base1 station visual changes.
- [ ] Stand at the station and buy the next tier through the panel. Cash decreases by the real price.
- [ ] Start training and confirm Power/sec and Cash/sec in the readout. Stop training.
- [ ] Reset trainer to tier 1.

## Guardians

- [ ] Teleport to each biome and confirm the character arrives near that resource area.
- [ ] Ordinary theft in Grasslands. The guardian wakes and pursues.
- [ ] Heavy theft and cursed theft. The readout shows slowdown or a curse title.
- [ ] Close and Long theft.
- [ ] Catch recovery. The character is flung, the item drops, and control returns.
- [ ] Reset scenario. The guardian is sleeping and the hands are empty.
- [ ] With two Studio clients, Two carriers. The guardian retargets. With one client, the command must fail.

## Travel

- [ ] Start the human timer, pick up a resource, return inside the safe zone, and stop the timer.
- [ ] Export JSON. The row is under `Human`.
- [ ] Run one scripted cell (Grasslands, ordinary, speed 30, middle). Confirm it first.
- [ ] Export again. The new row is under `Scripted`, with outbound, wake, chase, safety, return, and round trip filled in.
- [ ] Confirm the two lists are still separate.
- [ ] Cancel a second scripted run while it says Outbound.

## Scenarios

- [ ] Fresh Player: Power 0, tier 1, starter pet, no override.
- [ ] Swamp, Jungle, Crystal Cave, and Volcano: Power matches that biome's first gated resource, and the trainer tier updates.
- [ ] Catalyst: a compatible catalyst is carried.
- [ ] Maximum Training: tier 10 and Power 150M. Turn Slow Mode on and off and confirm the speed stays finite.

## Isolation

- [ ] A misspelled command does nothing and returns an error in the readout.
- [ ] After Stop, the next Play starts from the normal fresh Studio session.
