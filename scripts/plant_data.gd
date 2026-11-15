extends Resource
## Definition of one plant species. Instances live in res://data/plants/*.tres.

@export var id: String = ""
@export var display_name: String = ""
## Days spent in each growth stage before maturity, e.g. [1, 2, 2] = 5 days.
@export var days_per_stage: Array[int] = [1, 2, 2]
## Seasons the plant is awake in (0 spring, 1 summer, 2 fall, 3 winter).
@export var seasons: Array[int] = [0]
## Regrowing plants stay after harvest and become ripe again after regrow_days.
@export var regrows: bool = false
@export var regrow_days: int = 3
## Placeholder-art shape: "flower", "bush" or "mushroom".
@export var shape: String = "flower"
@export var leaf_color: Color = Color(0.3, 0.6, 0.3)
@export var bloom_color: Color = Color(1, 0.8, 0.3)
@export var radiant_color: Color = Color(1, 1, 0.8)


func total_days() -> int:
	var total: int = 0
	for d: int in days_per_stage:
		total += d
	return total


## Stage 0 is a seed; stage == days_per_stage.size() is mature.
func stage_for(days_grown: int) -> int:
	var left: int = days_grown
	var stage: int = 0
	for d: int in days_per_stage:
		if left < d:
			return stage
		left -= d
		stage += 1
	return stage
