# computercraft-miner
A robot that mines in computercraft, as well as a wireless controller for it.

## Installation
### For the wireless controller:
1. Set up a computer (either type)
1. Add a wireless modem.
1. Set up a 3*2 (3 wide, 2 tall) array of advanced monitors.
1. Run the following command: `pastebin run UzQh6UMQ`
1. Restart the computer
1. If there are multiple robots or your robot has a different channel than the default, make sure the list is updated accordingly

### For the robot:
1. Place a robot (either type) at the desired dropoff location (there should be a chest beneath it)
1. Give the robot coal (a stack, probably)
1. Run the following command: `pastebin run Ytb1y6HN`
1. Ensure that the values in `data/settings` and `data/data` are correct. This includes:
    1. Changing `coords` and `heading` in `data/data`
    1. Changing the settings in `data/settings` to the desired settings
    1. Changing `message_frequency` in `data/settings` if this is not the only robot or if channel 101 is being used for something else, change the 
1. Restart the robot

## Notes
* This should work, but has not been tested with, ender modems. With just normal modems, the wireless controller and robot must be within 64 blocks to function properly. However, the robot will function without the controller, there just won't be any way to control it.
