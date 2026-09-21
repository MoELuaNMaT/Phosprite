#ifndef PHOSPRITE_NATIVE_DOCUMENTS_H
#define PHOSPRITE_NATIVE_DOCUMENTS_H

#include "core/object/class_db.h"
#include "core/variant/array.h"
#include "core/variant/dictionary.h"
#include "core/variant/packed_string_array.h"

class PhospriteNativeDocuments : public Object {
	GDCLASS(PhospriteNativeDocuments, Object);

	static PhospriteNativeDocuments *singleton;
	Array pending_events;

	static void _bind_methods();

public:
	static PhospriteNativeDocuments *get_singleton();

	bool present_document_picker();
	bool present_photo_picker();
	bool reveal_in_files(const String &p_path);
	bool cleanup_temp_file(const String &p_path);

	int get_pending_event_count() const;
	Dictionary pop_event();
	void enqueue_paths(const PackedStringArray &p_paths, const String &p_source);
	void enqueue_error(const String &p_message);

	PhospriteNativeDocuments();
	~PhospriteNativeDocuments();
};

void phosprite_native_documents_initialize();
void phosprite_native_documents_shutdown();

#endif // PHOSPRITE_NATIVE_DOCUMENTS_H
