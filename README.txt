This project is based on the tiny ray caster tutorial from https://github.com/ssloy/tinyraycast

TODO list:
- figure out what the hell I want to do with the enemy rendering
	- start with just getting the math in?
- consolidate player state signals
- add proper levels using nodes to represent enemies/walls
	- skull_enemy.tscn is kind of a start to this
	- walls need:
		- texture
		- start/end pos
		- texture orientation?
		- vertical start/end? sounds complicated
	- rooms need to have specfic enclosed polygons of walls, connections to other rooms
- movement is very inconsistent at exotic FPS
- The edge of wall tiles tend to be rendered strangely
	- changing the amount of rendering loops changes how large this error is
	- might have to do with the cheaty_scaled thing
- enemy disappearing bug
