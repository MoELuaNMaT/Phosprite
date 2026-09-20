class_name ProjectIdentity
extends RefCounted

## Stable project identity helpers shared by Project serialization and the Gallery library.


static func generate_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := bytes.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [
			hex.substr(0, 8),
			hex.substr(8, 4),
			hex.substr(12, 4),
			hex.substr(16, 4),
			hex.substr(20, 12),
		]
	)


static func is_valid_uuid(value: String) -> bool:
	if value.length() != 36:
		return false
	for index in value.length():
		if index in [8, 13, 18, 23]:
			if value[index] != "-":
				return false
			continue
		var code := value.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_lower_hex := code >= 97 and code <= 102
		var is_upper_hex := code >= 65 and code <= 70
		if not (is_digit or is_lower_hex or is_upper_hex):
			return false
	return true
