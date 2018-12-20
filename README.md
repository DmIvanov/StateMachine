# StateMachine

In this sample project I'm trying to investigate different approaches to implement a state machine for a real product feature.

Let's say we have our mobile app as an interface for some remote device - let's say an air conditioner. We need to update a firmware on this device through the app. Here are the stages of the process we have:
	1. Download f/w from the remote server
	2. Store it on disc
	3. Upload it to our device
	4. Install it and restart the device

Here are the requirements:
	Downloading from API:
		- we have 2 endpoints: the first one - to check if there is a new version, the second one - to actually download the file
	UI:
	- we should update UI with the current status and some status metadata (progress, f/w version)
	- we should show errors if something goes wrong
	- we should handle errors differently
	- we should be able to restart the process from the place we stopped

Additional restrictions:
	- we should check that we know the current version, if not we shouldn't start the process
	- we shouldn't connect to the remote API if we don't have the internet (showing an error)
	- we shouldn't upload the f/w to the device if the device is not connected (showing an error)
