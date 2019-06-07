@class MarginImage;
@class GlkTextBufferWindow;

// I suppose this is necessary to get rid of that ugly Markup menu on attached
// images.

@interface MyAttachmentCell : NSTextAttachmentCell {
    NSInteger align;
    NSInteger pos;
}

@property NSAttributedString *attrstr;

- (instancetype)initImageCell:(NSImage *)image
                 andAlignment:(NSInteger)analignment
                    andAttStr:(NSAttributedString *)anattrstr
                           at:(NSInteger)apos;

//@property (readonly) BOOL wantsToTrackMouse;

@end

@interface MyTextView : NSTextView <NSTextFinderClient> {
    NSTextFinder *_textFinder;
}

- (void)superKeyDown:(NSEvent *)evt;
- (void)temporarilyHideCaret;
- (void)resetTextFinder; // Call after changing the text storage, or search will
                         // break.

@property BOOL shouldDrawCaret;
@property NSRect restoredFrame;
@property CGFloat bottomPadding;
@property(weak, readonly) NSTextFinder *textFinder;

@property BOOL shouldSpeak_10_7;
@property NSRange rangeToSpeak_10_7;

@end

/*
 * Extend NSTextContainer to have images in the margins with
 * the text flowing around them.
 */

@interface MarginContainer : NSTextContainer {
    NSMutableArray *margins;
    NSMutableArray *flowbreaks;
}

- (id)initWithContainerSize:(NSSize)size;
- (void)clearImages;
- (void)addImage:(NSImage *)image
           align:(NSInteger)align
              at:(NSInteger)top
          linkid:(NSUInteger)linkid;
- (void)drawRect:(NSRect)rect;
- (void)invalidateLayout;
- (void)unoverlap:(MarginImage *)image;
- (BOOL)hasMarginImages;
- (NSMutableAttributedString *)marginsToAttachmentsInString:
    (NSMutableAttributedString *)string;
- (NSUInteger)findHyperlinkAt:(NSPoint)p;

@end

/*
 * TextBuffer window controller
 */

#define HISTORYLEN 100

@interface GlkTextBufferWindow
    : GlkWindow <NSTextViewDelegate, NSTextStorageDelegate> {
    NSScrollView *scrollview;
    NSLayoutManager *layoutmanager;
    MarginContainer *container;
    MyTextView *textview;
    NSTextStorage *textstorage;

    BOOL line_request;
    BOOL hyper_request;

    BOOL echo_toggle_pending; /* if YES, line echo behavior will be inverted,
                                 starting from the next line event*/
    BOOL echo; /* if NO, line input text will be deleted when entered */

    NSInteger fence; /* for input line editing */

    NSString *history[HISTORYLEN];
    NSInteger historypos;
    NSInteger historyfirst, historypresent;

    NSMutableArray *moveRanges;
    NSInteger moveRangeIndex;

    CGFloat lastLineheight;

    /* for temporarily storing scroll position */
    NSUInteger lastVisible; 
    CGFloat lastScrollOffset;
    BOOL lastAtBottom;
}

@property(readonly) NSInteger lastchar; /* for smart formatting */
@property(readonly) NSInteger lastseen; /* for more paging */

/* For autorestoring scroll position */
@property NSUInteger restoredLastVisible;
@property CGFloat restoredScrollOffset;
@property BOOL restoredAtBottom;

@property NSRange restoredSelection;
@property NSString *restoredSearch;
@property BOOL restoredFindBarVisible;

- (void)recalcBackground;
- (void)onKeyDown:(NSEvent *)evt;
- (void)echo:(BOOL)val;
- (BOOL)myMouseDown:(NSEvent *)theEvent;
- (void)stopSpeakingText_10_7;
- (void)scrollToCharacter:(NSUInteger)character withOffset:(CGFloat)offset;
- (void)scrollToBottom;
- (BOOL)scrolledToBottom;
- (void)storeScrollOffset;
- (void)restoreScroll;
- (void)restoreTextFinder;
- (void)restoreScrollBarStyle;

- (IBAction)speakMostRecent:(id)sender;
- (IBAction)speakPrevious:(id)sender;
- (IBAction)speakNext:(id)sender;
- (IBAction)speakStatus:(id)sender;

@end
