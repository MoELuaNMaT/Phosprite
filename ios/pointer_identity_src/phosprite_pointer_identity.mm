#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include "phosprite_pointer_identity.h"

PhospritePointerIdentity *PhospritePointerIdentity::singleton = nullptr;

namespace {
using TouchesBeganFn = void (*)(id, SEL, NSSet *, UIEvent *);
using GetTouchIdFn = int (*)(id, SEL, UITouch *);

TouchesBeganFn original_touches_began = nullptr;
Class hooked_view_class = Nil;

int pointer_kind_for_touch(UITouch *p_touch) {
	switch (p_touch.type) {
		case UITouchTypePencil:
			return PhospritePointerIdentity::POINTER_PENCIL;
		case UITouchTypeDirect:
			return PhospritePointerIdentity::POINTER_DIRECT;
		default:
			return PhospritePointerIdentity::POINTER_INDIRECT;
	}
}

void phosprite_touches_began(id p_self, SEL p_cmd, NSSet *p_touches, UIEvent *p_event) {
	PhospritePointerIdentity *bridge = PhospritePointerIdentity::get_singleton();
	SEL get_touch_id_selector = NSSelectorFromString(@"getTouchIDForTouch:");
	if (bridge && [p_self respondsToSelector:get_touch_id_selector]) {
		GetTouchIdFn get_touch_id = reinterpret_cast<GetTouchIdFn>(objc_msgSend);
		for (UITouch *touch in p_touches) {
			// Allocate/reuse the exact touch id Godot will use, then publish identity
			// before the original handler can deliver InputEventScreenTouch to GDScript.
			int touch_id = get_touch_id(p_self, get_touch_id_selector, touch);
			if (touch_id < 0) {
				continue;
			}
			bridge->enqueue_begin_info(touch_id, pointer_kind_for_touch(touch), touch.majorRadius);
		}
	}

	if (original_touches_began) {
		original_touches_began(p_self, p_cmd, p_touches, p_event);
	}
}
} // namespace

void PhospritePointerIdentity::_bind_methods() {
	ClassDB::bind_method(D_METHOD("consume_begin_info", "touch_id"), &PhospritePointerIdentity::consume_begin_info);
	ClassDB::bind_method(D_METHOD("clear_pending"), &PhospritePointerIdentity::clear_pending);

	BIND_ENUM_CONSTANT(POINTER_UNKNOWN);
	BIND_ENUM_CONSTANT(POINTER_PENCIL);
	BIND_ENUM_CONSTANT(POINTER_DIRECT);
	BIND_ENUM_CONSTANT(POINTER_INDIRECT);
}

PhospritePointerIdentity *PhospritePointerIdentity::get_singleton() {
	return singleton;
}

Dictionary PhospritePointerIdentity::consume_begin_info(int p_touch_id) {
	Dictionary result;
	if (p_touch_id < 0 || p_touch_id >= MAX_TOUCHES || begin_queues[p_touch_id].empty()) {
		return result;
	}
	BeginInfo info = begin_queues[p_touch_id].front();
	begin_queues[p_touch_id].pop_front();
	result["kind"] = info.kind;
	result["major_radius"] = info.major_radius;
	return result;
}

void PhospritePointerIdentity::clear_pending() {
	for (int i = 0; i < MAX_TOUCHES; i++) {
		begin_queues[i].clear();
	}
}

void PhospritePointerIdentity::enqueue_begin_info(int p_touch_id, int p_kind, float p_major_radius) {
	if (p_touch_id < 0 || p_touch_id >= MAX_TOUCHES) {
		return;
	}
	BeginInfo info;
	info.kind = p_kind;
	info.major_radius = p_major_radius;
	begin_queues[p_touch_id].push_back(info);
	while (begin_queues[p_touch_id].size() > 8) {
		begin_queues[p_touch_id].pop_front();
	}
}

PhospritePointerIdentity::PhospritePointerIdentity() {
	singleton = this;
	phosprite_pointer_identity_install_touch_hook();
}

PhospritePointerIdentity::~PhospritePointerIdentity() {
	phosprite_pointer_identity_uninstall_touch_hook();
	if (singleton == this) {
		singleton = nullptr;
	}
}

void phosprite_pointer_identity_install_touch_hook() {
	if (hooked_view_class != Nil) {
		return;
	}
	Class view_class = NSClassFromString(@"GDTView");
	if (view_class == Nil) {
		return;
	}
	SEL selector = @selector(touchesBegan:withEvent:);
	Method method = class_getInstanceMethod(view_class, selector);
	if (!method) {
		return;
	}
	original_touches_began = reinterpret_cast<TouchesBeganFn>(method_getImplementation(method));
	method_setImplementation(method, reinterpret_cast<IMP>(phosprite_touches_began));
	hooked_view_class = view_class;
}

void phosprite_pointer_identity_uninstall_touch_hook() {
	if (hooked_view_class == Nil || !original_touches_began) {
		return;
	}
	SEL selector = @selector(touchesBegan:withEvent:);
	Method method = class_getInstanceMethod(hooked_view_class, selector);
	if (method && method_getImplementation(method) == reinterpret_cast<IMP>(phosprite_touches_began)) {
		method_setImplementation(method, reinterpret_cast<IMP>(original_touches_began));
	}
	hooked_view_class = Nil;
	original_touches_began = nullptr;
}
