//
//  AudioPlayer.m
//  Spatterlight
//
//  Created by Administrator on 2021-01-24.
//

#import "AudioResourceHandler.h"

#include <SDL/SDL.h>
#include <SDL/SDL_mixer.h>

#import "GlkSoundChannel.h"
#import "GlkController.h"

#define SDL_CHANNELS 64
#define MAX_SOUND_RESOURCES 500

@implementation SoundFile : NSObject

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _URL = [NSURL fileURLWithPath:path];
        NSError *theError;
        _bookmark = [_URL bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile
                        includingResourceValuesForKeys:nil
                                         relativeToURL:nil
                                                 error:&theError];
        if (theError || !_bookmark)
            NSLog(@"Error when encoding bookmark: %@", theError);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    _URL =  [decoder decodeObjectOfClass:[NSURL class] forKey:@"URL"];
    _bookmark = [decoder decodeObjectOfClass:[NSData class] forKey:@"bookmark"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_URL forKey:@"URL"];
    [encoder encodeObject:_bookmark forKey:@"bookmark"];
}

- (void)resolveBookmark {
    BOOL bookmarkIsStale = NO;
    NSError *error = nil;
    _URL = [NSURL URLByResolvingBookmarkData:_bookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&bookmarkIsStale error:&error];
    if (bookmarkIsStale) {
        _bookmark = [_URL bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile
                        includingResourceValuesForKeys:nil
                                         relativeToURL:nil
                                                 error:&error];
    }
    if (error) {
        NSLog(@"Soundfile resolveBookmark: %@", error);
    }
}

@end


@implementation SoundResource : NSObject

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (instancetype)initWithFilename:(NSString *)filename  offset:(NSUInteger)offset length:(NSUInteger)length {
    self = [super init];
    if (self) {
        _filename = filename;
        _offset = offset;
        _length = length;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    _filename = [decoder decodeObjectOfClass:[NSString class] forKey:@"filename"];
    _length = (size_t)[decoder decodeIntForKey:@"length"];
    _offset = (size_t)[decoder decodeIntForKey:@"offset"];
    _type = [decoder decodeIntForKey:@"type"];
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_filename forKey:@"filename"];
    [encoder encodeInt:_length forKey:@"length"];
    [encoder encodeInt:_offset forKey:@"offset"];
    [encoder encodeInt:_type forKey:@"type"];
}

-(BOOL)load {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:_soundFile.URL.path];
    if (!fileHandle) {
        [_soundFile resolveBookmark];
        fileHandle = [NSFileHandle fileHandleForReadingAtPath:_soundFile.URL.path];
        if (!fileHandle)
            return NO;
    }
    [fileHandle seekToFileOffset:_offset];
    _data = [fileHandle readDataOfLength:_length];
    if (!_data) {
        NSLog(@"Could not read sound resource from file %@, length %ld, offset %ld\n",_soundFile.URL.path, _length, _offset);
        return NO;
    }

    if (!_type) {
        _type = [self detect_sound_format];
        if (!_type) {
            NSLog(@"Unknown format");
            return NO;
        }
    }

    return YES;
}

- (NSInteger)detect_sound_format
{
    char *buf = (char *)_data.bytes;
    char str[30];
    if (_length > 29)
    {
        strncpy(str, buf, 29);
        str[29]='\0';
    } else {
        strncpy(str, buf, _length);
        str[_length - 1]='\0';
    }
    /* AIFF */
    if (_length > 4 && !memcmp(buf, "FORM", 4))
        return giblorb_ID_FORM;

    /* WAVE */
    if (_length > 4 && !memcmp(buf, "WAVE", 4))
        return giblorb_ID_WAVE;

    if (_length > 4 && !memcmp(buf, "RIFF", 4))
        return giblorb_ID_WAVE;

    /* midi */
    if (_length > 4 && !memcmp(buf, "MThd", 4))
        return giblorb_ID_MIDI;

    /* s3m */
    if (_length > 0x30 && !memcmp(buf + 0x2c, "SCRM", 4))
        return giblorb_ID_MOD;

    /* XM */
    if (_length > 20 && !memcmp(buf, "Extended Module: ", 17))
        return giblorb_ID_MOD;

    /* MOD */
    if (_length > 1084)
    {
        char resname[4];
        memcpy(resname, (buf) + 1080, 4);
        if (!strcmp(resname+1, "CHN") ||        /* 4CHN, 6CHN, 8CHN */
            !strcmp(resname+2, "CN") ||         /* 16CN, 32CN */
            !strcmp(resname, "M.K.") || !strcmp(resname, "M!K!") ||
            !strcmp(resname, "FLT4") || !strcmp(resname, "CD81") ||
            !strcmp(resname, "OKTA") || !strcmp(resname, "    "))
            return giblorb_ID_MOD;
    }

    /* ogg */
    if (_length > 4 && !memcmp(buf, "OggS", 4))
        return giblorb_ID_OGG;

    return giblorb_ID_MP3;
}

@end

@implementation AudioResourceHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _resources = [[NSMutableDictionary alloc] init];
        _sound_channels = [[NSMutableDictionary alloc] init];
        _files = [[NSMutableDictionary alloc] init];
        [self initializeSound];
    }
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    _files = [decoder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"files"];
    _resources = [decoder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"resources"];
    if (_resources)
        for (SoundResource *res in _resources.allValues) {
            res.soundFile = _files[res.filename];
        }
    _restored_music_channel_id = (NSUInteger)[decoder decodeIntForKey:@"music_channel"];
    return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_files forKey:@"files"];
    [encoder encodeObject:_resources forKey:@"resources"];
    [encoder encodeInt:_music_channel.name forKey:@"music_channel"];
}

- (void)initializeSound
{
    if (SDL_Init(SDL_INIT_AUDIO) == -1)
    {
        NSLog(@"SDL init failed\n");
        NSLog(@"%s", SDL_GetError());
        return;
    }
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 4096) == -1)
    {
        NSLog(@"SDL Mixer init failed\n");
        NSLog(@"%s", Mix_GetError());
        return;
    }

    int channels = Mix_AllocateChannels(SDL_CHANNELS);
    Mix_GroupChannels(0, channels - 1 , FREE);
    Mix_ChannelFinished(NULL);
}

-(NSInteger)load_sound_resource:(NSInteger)snd length:(NSUInteger *)len data:(char **)buf {

    kBlorbSoundFormatType type = NONE;
    SoundResource *resource = _resources[@(snd)];

    if (resource)
    {
        if (!resource.data)
        {
            [resource load];
            if (!resource.data)
                return NONE;
        }
        *len = resource.length;
        *buf = (char *)resource.data.bytes;
        type = resource.type;
    }

    return type;
}

- (void)setSoundID:(NSInteger)snd filename:(nullable NSString *)filename length:(NSUInteger)length offset:(NSUInteger)offset {

    SoundResource *res = _resources[@(snd)];

    if (res == nil)
    {
        res = [[SoundResource alloc] initWithFilename:filename  offset:offset length:length];
        _resources[@(snd)] = res;
    }
    else if (res.data)
    {
        return;
    }

    res.length = length;

    if (filename != nil)
    {
        res.soundFile = _files[filename];
        if (!res.soundFile) {
            res.soundFile = [[SoundFile alloc] initWithPath:filename];
            _files[filename] = res.soundFile;
        }
    } else return;
    res.offset = offset;
    [res load];
}

- (BOOL)soundIsLoaded:(NSInteger)soundId {
    SoundResource *resource = _resources[@(soundId)];
    if (resource)
        return (resource.data != nil);
    return NO;
}

- (void)stopAllAndCleanUp:(NSArray *)channels {
    if (!channels.count)
        return;
    Mix_ChannelFinished(NULL);
    Mix_HookMusicFinished(NULL);
    for (GlkSoundChannel* chan in channels) {
        [chan stop];
    }
    Mix_CloseAudio();
}

@end
