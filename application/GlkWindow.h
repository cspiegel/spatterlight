@class GlkController, GlkHyperlink, Theme;

@interface GlkWindow : NSView {

    NSMutableArray *hyperlinks;
    GlkHyperlink *currentHyperlink;
    NSMutableDictionary *currentTerminators;

    // An array of attribute dictionaries,
    // with style hints applied if use hints
    // option is on for this theme
    NSMutableArray *styles;

    BOOL char_request;
}

@property(readonly) NSInteger name;
@property GlkController *glkctl;

@property NSArray *styleHints;
@property NSMutableDictionary *pendingTerminators;
@property BOOL terminatorsPending;
@property Theme *theme;

- (instancetype)initWithGlkController:(GlkController *)glkctl
                                 name:(NSInteger)name;

- (BOOL)getStyleVal:(NSUInteger)style
               hint:(NSUInteger)hint
              value:(NSInteger *)value;

- (BOOL)wantsFocus;
- (void)grabFocus;
- (void)flushDisplay;
- (void)markLastSeen;
- (void)performScroll;
- (void)makeTransparent;
- (void)setBgColor:(NSInteger)bc;
- (void)clear;
- (void)putString:(NSString *)buf style:(NSUInteger)style;
- (void)moveToColumn:(NSUInteger)x row:(NSUInteger)y;
- (void)initLine:(NSString *)buf;
- (void)initChar;
- (void)cancelChar;
- (NSString *)cancelLine;
- (void)initMouse;
- (void)cancelMouse;
- (void)setHyperlink:(NSUInteger)linkid;
- (void)initHyperlink;
- (void)cancelHyperlink;

- (void)fillRects:(struct fillrect *)rects count:(NSInteger)n;
- (void)drawImage:(NSImage *)buf
             val1:(NSInteger)v1
             val2:(NSInteger)v2
            width:(NSInteger)w
           height:(NSInteger)h;
- (void)flowBreak;
- (void)prefsDidChange;
- (void)terpDidStop;
- (NSArray *)deepCopyOfStyleHintsArray:(NSArray *)array;

- (void)restoreSelection;

@end
