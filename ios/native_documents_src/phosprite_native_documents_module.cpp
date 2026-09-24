#include "phosprite_native_documents.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/os/memory.h"

static PhospriteNativeDocuments *native_documents = nullptr;

void register_phosprite_native_documents_types() {
	ClassDB::register_class<PhospriteNativeDocuments>();
	native_documents = memnew(PhospriteNativeDocuments);
	Engine::get_singleton()->add_singleton(
		Engine::Singleton("PhospriteNativeDocuments", native_documents)
	);
}

void unregister_phosprite_native_documents_types() {
	if (native_documents) {
		memdelete(native_documents);
		native_documents = nullptr;
	}
}
