#import "main.h"
#import "NSColor+integer.h"

#ifdef DEBUG
#define NSLog(FORMAT, ...)                                                     \
    fprintf(stderr, "%s\n",                                                    \
            [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...)
#endif

@implementation GlkGraphicsWindow

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (instancetype)initWithGlkController:(GlkController *)glkctl_
                                 name:(NSInteger)name_ {
    self = [super initWithGlkController:glkctl_ name:name_];

    if (self) {
        image = [[NSImage alloc] initWithSize:NSZeroSize];
        bgnd = 0xFFFFFF; // White

        mouse_request = NO;
        transparent = NO;
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        image = [decoder decodeObjectOfClass:[NSImage class] forKey:@"image"];
        dirty = YES;
        mouse_request = [decoder decodeBoolForKey:@"mouse_request"];
        transparent = [decoder decodeBoolForKey:@"transparent"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:image forKey:@"image"];
    [encoder encodeBool:mouse_request forKey:@"mouse_request"];
    [encoder encodeBool:transparent forKey:@"transparent"];
}

- (BOOL)isOpaque {
    return !transparent;
}

- (void)makeTransparent {
    transparent = YES;
    dirty = YES;
}

- (void)setBgColor:(NSInteger)bc {
    bgnd = bc;

    //    NSLog(@"Background in graphics window was set to bgnd(%ld)",
    //    (long)bgnd);

    [self.glkctl setBorderColor:[NSColor colorFromInteger:bgnd] fromWindow:self];
}

- (void)drawRect:(NSRect)rect {
    NSRect bounds = self.bounds;

    if (!transparent) {
        [[NSColor colorFromInteger:bgnd] set];
        NSRectFill(rect);
    }

    [image drawAtPoint:bounds.origin
              fromRect:NSMakeRect(0, 0, bounds.size.width, bounds.size.height)
             operation:NSCompositeSourceOver
              fraction:1.0];
}

- (void)setFrame:(NSRect)frame {

    frame.origin.y = round(frame.origin.y);
    
    if (NSEqualRects(frame, self.frame) && !NSEqualSizes(image.size, NSZeroSize))
        return;

    super.frame = frame;

    if (frame.size.width == 0 || frame.size.height == 0)
        return;

    // First we store the current contents
    NSImage *oldimage = image;

    // Then we create a new image, filling it with background color
    if (!transparent) {

        image = [[NSImage alloc] initWithSize:frame.size];

        [image lockFocus];
        [[NSColor colorFromInteger:bgnd] set];
        NSRectFill(self.bounds);
        [image unlockFocus];
    }

    // The we draw the old contents over it
    [self drawImage:oldimage
               val1:0
               val2:0
              width:(NSInteger)oldimage.size.width
             height:(NSInteger)oldimage.size.height
              style:style_Normal];

    dirty = YES;
}

- (void)fillRects:(struct fillrect *)rects count:(NSInteger)count {
    NSBitmapImageRep *bitmap;
    NSSize size;
    NSInteger x, y;
    NSInteger i;

    size = image.size;

    if (size.width == 0 || size.height == 0 || size.height > INT_MAX)
        return;

    bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:(NSInteger)size.width
                      pixelsHigh:(NSInteger)size.height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:32];

    bitmap.size = size;

    unsigned char *pd = bitmap.bitmapData;
    NSInteger ps = bitmap.bytesPerRow;
    NSInteger pw = bitmap.pixelsWide;
    NSInteger ph = bitmap.pixelsHigh;

    memset(pd, 0x00, ps * ph);

    for (i = 0; i < count; i++) {
        unsigned char ca = 0xff; //((rects[i].color >> 24) & 0xff);
        unsigned char cr = ((rects[i].color >> 16) & 0xff);
        unsigned char cg = ((rects[i].color >> 8) & 0xff);
        unsigned char cb = ((rects[i].color >> 0) & 0xff);

        NSInteger rx0 = rects[i].x;
        NSInteger ry0 = rects[i].y;
        NSInteger rx1 = rx0 + rects[i].w;
        NSInteger ry1 = ry0 + rects[i].h;

        if (ry0 < 0)
            ry0 = 0;
        if (ry1 < 0)
            ry1 = 0;
        if (rx0 < 0)
            rx0 = 0;
        if (rx1 < 0)
            rx1 = 0;

        if (ry0 > ph)
            ry0 = ph;
        if (ry1 > ph)
            ry1 = ph;
        if (rx0 > pw)
            rx0 = pw;
        if (rx1 > pw)
            rx1 = pw;

        for (y = ry0; y < ry1; y++) {
            unsigned char *p = pd + (y * ps) + (rx0 * 4);
            for (x = rx0; x < rx1; x++) {
                *p++ = cr;
                *p++ = cg;
                *p++ = cb;
                *p++ = ca;
            }
        }
    }

    [image lockFocus];
    {
        NSImage *tmp = [[NSImage alloc] initWithSize:size];
        [tmp addRepresentation:bitmap];
        [tmp drawAtPoint:NSZeroPoint
                fromRect:NSMakeRect(0, 0, size.width, size.height)
               operation:NSCompositeSourceOver
                fraction:1.0];
    }
    [image unlockFocus];

    dirty = YES;
}

- (NSRect)florpCoords:(NSRect)r {
    NSRect res = r;
    NSSize size = image.size;
    res.origin.y = size.height - res.origin.y - res.size.height;
    return res;
}

- (void)drawImage:(NSImage *)src
             val1:(NSInteger)x
             val2:(NSInteger)y
            width:(NSInteger)w
           height:(NSInteger)h
            style:(NSUInteger)style {
    NSSize srcsize = src.size;

    if (NSEqualSizes(image.size, NSZeroSize)) {
        return;
    }

    if (w == 0)
        w = (NSInteger)srcsize.width;
    if (h == 0)
        h = (NSInteger)srcsize.height;

    [image lockFocus];

    [NSGraphicsContext currentContext].imageInterpolation =
        NSImageInterpolationHigh;

    [src drawInRect:[self florpCoords:NSMakeRect(x, y, w, h)]
           fromRect:NSMakeRect(0, 0, srcsize.width, srcsize.height)
          operation:NSCompositeSourceOver
           fraction:1.0];

    [image unlockFocus];

    dirty = YES;
}

- (void)initMouse {
    mouse_request = YES;
}

- (void)cancelMouse {
    mouse_request = NO;
}

- (void)mouseDown:(NSEvent *)theEvent {
    if (mouse_request && theEvent.clickCount == 1) {
        [self.glkctl markLastSeen];

        NSPoint p;
        p = theEvent.locationInWindow;
        p = [self convertPoint:p fromView:nil];
        p.y = self.frame.size.height - p.y;
        // NSLog(@"mousedown in gfx at %g,%g", p.x, p.y);
        GlkEvent *gev = [[GlkEvent alloc] initMouseEvent:p forWindow:self.name];
        [self.glkctl queueEvent:gev];
        mouse_request = NO;
    }
}

- (BOOL)wantsFocus {
    return char_request;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)initChar {
    // NSLog(@"init char in %d", name);
    char_request = YES;
}

- (void)cancelChar {
    // NSLog(@"cancel char in %d", name);
    char_request = NO;
}

- (void)keyDown:(NSEvent *)evt {
    NSString *str = evt.characters;
    unsigned ch = keycode_Unknown;
    if (str.length)
        ch = chartokeycode([str characterAtIndex:str.length - 1]);

    GlkWindow *win;
    // pass on this key press to another GlkWindow if we are not expecting one
    if (!self.wantsFocus)
        for (win in [self.glkctl.gwindows allValues]) {
            if (win != self && win.wantsFocus) {
                NSLog(@"GlkGraphicsWindow: Passing on keypress");
                [win keyDown:evt];
                [win grabFocus];
                return;
            }
        }

    if (char_request && ch != keycode_Unknown) {
        [self.glkctl markLastSeen];

        // NSLog(@"char event from %d", name);
        GlkEvent *gev = [[GlkEvent alloc] initCharEvent:ch forWindow:self.name];
        [self.glkctl queueEvent:gev];
        char_request = NO;
        return;
    }
}

#pragma mark Accessibility

- (NSString *)accessibilityRoleDescription {
        return [NSString
            stringWithFormat:@"Graphics window%@%@",
                             mouse_request ? @", waiting for mouse clicks"
                                           : @"",
                             char_request ? @", waiting for a key press" : @""];
}

- (NSArray *)accessibilityCustomActions API_AVAILABLE(macos(10.13)) {
    NSArray *actions = [self.glkctl accessibilityCustomActions];
    return actions;
}

- (BOOL)isAccessibilityElement {
    return YES;
}

@end
