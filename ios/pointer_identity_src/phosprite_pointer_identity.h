#ifndef PHOSPRITE_POINTER_IDENTITY_H
#define PHOSPRITE_POINTER_IDENTITY_H

#include "core/object/class_db.h"
#include "core/variant/dictionary.h"

class PhospritePointerIdentity : public Object {
	GDCLASS(PhospritePointerIdentity, Object);

public:
	enum PointerKind {
		POINTER_UNKNOWN = 0,
		POINTER_PENCIL = 1,
		POINTER_DIRECT = 2,
		POINTER_INDIRECT = 3,
	};

private:
	struct BeginInfo {
		int kind = POINTER_UNKNOWN;
		float major_radius = 0.0f;
	};

	static constexpr int MAX_TOUCHES = 32;
	static PhospritePointerIdentity *singleton;
	BeginInfo begin_info[MAX_TOUCHES];
	bool has_begin_info[MAX_TOUCHES] = {};

	static void _bind_methods();

public:
	static PhospritePointerIdentity *get_singleton();

	Dictionary consume_begin_info(int p_touch_id);
	void clear_pending();
	void enqueue_begin_info(int p_touch_id, int p_kind, float p_major_radius);

	PhospritePointerIdentity();
	~PhospritePointerIdentity();
};

VARIANT_ENUM_CAST(PhospritePointerIdentity::PointerKind);

void phosprite_pointer_identity_install_touch_hook();
void phosprite_pointer_identity_uninstall_touch_hook();

#endif // PHOSPRITE_POINTER_IDENTITY_H
