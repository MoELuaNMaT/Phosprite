#include "phosprite_pointer_identity.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/os/memory.h"

static PhospritePointerIdentity *pointer_identity = nullptr;

void register_phosprite_pointer_identity_types() {
	ClassDB::register_class<PhospritePointerIdentity>();
	pointer_identity = memnew(PhospritePointerIdentity);
	Engine::get_singleton()->add_singleton(
		Engine::Singleton("PhospritePointerIdentity", pointer_identity)
	);
}

void unregister_phosprite_pointer_identity_types() {
	if (pointer_identity) {
		memdelete(pointer_identity);
		pointer_identity = nullptr;
	}
}
