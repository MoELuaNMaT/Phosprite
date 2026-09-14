class_name TouchPointerOwnership
extends RefCounted

## Minimal pointer-ownership registry shared by future touch surfaces.
##
## D0 only arbitrates ownership. It intentionally does not decide whether a
## pointer represents canvas editing, scrolling, layer reordering, palette
## interaction, or any other product-specific behavior.
var _owners: Dictionary = {}


func acquire(pointer_id: int, owner: StringName) -> bool:
	if pointer_id < 0 or owner == &"":
		return false
	if _owners.has(pointer_id):
		return _owners[pointer_id] == owner
	_owners[pointer_id] = owner
	return true


func is_owned(pointer_id: int) -> bool:
	return _owners.has(pointer_id)


func is_owned_by(pointer_id: int, owner: StringName) -> bool:
	return _owners.get(pointer_id, &"") == owner


func owner_of(pointer_id: int) -> StringName:
	return _owners.get(pointer_id, &"") as StringName


func release(pointer_id: int, owner: StringName = &"") -> bool:
	if not _owners.has(pointer_id):
		return false
	if owner != &"" and _owners[pointer_id] != owner:
		return false
	_owners.erase(pointer_id)
	return true


## Cancels one pointer regardless of its current owner and returns the owner
## token so the caller can route a product-specific cancellation if needed.
func cancel(pointer_id: int) -> StringName:
	if not _owners.has(pointer_id):
		return &""
	var owner := _owners[pointer_id] as StringName
	_owners.erase(pointer_id)
	return owner


## Releases every pointer owned by [param owner] and returns their ids in a
## deterministic order, useful when a UI surface disappears mid-gesture.
func cancel_owner(owner: StringName) -> PackedInt32Array:
	var cancelled := PackedInt32Array()
	if owner == &"":
		return cancelled
	for pointer_id: int in _owners.keys():
		if _owners[pointer_id] == owner:
			cancelled.append(pointer_id)
	for pointer_id: int in cancelled:
		_owners.erase(pointer_id)
	cancelled.sort()
	return cancelled


## Clears all ownership, for example on app/window interruption. The snapshot
## lets a caller dispatch cancellation to the previous owners before discarding it.
func cancel_all() -> Dictionary:
	var snapshot := _owners.duplicate()
	_owners.clear()
	return snapshot


func active_count() -> int:
	return _owners.size()
