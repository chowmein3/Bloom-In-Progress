extends Node
## Networking entry point. Milestone 1 is solo, so this only hands out the
## local player id. Milestone 2 adds host/join here and turns the
## GameState.request_* calls into RPCs to the host.

const SOLO_PLAYER_ID := 1


func local_id() -> int:
	return SOLO_PLAYER_ID


func is_host() -> bool:
	return true
