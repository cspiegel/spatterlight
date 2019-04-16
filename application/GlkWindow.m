#import "main.h"

@implementation GlkWindow

- (instancetype) initWithGlkController: (GlkController*)glkctl_ name: (NSInteger)name
{
    self = [super initWithFrame:NSZeroRect];

    if (self)
    {
        _glkctl = glkctl_;
        _name = name;
        bgnd = 0xFFFFFF; // White
        styles = [NSMutableArray arrayWithCapacity:style_NUMSTYLES];
        while (styles.count < style_NUMSTYLES)
            [styles addObject:[[GlkStyle alloc] init]];
        _pendingTerminators = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                               @(NO), @keycode_Func1,
                               @(NO), @keycode_Func2,
                               @(NO), @keycode_Func3,
                               @(NO), @keycode_Func4,
                               @(NO), @keycode_Func5,
                               @(NO), @keycode_Func6,
                               @(NO), @keycode_Func7,
                               @(NO), @keycode_Func8,
                               @(NO), @keycode_Func9,
                               @(NO), @keycode_Func10,
                               @(NO), @keycode_Func11,
                               @(NO), @keycode_Func12,
                               @(NO), @keycode_Escape,
                               nil];
        currentTerminators = _pendingTerminators;
        _terminatorsPending = NO;
    }

    return self;
}

- (instancetype) initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    if (self)
    {
        styles = [decoder decodeObjectForKey:@"styles"];
        _name = [decoder decodeIntegerForKey:@"name"];
        bgnd = [decoder decodeIntegerForKey:@"bgnd"];
        hyperlinks = [decoder decodeObjectForKey:@"hyperlinks"];
        currentHyperlink = [decoder decodeObjectForKey:@"currentHyperlink"];
        currentTerminators = [decoder decodeObjectForKey:@"currentTerminators"];
        _pendingTerminators = [decoder decodeObjectForKey:@"pendingTerminators"];
        _terminatorsPending = [decoder decodeBoolForKey:@"terminatorsPending"];
        char_request = [decoder decodeBoolForKey:@"char_request"];
        _restoredFrame = [decoder decodeRectForKey:@"restoredFrame"];
        _restoredResizingMask = [decoder decodeIntegerForKey:@"autoresizingmask"];
        NSLog(@"Decoded frame %@ for GlkWindow %ld", NSStringFromRect(_restoredFrame), self.name);
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
    [super encodeWithCoder:encoder];

    [encoder encodeInteger:_name forKey:@"name"];
    [encoder encodeInteger:bgnd forKey:@"bgnd"];
    [encoder encodeObject:hyperlinks forKey:@"hyperlinks"];
    [encoder encodeObject:currentHyperlink forKey:@"currentHyperlink"];
    [encoder encodeObject:currentTerminators forKey:@"currentTerminators"];
    [encoder encodeObject:_pendingTerminators forKey:@"pendingTerminators"];
    [encoder encodeBool:_terminatorsPending forKey:@"terminatorsPending"];
    [encoder encodeBool:char_request forKey:@"char_request"];
    [encoder encodeObject:styles forKey:@"styles"];
    [encoder encodeInteger:self.autoresizingMask forKey:@"autoresizingmask"];
    [encoder encodeRect:self.frame forKey:@"restoredFrame"];
}

- (NSString *) sayMask: (NSUInteger)mask {
    NSString *maskToSay = [NSString stringWithFormat:@" %@ | %@", (mask & NSViewWidthSizable)?@"NSViewWidthSizable":@"NSViewMaxXMargin", (mask & NSViewHeightSizable)?@"NSViewHeightSizable":@"NSViewMaxYMargin"];
    return maskToSay;
}

- (void) setStyle: (NSInteger)style windowType: (NSInteger)wintype enable: (NSInteger*)enable value:(NSInteger*)value
{
    [styles removeObjectAtIndex:style];
    [styles insertObject:[[GlkStyle alloc] initWithStyle: style
                                         windowType: wintype
                                             enable: enable
                                                value: value] atIndex:style];
}

- (BOOL) getStyleVal: (NSInteger)style hint: (NSInteger)hint value:(NSInteger *)value
{
    GlkStyle *checkedStyle = [styles objectAtIndex:style];
    if(checkedStyle)
    {
        if ([checkedStyle valueForHint:hint value:value])
            return YES;
    }

    return NO;
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) setFrame: (NSRect)thisframe
{
    NSRect mainframe = self.superview.frame;
    NSInteger hmask, vmask;
    NSInteger rgt = 0;
    NSInteger bot = 0;

    /* set autoresizing for live resize. */
    /* the client should rearrange after it's finished. */
    /* flex the views connected to the right and bottom */
    /* keep the other views fixed in size */
    /* x and y separable */

    CGFloat border = Preferences.border;

    if (fabs(NSMaxX(thisframe) - (NSMaxX(mainframe) - border)) < 2.0)
        rgt = 1;

    if (fabs(NSMaxY(thisframe) - (NSMaxY(mainframe) - border)) < 2.0)
        bot = 1;

    if (rgt)
        hmask = NSViewWidthSizable;
    else
        hmask = NSViewMaxXMargin;

    if (bot)
        vmask = NSViewHeightSizable;
    else
        vmask = NSViewMaxYMargin;

    NSUInteger previousMask = self.autoresizingMask;

    self.autoresizingMask = hmask | vmask;

    if (previousMask != self.autoresizingMask) {
        NSLog(@"Changed autoresizingmask for window %ld from %@ to %@", _name, [self sayMask:previousMask], [self sayMask:self.autoresizingMask]);
        NSLog(@"fabs(NSMaxX(thisframe) - (NSMaxX(mainframe) - border) = %f", fabs(NSMaxX(thisframe) - (NSMaxX(mainframe) - border)));
        NSLog(@"fabs(NSMaxY(thisframe) - (NSMaxY(mainframe) - border)) = %f", fabs(NSMaxY(thisframe) - (NSMaxY(mainframe) - border)));

    }

    super.frame = thisframe;
}

- (void) prefsDidChange
{
    NSInteger i;
    for (i = 0; i < style_NUMSTYLES; i++)
        [[styles objectAtIndex:i] prefsDidChange];
}

- (void) terpDidStop
{
}

- (BOOL) wantsFocus
{
    return NO;
}

- (void) grabFocus
{
    // NSLog(@"grab focus in window %ld", self.name);
    [self.window makeFirstResponder: self];
    NSAccessibilityPostNotification( self, NSAccessibilityFocusedUIElementChangedNotification );
}

- (void) flushDisplay
{
}

- (void) setBgColor: (NSInteger)bc
{
    NSLog(@"set background color in %@ not allowed", [self class]);
}

- (void) fillRects: (struct fillrect *)rects count: (NSInteger)n
{
    NSLog(@"fillrect in %@ not implemented", [self class]);
}

- (void) drawImage: (NSImage*)buf val1: (NSInteger)v1 val2: (NSInteger)v2 width: (NSInteger)w height: (NSInteger)h
{
    NSLog(@"drawimage in %@ not implemented", [self class]);
}

- (void) flowBreak
{
    NSLog(@"flowbreak in %@ not implemented", [self class]);
}

- (void) makeTransparent
{
    NSLog(@"makeTransparent in %@ not implemented", [self class]);
}

- (void) markLastSeen { }
- (void) performScroll { }

- (void) clear
{
    NSLog(@"clear in %@ not implemented", [self class]);
}

- (void) putString:(NSString*)buf style:(NSInteger)style
{
    NSLog(@"print in %@ not implemented", [self class]);
}

- (NSDictionary *) attributesFromStylevalue: (NSInteger)stylevalue
{
    NSInteger style = stylevalue & 0xff;
    NSInteger fg = (stylevalue >> 8) & 0xff;
    NSInteger bg = (stylevalue >> 16) & 0xff;

    if (fg || bg)
    {
        NSMutableDictionary *mutatt = [((GlkStyle *)([styles objectAtIndex:style])).attributes mutableCopy];
        [mutatt setObject:@(stylevalue) forKey:@"GlkStyle"];
        if ([Preferences stylesEnabled])
        {
            if (fg)
                [mutatt setObject:[Preferences foregroundColor: (int)(fg - 1)] forKey:NSForegroundColorAttributeName];
            if (bg)
                [mutatt setObject:[Preferences backgroundColor: (int)(bg - 1)] forKey:NSBackgroundColorAttributeName];
        }
        return (NSDictionary *) mutatt;
    }
    else
    {
        return ((GlkStyle *)([styles objectAtIndex:style])).attributes;
    }
}

- (void) moveToColumn:(NSInteger)x row:(NSInteger)y
{
    NSLog(@"move cursor in %@ not implemented", [self class]);
}

- (void) initLine: (NSString*)buf
{
    NSLog(@"line input in %@ not implemented", [self class]);
}

- (NSString*) cancelLine
{
    return @"";
}

- (void) initChar
{
    NSLog(@"char input in %@ not implemented", [self class]);
}

- (void) cancelChar
{
}

- (void) initMouse
{
    NSLog(@"mouse input in %@ not implemented", [self class]);
}

- (void) cancelMouse
{
}

- (void) setHyperlink: (NSUInteger)linkid;
{
    NSLog(@"hyperlink input in %@ not implemented", [self class]);
}

- (void) initHyperlink
{
    NSLog(@"hyperlink input in %@ not implemented", [self class]);
}

- (void) cancelHyperlink
{
    NSLog(@"hyperlink input in %@ not implemented", [self class]);
}

- (BOOL) hasLineRequest
{
    return NO;
}

#pragma mark -
#pragma mark Windows restoration

+ (NSArray *)restorableStateKeyPaths
{
    return @[ @"name" ];
}

#pragma mark Accessibility

- (BOOL)accessibilityIsIgnored {
	return NO;
}

- (void) restoreSelection {}

@end
