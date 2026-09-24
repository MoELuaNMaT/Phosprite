#import <Foundation/Foundation.h>
#import <PhotosUI/PhotosUI.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>

#include "drivers/apple_embedded/godot_app_delegate.h"
#include "phosprite_native_documents.h"

PhospriteNativeDocuments *PhospriteNativeDocuments::singleton = nullptr;

static NSMutableArray<NSString *> *cold_open_paths = nil;
static id document_picker_delegate = nil;
static id photo_picker_delegate = nil;
static id app_delegate_service = nil;

static NSString *to_ns_string(const String &p_value) {
	CharString utf8 = p_value.utf8();
	return [NSString stringWithUTF8String:utf8.get_data()];
}

static String to_godot_string(NSString *p_value) {
	if (!p_value) {
		return String();
	}
	return String::utf8([p_value UTF8String]);
}

static NSURL *import_root_url() {
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"PhospriteImports"];
	[[NSFileManager defaultManager] createDirectoryAtPath:path
		withIntermediateDirectories:YES
		attributes:nil
		error:nil];
	return [NSURL fileURLWithPath:path isDirectory:YES];
}

static NSString *safe_file_name(NSString *p_name, NSString *p_fallback) {
	NSString *name = p_name.length > 0 ? [p_name lastPathComponent] : p_fallback;
	if (name.length == 0) {
		name = @"imported-file";
	}
	return [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
}

static NSURL *unique_destination_url(NSString *p_name) {
	NSURL *folder = [import_root_url() URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]
		isDirectory:YES];
	NSError *folder_error = nil;
	if (![[NSFileManager defaultManager] createDirectoryAtURL:folder
		withIntermediateDirectories:YES
		attributes:nil
		error:&folder_error]) {
		return nil;
	}
	return [folder URLByAppendingPathComponent:safe_file_name(p_name, @"imported-file")];
}

static NSURL *copy_external_url(NSURL *p_url) {
	if (!p_url || !p_url.isFileURL) {
		return nil;
	}

	BOOL scoped = [p_url startAccessingSecurityScopedResource];
	NSURL *destination = unique_destination_url(p_url.lastPathComponent);
	if (!destination) {
		if (scoped) {
			[p_url stopAccessingSecurityScopedResource];
		}
		return nil;
	}

	__block NSError *copy_error = nil;
	NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
	[coordinator coordinateReadingItemAtURL:p_url
		options:NSFileCoordinatorReadingWithoutChanges
		error:&copy_error
		byAccessor:^(NSURL *new_url) {
			NSError *error = nil;
			if (![[NSFileManager defaultManager] copyItemAtURL:new_url
				toURL:destination
				error:&error]) {
				copy_error = error;
			}
		}];

	if (scoped) {
		[p_url stopAccessingSecurityScopedResource];
	}
	if (copy_error) {
		[[NSFileManager defaultManager] removeItemAtURL:[destination URLByDeletingLastPathComponent]
			error:nil];
		return nil;
	}
	return destination;
}

static NSURL *write_photo_png(UIImage *p_image, NSString *p_name) {
	if (!p_image) {
		return nil;
	}
	NSString *base = p_name.length > 0 ? [[p_name lastPathComponent] stringByDeletingPathExtension] : @"Photo";
	NSString *name = [base stringByAppendingPathExtension:@"png"];
	NSURL *destination = unique_destination_url(name);
	if (!destination) {
		return nil;
	}

	// UIImage.size is expressed in points. Using a default UIGraphicsImageRenderer
	// multiplies that logical size by the device screen scale, so a 64×64 pixel
	// sprite can silently become 128×128 on a 2x iPad. Normalize orientation at
	// scale 1.0 using the source image's real pixel dimensions instead.
	CGFloat pixel_width = p_image.CGImage ? (CGFloat)CGImageGetWidth(p_image.CGImage) : p_image.size.width * p_image.scale;
	CGFloat pixel_height = p_image.CGImage ? (CGFloat)CGImageGetHeight(p_image.CGImage) : p_image.size.height * p_image.scale;
	BOOL swaps_axes =
		p_image.imageOrientation == UIImageOrientationLeft ||
		p_image.imageOrientation == UIImageOrientationLeftMirrored ||
		p_image.imageOrientation == UIImageOrientationRight ||
		p_image.imageOrientation == UIImageOrientationRightMirrored;
	CGSize output_size = swaps_axes ? CGSizeMake(pixel_height, pixel_width) : CGSizeMake(pixel_width, pixel_height);
	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
	format.scale = 1.0;
	format.opaque = NO;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:output_size format:format];
	UIImage *normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		[p_image drawInRect:CGRectMake(0, 0, output_size.width, output_size.height)];
	}];
	NSData *data = UIImagePNGRepresentation(normalized);
	if (!data || ![data writeToURL:destination atomically:YES]) {
		[[NSFileManager defaultManager] removeItemAtURL:[destination URLByDeletingLastPathComponent]
			error:nil];
		return nil;
	}
	return destination;
}

static UIViewController *top_view_controller() {
	UIApplication *application = [UIApplication sharedApplication];
	UIWindow *window = nil;
	for (UIScene *scene in application.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		UIWindowScene *window_scene = (UIWindowScene *)scene;
		if (window_scene.activationState != UISceneActivationStateForegroundActive &&
			window_scene.activationState != UISceneActivationStateForegroundInactive) {
			continue;
		}
		for (UIWindow *candidate in window_scene.windows) {
			if (candidate.isKeyWindow) {
				window = candidate;
				break;
			}
		}
		if (!window && window_scene.windows.count > 0) {
			window = window_scene.windows.firstObject;
		}
		if (window) {
			break;
		}
	}
	if (!window) {
		window = application.windows.firstObject;
	}

	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController) {
		controller = controller.presentedViewController;
	}
	if ([controller isKindOfClass:[UINavigationController class]]) {
		controller = ((UINavigationController *)controller).visibleViewController;
	}
	if ([controller isKindOfClass:[UITabBarController class]]) {
		controller = ((UITabBarController *)controller).selectedViewController;
	}
	return controller;
}

static void enqueue_paths_on_main(NSArray<NSString *> *p_paths, NSString *p_source) {
	dispatch_async(dispatch_get_main_queue(), ^{
		PhospriteNativeDocuments *bridge = PhospriteNativeDocuments::get_singleton();
		if (!bridge) {
			if ([p_source isEqualToString:@"open_in"]) {
				if (!cold_open_paths) {
					cold_open_paths = [NSMutableArray new];
				}
				[cold_open_paths addObjectsFromArray:p_paths];
			}
			return;
		}
		PackedStringArray paths;
		for (NSString *path in p_paths) {
			paths.push_back(to_godot_string(path));
		}
		if (!paths.is_empty()) {
			bridge->enqueue_paths(paths, to_godot_string(p_source));
		}
	});
}

static void enqueue_error_on_main(NSString *p_message) {
	dispatch_async(dispatch_get_main_queue(), ^{
		PhospriteNativeDocuments *bridge = PhospriteNativeDocuments::get_singleton();
		if (bridge) {
			bridge->enqueue_error(to_godot_string(p_message));
		}
	});
}

static void capture_open_url(NSURL *p_url) {
	if (!p_url || !p_url.isFileURL) {
		return;
	}
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSURL *copied = copy_external_url(p_url);
		if (copied) {
			enqueue_paths_on_main(@[copied.path], @"open_in");
		} else {
			enqueue_error_on_main(@"Could not copy the document opened by Files.");
		}
	});
}

static void scene_open_url_contexts(id p_self, SEL p_cmd, UIScene *p_scene, NSSet<UIOpenURLContext *> *p_contexts) {
	for (UIOpenURLContext *context in p_contexts) {
		capture_open_url(context.URL);
	}
}

static void scene_will_connect(id p_self, SEL p_cmd, UIScene *p_scene, UISceneSession *p_session, UISceneConnectionOptions *p_options) {
	for (UIOpenURLContext *context in p_options.URLContexts) {
		capture_open_url(context.URL);
	}
}

static void install_scene_url_hooks() {
	Class delegate_class = [GDTApplicationDelegate class];
	class_addMethod(
		delegate_class,
		@selector(scene:openURLContexts:),
		(IMP)scene_open_url_contexts,
		"v@:@@"
	);
	class_addMethod(
		delegate_class,
		@selector(scene:willConnectToSession:options:),
		(IMP)scene_will_connect,
		"v@:@@@"
	);
}

@interface PhospriteNativeDocumentsBootstrap : NSObject
@end

@implementation PhospriteNativeDocumentsBootstrap
+ (void)load {
	cold_open_paths = [NSMutableArray new];
	install_scene_url_hooks();
}
@end

@interface PhospriteDocumentPickerDelegate : NSObject <UIDocumentPickerDelegate>
@end

@implementation PhospriteDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	if (urls.count == 0) {
		return;
	}
	dispatch_group_t group = dispatch_group_create();
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:urls.count];
	for (NSUInteger index = 0; index < urls.count; index++) {
		[results addObject:[NSNull null]];
		dispatch_group_enter(group);
		NSURL *url = urls[index];
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
			NSURL *copied = copy_external_url(url);
			@synchronized(results) {
				if (copied) {
					results[index] = copied.path;
				}
			}
			dispatch_group_leave(group);
		});
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		NSMutableArray<NSString *> *paths = [NSMutableArray new];
		for (id result in results) {
			if ([result isKindOfClass:[NSString class]]) {
				[paths addObject:(NSString *)result];
			}
		}
		if (paths.count > 0) {
			enqueue_paths_on_main(paths, @"files");
		}
		if (paths.count != urls.count) {
			enqueue_error_on_main(@"One or more selected files could not be copied.");
		}
	});
}

@end

@interface PhospritePhotoPickerDelegate : NSObject <PHPickerViewControllerDelegate>
@end

@implementation PhospritePhotoPickerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (results.count == 0) {
		return;
	}

	dispatch_group_t group = dispatch_group_create();
	NSMutableArray *paths_by_index = [NSMutableArray arrayWithCapacity:results.count];
	for (NSUInteger index = 0; index < results.count; index++) {
		[paths_by_index addObject:[NSNull null]];
		PHPickerResult *result = results[index];
		NSItemProvider *provider = result.itemProvider;
		dispatch_group_enter(group);
		[provider loadObjectOfClass:[UIImage class]
			completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
				UIImage *image = [object isKindOfClass:[UIImage class]] ? (UIImage *)object : nil;
				if (image && !error) {
					NSURL *destination = write_photo_png(image, provider.suggestedName);
					if (destination) {
						@synchronized(paths_by_index) {
							paths_by_index[index] = destination.path;
						}
					}
				}
				dispatch_group_leave(group);
			}];
	}

	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		NSMutableArray<NSString *> *paths = [NSMutableArray new];
		for (id value in paths_by_index) {
			if ([value isKindOfClass:[NSString class]]) {
				[paths addObject:(NSString *)value];
			}
		}
		if (paths.count > 0) {
			enqueue_paths_on_main(paths, @"photos");
		}
		if (paths.count != results.count) {
			enqueue_error_on_main(@"One or more selected photos could not be prepared for import.");
		}
	});
}

@end

@interface PhospriteNativeDocumentsAppDelegateService : NSObject <UIApplicationDelegate>
@end

@implementation PhospriteNativeDocumentsAppDelegateService

- (BOOL)application:(UIApplication *)application
	openURL:(NSURL *)url
	options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	if (!url.isFileURL) {
		return NO;
	}
	capture_open_url(url);
	return YES;
}

@end

static bool present_document_picker() {
	UIViewController *controller = top_view_controller();
	if (!controller) {
		return false;
	}

	NSMutableArray<UTType *> *types = [NSMutableArray new];
	for (NSString *extension in @[
		@"pxo", @"ase", @"aseprite", @"png", @"bmp", @"hdr", @"jpg", @"jpeg", @"svg", @"tga", @"webp", @"exr"
	]) {
		UTType *type = [UTType typeWithFilenameExtension:extension];
		if (type && ![types containsObject:type]) {
			[types addObject:type];
		}
	}
	if (types.count == 0) {
		[types addObject:UTTypeData];
	}

	UIDocumentPickerViewController *picker =
		[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:NO];
	picker.allowsMultipleSelection = YES;
	if (!document_picker_delegate) {
		document_picker_delegate = [PhospriteDocumentPickerDelegate new];
	}
	picker.delegate = document_picker_delegate;
	[controller presentViewController:picker animated:YES completion:nil];
	return true;
}

static bool present_photo_picker() {
	UIViewController *controller = top_view_controller();
	if (!controller) {
		return false;
	}

	PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
	configuration.filter = [PHPickerFilter imagesFilter];
	configuration.selectionLimit = 0;
	PHPickerViewController *picker =
		[[PHPickerViewController alloc] initWithConfiguration:configuration];
	if (!photo_picker_delegate) {
		photo_picker_delegate = [PhospritePhotoPickerDelegate new];
	}
	picker.delegate = photo_picker_delegate;
	[controller presentViewController:picker animated:YES completion:nil];
	return true;
}

static bool reveal_in_files(NSString *p_path) {
	if (p_path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:p_path]) {
		return false;
	}
	NSURL *file_url = [NSURL fileURLWithPath:p_path];
	NSString *absolute = file_url.absoluteString;
	if (![absolute hasPrefix:@"file://"]) {
		return false;
	}
	NSString *shared = [absolute stringByReplacingCharactersInRange:NSMakeRange(0, 7)
		withString:@"shareddocuments://"];
	NSURL *files_url = [NSURL URLWithString:shared];
	if (!files_url) {
		return false;
	}
	[[UIApplication sharedApplication] openURL:files_url
		options:@{}
		completionHandler:^(BOOL success) {
			if (!success) {
				enqueue_error_on_main(@"Files could not reveal the requested project.");
			}
		}];
	return true;
}

static bool cleanup_temp_path(NSString *p_path) {
	if (p_path.length == 0) {
		return false;
	}
	NSString *root = import_root_url().path.stringByStandardizingPath;
	NSString *path = p_path.stringByStandardizingPath;
	if (![path hasPrefix:[root stringByAppendingString:@"/"]]) {
		return false;
	}
	NSURL *file_url = [NSURL fileURLWithPath:path];
	NSURL *folder = [file_url URLByDeletingLastPathComponent];
	return [[NSFileManager defaultManager] removeItemAtURL:folder error:nil];
}

void PhospriteNativeDocuments::_bind_methods() {
	ClassDB::bind_method(D_METHOD("present_document_picker"), &PhospriteNativeDocuments::present_document_picker);
	ClassDB::bind_method(D_METHOD("present_photo_picker"), &PhospriteNativeDocuments::present_photo_picker);
	ClassDB::bind_method(D_METHOD("reveal_in_files", "path"), &PhospriteNativeDocuments::reveal_in_files);
	ClassDB::bind_method(D_METHOD("cleanup_temp_file", "path"), &PhospriteNativeDocuments::cleanup_temp_file);
	ClassDB::bind_method(D_METHOD("get_pending_event_count"), &PhospriteNativeDocuments::get_pending_event_count);
	ClassDB::bind_method(D_METHOD("pop_event"), &PhospriteNativeDocuments::pop_event);
}

PhospriteNativeDocuments *PhospriteNativeDocuments::get_singleton() {
	return singleton;
}

bool PhospriteNativeDocuments::present_document_picker() {
	return ::present_document_picker();
}

bool PhospriteNativeDocuments::present_photo_picker() {
	return ::present_photo_picker();
}

bool PhospriteNativeDocuments::reveal_in_files(const String &p_path) {
	return ::reveal_in_files(to_ns_string(p_path));
}

bool PhospriteNativeDocuments::cleanup_temp_file(const String &p_path) {
	return ::cleanup_temp_path(to_ns_string(p_path));
}

int PhospriteNativeDocuments::get_pending_event_count() const {
	return pending_events.size();
}

Dictionary PhospriteNativeDocuments::pop_event() {
	if (pending_events.is_empty()) {
		return Dictionary();
	}
	Dictionary event = pending_events[0];
	pending_events.remove_at(0);
	return event;
}

void PhospriteNativeDocuments::enqueue_paths(const PackedStringArray &p_paths, const String &p_source) {
	Dictionary event;
	event["type"] = "paths";
	event["source"] = p_source;
	event["paths"] = p_paths;
	pending_events.push_back(event);
}

void PhospriteNativeDocuments::enqueue_error(const String &p_message) {
	Dictionary event;
	event["type"] = "error";
	event["message"] = p_message;
	pending_events.push_back(event);
}

PhospriteNativeDocuments::PhospriteNativeDocuments() {
	singleton = this;
	phosprite_native_documents_initialize();
}

PhospriteNativeDocuments::~PhospriteNativeDocuments() {
	phosprite_native_documents_shutdown();
	if (singleton == this) {
		singleton = nullptr;
	}
}

void phosprite_native_documents_initialize() {
	if (!document_picker_delegate) {
		document_picker_delegate = [PhospriteDocumentPickerDelegate new];
	}
	if (!photo_picker_delegate) {
		photo_picker_delegate = [PhospritePhotoPickerDelegate new];
	}
	if (!app_delegate_service) {
		app_delegate_service = [PhospriteNativeDocumentsAppDelegateService new];
		[GDTApplicationDelegate addService:app_delegate_service];
	}

	if (cold_open_paths.count > 0) {
		NSArray<NSString *> *paths = [cold_open_paths copy];
		[cold_open_paths removeAllObjects];
		enqueue_paths_on_main(paths, @"open_in");
	}
}

void phosprite_native_documents_shutdown() {
	document_picker_delegate = nil;
	photo_picker_delegate = nil;
	app_delegate_service = nil;
}
