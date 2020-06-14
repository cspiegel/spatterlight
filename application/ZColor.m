//
//  ZColor.m
//  Spatterlight
//
//  Created by Petter Sjölund on 2020-04-29.
//
//

#import "ZColor.h"

@implementation ZColor

- (instancetype)initWithText:(NSInteger)fg background:(NSInteger)bg {
    self = [super init];
    if (self) {
        _fg = fg;
        _bg = bg;
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    _fg = [decoder decodeIntegerForKey:@"fg"];
    _bg = [decoder decodeIntegerForKey:@"bg"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInteger:_fg forKey:@"fg"];
    [encoder encodeInteger:_bg forKey:@"bg"];
}

- (NSMutableDictionary *)coloredAttributes:(NSMutableDictionary *)dict {
    if (_fg >= 0) {
        dict[NSForegroundColorAttributeName] = [self colorFromInteger:_fg];
    }
//    else {
//        [dict removeObjectForKey:NSForegroundColorAttributeName];
//    }
    if (_bg >= 0) {
        dict[NSBackgroundColorAttributeName] = [self colorFromInteger:_bg];
    }
//    else {
//        [dict removeObjectForKey:NSBackgroundColorAttributeName];
//    }
    return dict;
}

- (NSMutableDictionary *)reversedAttributes:(NSMutableDictionary *)dict {
    if (_fg >= 0) {
        dict[NSBackgroundColorAttributeName] = [self colorFromInteger:_fg];
    } 
    if (_bg >= 0) {
        dict[NSForegroundColorAttributeName] = [self colorFromInteger:_bg];
    }
    return dict;
}

- (NSColor *)colorFromInteger:(NSInteger)value {
    NSInteger r,g,b;
    r = (value >> 16) & 0xff;
    g = (value >> 8) & 0xff;
    b = (value >> 0) & 0xff;
    return [NSColor colorWithCalibratedRed:r / 255.0
                                      green:g / 255.0
                                       blue:b / 255.0
                                      alpha:1.0];

}

- (NSString *)colorDescription:(NSInteger)value {
    NSInteger r,g,b;
    r = (value >> 16) & 0xff;
    g = (value >> 8) & 0xff;
    b = (value >> 0) & 0xff;

    if (r > 250 && g > 250 && b > 250)
        return @"white";

    if (r < 2 && g < 2 && b < 2)
        return @"black";

    if (value == -1)
        return @"zcolor_Default";
    if (value == -2)
        return @"zcolor_Current";

    return [NSString stringWithFormat:@"0x%lx", (long)value];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"fg: %@ bg: %@", [self colorDescription:_fg], [self colorDescription:_bg]];
}

@end
