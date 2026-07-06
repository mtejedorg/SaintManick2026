class_name ShopUpgrade
extends Resource

enum Currency { SCRAP, CELLS, CORES }

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var currency: Currency = Currency.SCRAP
@export var prerequisite_id: String = ""
@export var is_repeatable: bool = false
