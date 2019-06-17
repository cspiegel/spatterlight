/*
 * GlkController --
 *
 * An NSWindowController that controls the game window,
 * talks with the interpreter process,
 * handles global glk commands,
 * dispatches sound channel and window commands,
 * queues events for sending to the interpreter.
 *
 * TODO: cache resources (in raw format) so findimage/findsound
 *       will succeed for more than just the last one uploaded.
 */

#import <QuartzCore/QuartzCore.h>

#import "Compatibility.h"
#import "main.h"

#define MAXWIN 64
#define MAXSND 32

@interface GlkHelperView : NSView {
    IBOutlet GlkController *delegate;
}
@end

@interface GlkController : NSWindowController {
    /* for talking to the interpreter */
    NSTask *task;
    NSFileHandle *readfh;
    NSFileHandle *sendfh;

    /* current state of the protocol */
    NSTimer *timer;
    NSTimer *soundNotificationsTimer;
    BOOL waitforevent;    /* terp wants an event */
    BOOL waitforfilename; /* terp wants a filename from a file dialog */
    BOOL dead;            /* le roi est mort! vive le roi! */
    NSDictionary *lastArrangeValues;
    NSRect lastContentResize;

    BOOL inFullScreenResize;

    BOOL windowRestoredBySystem;
    BOOL shouldRestoreUI;
    BOOL shouldShowAutorestoreAlert;

    NSSize borderFullScreenSize;
    NSWindow *snapshotWindow;

    /* the glk objects */
    // GlkSoundChannel *gchannels[MAXSND];
    BOOL windowdirty; /* the contentView needs to repaint */

    /* image/sound resource uploading protocol */
    NSInteger lastimageresno;
    NSInteger lastsoundresno;
    NSImage *lastimage;
    NSData *lastsound;

    /* stylehints need to be copied to new windows, so we keep the values around
     */
    NSInteger styleuse[2][style_NUMSTYLES][stylehint_NUMHINTS];
    NSInteger styleval[2][style_NUMSTYLES][stylehint_NUMHINTS];

    /* keep some info around for the about-box and resetting*/
    NSString *gamefile;
    NSString *gameifid;
    NSString *terpname;

    NSDictionary *gameinfo;

    GlkController *restoredController;
    NSUInteger turns;
    NSMutableData *bufferedData;
}

@property NSMutableDictionary *gwindows;
@property IBOutlet NSView *borderView;
@property IBOutlet GlkHelperView *contentView;

@property(getter=isAlive, readonly) BOOL alive;

@property(readonly) NSTimeInterval storedTimerLeft;
@property(readonly) NSTimeInterval storedTimerInterval;
@property(readonly) NSRect storedWindowFrame;
@property(readonly) NSRect storedContentFrame;
@property(readonly) NSRect storedBorderFrame;

@property(readonly) NSRect windowPreFullscreenFrame;

@property NSInteger firstResponderView;

@property NSMutableArray *queue;

@property(nonatomic) NSString *appSupportDir;
@property(nonatomic) NSString *autosaveFileGUI;
@property(nonatomic) NSString *autosaveFileTerp;

@property(readonly) BOOL supportsAutorestore;
@property(readonly) BOOL inFullscreen;

- (void)runTerp:(NSString *)terpname
   withGameFile:(NSString *)gamefilename
           IFID:(NSString *)gameifid
           info:(NSDictionary *)gameinfo
          reset:(BOOL)shouldReset
     winRestore:(BOOL)windowRestoredBySystem;

- (void)deleteAutosaveFilesForGameFile:(NSString *)gamefile
                                withInfo:(NSDictionary *)gameinfo;

- (IBAction)reset:(id)sender;

- (void)queueEvent:(GlkEvent *)gevent;
- (void)contentDidResize:(NSRect)frame;
- (void)markLastSeen;
- (void)performScroll;
- (void)setBorderColor:(NSColor *)color;
- (void)restoreUI;
- (void)autoSaveOnExit;
- (void)storeScrollOffsets;
- (void)restoreScrollOffsets;

@end
