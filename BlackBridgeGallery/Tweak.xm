#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

static NSString *const BBInbox = @"/var/mobile/Media/Downloads/BlackBridge";
static NSMutableDictionary<NSString *, NSNumber *> *BBObservedSizes;
static NSMutableSet<NSString *> *BBImportsInFlight;
static dispatch_source_t BBTimer;

static BOOL BBIsVideo(NSString *extension) {
    return [@[@"mov", @"mp4", @"m4v"] containsObject:extension];
}

static BOOL BBIsSupported(NSString *extension) {
    return [@[@"jpg", @"jpeg", @"png", @"gif", @"heic", @"heif", @"tif", @"tiff", @"mov", @"mp4", @"m4v"] containsObject:extension];
}

static void BBImportFile(NSString *path) {
    if ([BBImportsInFlight containsObject:path]) return;
    [BBImportsInFlight addObject:path];
    NSURL *url = [NSURL fileURLWithPath:path];
    BOOL video = BBIsVideo(path.pathExtension.lowercaseString);

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        if (video) {
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        } else {
            [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
        }
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [BBImportsInFlight removeObject:path];
            [BBObservedSizes removeObjectForKey:path];
            if (success) {
                NSError *removeError = nil;
                [[NSFileManager defaultManager] removeItemAtPath:path error:&removeError];
                NSLog(@"[BlackBridgeGallery] Imported %@ removeError=%@", path.lastPathComponent, removeError);
            } else {
                NSLog(@"[BlackBridgeGallery] Import failed %@ error=%@", path.lastPathComponent, error);
            }
        });
    }];
}

static void BBScanInbox(void) {
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:BBInbox withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSString *> *names = [manager contentsOfDirectoryAtPath:BBInbox error:nil] ?: @[];
    NSMutableSet<NSString *> *present = [NSMutableSet set];

    for (NSString *name in names) {
        if ([name hasPrefix:@"."]) continue;
        NSString *extension = name.pathExtension.lowercaseString;
        if (!BBIsSupported(extension)) continue;
        NSString *path = [BBInbox stringByAppendingPathComponent:name];
        [present addObject:path];
        NSDictionary *attributes = [manager attributesOfItemAtPath:path error:nil];
        NSNumber *size = attributes[NSFileSize];
        if (!size || size.unsignedLongLongValue == 0) continue;
        NSNumber *previousSize = BBObservedSizes[path];
        BBObservedSizes[path] = size;
        if (previousSize && [previousSize isEqualToNumber:size]) BBImportFile(path);
    }

    for (NSString *path in BBObservedSizes.allKeys.copy) {
        if (![present containsObject:path] && ![BBImportsInFlight containsObject:path]) {
            [BBObservedSizes removeObjectForKey:path];
        }
    }
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BBObservedSizes = [NSMutableDictionary dictionary];
        BBImportsInFlight = [NSMutableSet set];
        BBTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(BBTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 2 * NSEC_PER_SEC, NSEC_PER_SEC / 4);
        dispatch_source_set_event_handler(BBTimer, ^{ BBScanInbox(); });
        dispatch_resume(BBTimer);
        NSLog(@"[BlackBridgeGallery] Gallery importer started");
    });
}

%end
