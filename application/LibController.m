/*
 *
 */

#import "main.h"

#ifdef DEBUG
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...)
#endif

enum { X_EDITED, X_LIBRARY, X_DATABASE }; // export selections

#define kSource @".source"
#define kDefault 1
#define kInternal 2
#define kExternal 3
#define kUser 4

#include <ctype.h>

/* the treaty of babel headers */
#include "treaty.h"
#include "ifiction.h"
#include "babel_handler.h"

@implementation LibHelperWindow
- (NSUInteger) draggingEntered:sender { return [self.delegate draggingEntered:sender]; }
- (void) draggingExited:sender { [self.delegate draggingEntered:sender]; }
- (BOOL) prepareForDragOperation:sender { return [self.delegate prepareForDragOperation:sender]; }
- (BOOL) performDragOperation:sender { return [self.delegate performDragOperation:sender]; }
@end

@implementation LibHelperTableView

- (void) textDidEndEditing: (NSNotification *) notification
{
    NSDictionary *userInfo;
    NSDictionary *newUserInfo;
    NSNumber *textMovement;
    int movementCode;
    
    userInfo = notification.userInfo;
    textMovement = userInfo[@"NSTextMovement"];
    movementCode = textMovement.intValue;
    
    // see if this a 'pressed-return' instance
    if (movementCode == NSReturnTextMovement)
    {
        // hijack the notification and pass a different textMovement value
        textMovement = @(NSIllegalTextMovement);
        newUserInfo = @{@"NSTextMovement": textMovement};
        notification = [NSNotification notificationWithName: notification.name
                                                     object: notification.object
                                                   userInfo: newUserInfo];
    }
    
    [super textDidEndEditing: notification];
}

@end

@implementation LibController

/*
 * Window controller, menus and file dialogs.
 *
 */

static NSMutableDictionary *load_mutable_plist(NSString *path)
{
    NSMutableDictionary *dict;
    NSString *error;
    
    dict = [[NSPropertyListSerialization
             propertyListFromData: [NSData dataWithContentsOfFile: path]
             mutabilityOption: NSPropertyListMutableContainersAndLeaves
             format: NULL
             errorDescription: &error] retain];
    
    if (!dict)
    {
        NSLog(@"libctl: cannot load plist: %@", error);
        dict = [[NSMutableDictionary alloc] init];
    }
    
    return dict;
}

static BOOL save_plist(NSString *path, NSDictionary *plist)
{
    NSData *plistData;
    NSString *error;
    
    plistData = [NSPropertyListSerialization dataFromPropertyList: plist
                                                           format: NSPropertyListBinaryFormat_v1_0
                                                 errorDescription: &error];
    if (plistData)
    {
        return [plistData writeToFile:path atomically:YES];
    }
    else
    {
        NSLog(@"%@", error);
        [error release];
        return NO;
    }
}

- (void) loadLibrary
{
    NSLog(@"libctl: loadLibrary");
    
    /* in case we are called more than once... */
    [homepath release];
    [gameTableModel release];
    [metadata release];
    [games release];
    
    homepath = [[NSURL fileURLWithPath:(@"~/Library/Application Support/Spatterlight").stringByExpandingTildeInPath  isDirectory:YES]retain];
    [[NSFileManager defaultManager] createDirectoryAtURL:homepath withIntermediateDirectories:YES attributes:NULL error:NULL];
    
    metadata = load_mutable_plist([homepath.path stringByAppendingPathComponent: @"Metadata.plist"]);
    games = load_mutable_plist([homepath.path stringByAppendingPathComponent: @"Games.plist"]);
}

- (IBAction) saveLibrary: (id)sender
{
    NSLog(@"libctl: saveLibrary");
    
    int code;
    
    code = save_plist([homepath.path stringByAppendingPathComponent: @"Metadata.plist"], metadata);
    if (!code)
        NSLog(@"libctl: cannot write metadata!");
    
    code = save_plist([homepath.path stringByAppendingPathComponent: @"Games.plist"], games);
    if (!code)
        NSLog(@"libctl: cannot write game list!");
}

- (void) windowDidLoad
{
    NSLog(@"libctl: windowDidLoad");
    
    self.windowFrameAutosaveName = @"LibraryWindow";
    gameTableView.autosaveName = @"GameTable";
    [gameTableView setAutosaveTableColumns: YES];
    // [gameTableView setDoubleAction: @selector(playGame:)];
    
    [self.window setExcludedFromWindowsMenu: YES];
    [self.window registerForDraggedTypes:
     @[NSFilenamesPboardType]];
    
    [infoButton setEnabled: NO];
    [playButton setEnabled: NO];
    
    gameTableModel = [[NSMutableArray alloc] init];
    gameTableDirty = YES;
    [self updateTableViews];
}

- (IBAction) deleteLibrary: (id)sender
{
    NSInteger choice =
    NSRunAlertPanel(@"Do you really want to delete the library?",
                    @"All the information about your games will be lost. The original game files will not be harmed.",
                    @"Delete", NULL, @"Cancel");
    if (choice != NSAlertOtherReturn)
    {
        [metadata removeAllObjects];
        [games removeAllObjects];
        gameTableDirty = YES;
        [self updateTableViews];
    }
}

- (IBAction) purgeLibrary: (id)sender
{
    NSInteger choice =
    NSRunAlertPanel(@"Do you really want to purge the library?",
                    @"Purging will delete the information about games that are not in the library at the moment.",
                    @"Purge", NULL, @"Cancel");
    if (choice != NSAlertOtherReturn)
    {
        NSEnumerator *enumerator;
        NSString *ifid;
        enumerator = [metadata keyEnumerator];
        while ((ifid = [enumerator nextObject]))
        {
            if (!games[ifid])
            {
                [metadata removeObjectForKey: ifid];
            }
        }
    }
}

- (void) beginImporting
{
    [importProgressPanel makeKeyAndOrderFront: self];
}

- (void) endImporting
{
    [importProgressPanel orderOut: self];
}


- (IBAction) importMetadata: (id)sender
{
    NSOpenPanel *panel = [[NSOpenPanel openPanel] retain];
    panel.prompt = @"Import";
    
    panel.allowedFileTypes = @[@"iFiction"];
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL* url = panel.URL;
            
            [self beginImporting];
            [self importMetadataFromFile: url.path];
            [self updateTableViews];
            [self endImporting];
        }
        
    }];
}

- (IBAction) exportMetadata: (id)sender
{
    NSSavePanel *panel = [[NSSavePanel savePanel] retain];
    panel.accessoryView = exportTypeView;
    panel.allowedFileTypes=@[@"iFiction"];
    panel.prompt = @"Export";
    panel.nameFieldStringValue = @"Interactive Fiction Metadata.iFiction";
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL* url = panel.URL;
            
            [self exportMetadataToFile: url.path what: exportTypeControl.indexOfSelectedItem];
            [panel release];
        }
    }];
}

- (IBAction) addGamesToLibrary: (id)sender
{
    NSOpenPanel *panel = [[NSOpenPanel openPanel] retain];
    [panel setAllowsMultipleSelection: YES];
    [panel setCanChooseDirectories: YES];
    panel.prompt = @"Add";
    
    panel.allowedFileTypes=gGameFileTypes;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSArray* urls = panel.URLs;
            
            [self beginImporting];
            [self addFiles: urls];
            [self endImporting];
        }
    }];
}


- (IBAction) playGame: (id)sender
{
    NSInteger rowidx = gameTableView.selectedRow;
    if (rowidx >= 0)
    {
        NSString *ifid = gameTableModel[rowidx];
        [self playGameWithIFID: ifid];
    }
}

- (IBAction) showGameInfo: (id)sender
{
    NSIndexSet *rows = gameTableView.selectedRowIndexes;
    NSInteger i;
    for (i = rows.firstIndex; i != NSNotFound; i = [rows indexGreaterThanIndex: i])
    {
        NSString *ifid = gameTableModel[i];
        NSString *path = games[ifid];
        NSDictionary *info = metadata[ifid];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath: path])
        {
            NSRunAlertPanel(@"Cannot find the file.",
                            @"The file could not be found at its original location. Maybe it has been moved since it was added to the library.",
                            @"Okay", NULL, NULL);
            return;
        }
        
        showInfoForFile(path, info);
    }
}

- (IBAction) revealGameInFinder: (id)sender
{
    NSIndexSet *rows = gameTableView.selectedRowIndexes;
    NSInteger i;
    for (i = rows.firstIndex; i != NSNotFound; i = [rows indexGreaterThanIndex: i])
    {
        NSString *ifid = gameTableModel[i];
        NSString *path = games[ifid];
        [[NSWorkspace sharedWorkspace] selectFile: path inFileViewerRootedAtPath: @""];
    }
}

- (IBAction) deleteGame: (id)sender
{
    NSIndexSet *rows = gameTableView.selectedRowIndexes;
    if (rows.count > 0)
    {
        NSString *ifid;
        NSInteger i;
        
        for (i = rows.firstIndex; i != NSNotFound; i = [rows indexGreaterThanIndex: i])
        {
            ifid = gameTableModel[i];
            NSLog(@"libctl: delete game %@", ifid);
            [games removeObjectForKey: ifid];
        }
        
        gameTableDirty = YES;
        [self updateTableViews];
    }
}

- (IBAction) delete: (id)sender
{
    [self deleteGame: sender];
}

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
    SEL action = menuItem.action;
    NSInteger count = gameTableView.numberOfSelectedRows;
    
    if (action == @selector(delete:))
        return count > 0;
    
    if (action == @selector(deleteGame:))
        return count > 0;
    
    if (action == @selector(revealGameInFinder:))
        return count > 0;
    
    if (action == @selector(showGameInfo:))
        return count > 0;
    
    if (action == @selector(playGame:))
        return count == 1;
    
    return YES;
}

/*
 * Drag-n-drop destination handler
 */

- (unsigned int) draggingEntered:sender
{
    extern NSString *terp_for_filename(NSString *path);
    
    NSFileManager *mgr = [NSFileManager defaultManager];
    BOOL isdir;
    NSInteger i;
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard.types containsObject: NSFilenamesPboardType])
    {
        NSArray *paths = [pboard propertyListForType: NSFilenamesPboardType];
        NSInteger count = paths.count;
        for (i = 0; i < count; i++)
        {
            NSString *path = paths[i];
            if ([gGameFileTypes containsObject: path.pathExtension.lowercaseString])
                return NSDragOperationCopy;
            if ([path.pathExtension isEqualToString: @"iFiction"])
                return NSDragOperationCopy;
            if ([mgr fileExistsAtPath: path isDirectory: &isdir])
                if (isdir)
                    return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}

- (void) draggingExited:sender
{
    // unhighlight window
}

- (BOOL) prepareForDragOperation:sender
{
    return YES;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard.types containsObject: NSFilenamesPboardType])
    {
        NSArray *files = [pboard propertyListForType: NSFilenamesPboardType];
        [self beginImporting];
        [self addFiles: files];
        [self endImporting];
        return YES;
    }
    return NO;
}


/*
 * Metadata is not tied to games in the library.
 * We keep it around even if the games come and go.
 * Metadata that has been edited by the user is flagged,
 * and can be exported.
 */

- (void) addMetadata: (NSMutableDictionary*)dict forIFIDs: (NSArray*)list
{
    NSInteger count = list.count;
    NSInteger i;
    
    if (cursrc == 0)
        NSLog(@"libctl: current metadata source failed...");
    
    for (i = 0; i < count; i++)
    {
        NSString *ifid = list[i];
        NSDictionary *entry = metadata[ifid];
        if (entry)
        {
            NSNumber *oldsrcv = entry[kSource];
            int oldsrc = oldsrcv.intValue;
            if (cursrc >= oldsrc)
            {
                dict[kSource] = @((int)cursrc);
                metadata[ifid] = dict;
                gameTableDirty = YES;
            }
        }
        else
        {
            dict[kSource] = @((int)cursrc);
            metadata[ifid] = dict;
            gameTableDirty = YES;
        }
    }
}

- (void) setMetadataValue: (NSString*)val forKey: (NSString*)key forIFID: (NSString*)ifid
{
    NSMutableDictionary *dict = metadata[ifid];
    if (dict)
    {
        NSLog(@"libctl: user set value %@ = '%@' for %@", key, val, ifid);
        dict[kSource] = @kUser;
        dict[key] = val;
        gameTableDirty = YES;
    }
}

static void read_xml_text(const char *rp, char *wp)
{
    /* kill initial whitespace */
    while (*rp && isspace(*rp))
        rp++;
    
    while (*rp)
    {
        if (*rp == '<')
        {
            if (strstr(rp, "<br/>") == rp || strstr(rp, "<br />") == rp)
            {
                *wp++ = '\n';
                *wp++ = '\n';
                rp += 5;
                if (*rp == '>')
                    rp ++;
                
                /* kill trailing whitespace */
                while (*rp && isspace(*rp))
                    rp++;
            }
            else
            {
                *wp++ = *rp++;
            }
        }
        else if (*rp == '&')
        {
            if (strstr(rp, "&lt;") == rp)
            {
                *wp++ = '<';
                rp += 4;
            }
            else if (strstr(rp, "&gt;") == rp)
            {
                *wp++ = '>';
                rp += 4;
            }
            else if (strstr(rp, "&amp;") == rp)
            {
                *wp++ = '&';
                rp += 5;
            }
            else
            {
                *wp++ = *rp++;
            }
        }
        else if (isspace(*rp))
        {
            *wp++ = ' ';
            while (*rp && isspace(*rp))
                rp++;
        }
        else
        {
            *wp++ = *rp++;
        }
    }
    
    *wp = 0;
}

- (void) handleXMLCloseTag: (struct XMLTag *)tag
{
    char bigbuf[4096];
    
    /* we don't parse tags after bibliographic until the next story begins... */
    if (!strcmp(tag->tag, "bibliographic"))
    {
        NSLog(@"libctl: import metadata for %@ by %@", metabuf[@"title"], metabuf[@"author"]);
        [self addMetadata: metabuf forIFIDs: ifidbuf];
        [ifidbuf release];
        [metabuf release];
        ifidbuf = nil;
        metabuf = nil;
    }
    
    /* we should only find ifid:s inside the <identification> tag, */
    /* which should be the first tag in a <story> */
    else if (!strcmp(tag->tag, "ifid"))
    {
        if (!ifidbuf)
        {
            ifidbuf = [[NSMutableArray alloc] initWithCapacity: 1];
            metabuf = [[NSMutableDictionary alloc] initWithCapacity: 10];
        }
        char save = *tag->end;
        *tag->end = 0;
        [ifidbuf addObject: @(tag->begin)];
        *tag->end = save;
    }
    
    /* only extract text from within the indentification and bibliographic tags */
    else if (metabuf)
    {
        if (tag->end - tag->begin >= sizeof(bigbuf) - 1)
            return;
        
        char save = *tag->end;
        *tag->end = 0;
        read_xml_text(tag->begin, bigbuf);
        *tag->end = save;
        
        NSString *val = @(bigbuf);
        
        if (!strcmp(tag->tag, "format"))
            metabuf[@"format"] = val;
        if (!strcmp(tag->tag, "bafn"))
            metabuf[@"bafn"] = val;
        if (!strcmp(tag->tag, "title"))
            metabuf[@"title"] = val;
        if (!strcmp(tag->tag, "author"))
            metabuf[@"author"] = val;
        if (!strcmp(tag->tag, "language"))
            metabuf[@"language"] = val;
        if (!strcmp(tag->tag, "headline"))
            metabuf[@"headline"] = val;
        if (!strcmp(tag->tag, "firstpublished"))
            metabuf[@"firstpublished"] = val;
        if (!strcmp(tag->tag, "genre"))
            metabuf[@"genre"] = val;
        if (!strcmp(tag->tag, "group"))
            metabuf[@"group"] = val;
        if (!strcmp(tag->tag, "description"))
            metabuf[@"description"] = val;
        if (!strcmp(tag->tag, "series"))
            metabuf[@"series"] = val;
        if (!strcmp(tag->tag, "seriesnumber"))
            metabuf[@"seriesnumber"] = val;
        if (!strcmp(tag->tag, "forgiveness"))
            metabuf[@"forgiveness"] = val;
    }
}

- (void) handleXMLError: (char*)msg
{
    if (strstr(msg, "Error:"))
        NSLog(@"libctl: xml: %s", msg);
}

static void handleXMLCloseTag(struct XMLTag *tag, void *ctx)
{
    [(LibController*)ctx handleXMLCloseTag: tag];
}

static void handleXMLError(char *msg, void *ctx)
{
    [(LibController*)ctx handleXMLError: msg];
}

- (void) importMetadataFromXML: (char*)mdbuf
{
    ifiction_parse(mdbuf, handleXMLCloseTag, self, handleXMLError, self);
    if (ifidbuf) [self->ifidbuf release];
    if (metabuf) [self->metabuf release];
    ifidbuf = nil;
    metabuf = nil;
}

- (BOOL) importMetadataFromFile: (NSString*)filename
{
    NSLog(@"libctl: importMetadataFromFile %@", filename);
    
    NSMutableData *data;
    
    data = [NSMutableData dataWithContentsOfFile: filename];
    if (!data)
        return NO;
    [data appendBytes: "\0" length: 1];
    
    cursrc = kExternal;
    [self importMetadataFromXML: data.mutableBytes];
    cursrc = 0;
    
    return YES;
}

static void write_xml_text(FILE *fp, NSDictionary *info, NSString *key)
{
    NSString *val;
    const char *tagname;
    const char *s;
    
    val = info[key];
    if (!val)
        return;
    
    tagname = key.UTF8String;
    s = val.UTF8String;
    
    fprintf(fp, "<%s>", tagname);
    while (*s)
    {
        if (*s == '&')
            fprintf(fp, "&amp;");
        else if (*s == '<')
            fprintf(fp, "&lt;");
        else if (*s == '>')
            fprintf(fp, "&gt;");
        else if (*s == '\n')
        {
            fprintf(fp, "<br/>");
            while (s[1] == '\n')
                s++;
        }
        else
        {
            putc(*s, fp);
        }
        s++;
    }
    fprintf(fp, "</%s>\n", tagname);
}

/*
 * Export user-edited metadata (ie, with kSource == kUser)
 */
- (BOOL) exportMetadataToFile: (NSString*)filename what: (NSInteger)what
{
    NSEnumerator *enumerator;
    NSString *ifid;
    //NSString *key, *val;
    NSDictionary *info;
    int src;
    
    NSLog(@"libctl: exportMetadataToFile %@", filename);
    
    FILE *fp;
    
    fp = fopen(filename.UTF8String, "w");
    if (!fp)
        return NO;
    
    fprintf(fp, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    fprintf(fp, "<ifindex version=\"1.0\">\n\n");
    
    if (what == X_EDITED || what == X_DATABASE)
        enumerator = [metadata keyEnumerator];
    else
        enumerator = [games keyEnumerator];
    while ((ifid = [enumerator nextObject]))
    {
        info = metadata[ifid];
        src = [info[kSource] intValue];
        if ((what == X_EDITED && src >= kUser) || what != X_EDITED)
        {
            fprintf(fp, "<story>\n");
            
            fprintf(fp, "<identification>\n");
            fprintf(fp, "<ifid>%s</ifid>\n", ifid.UTF8String);
            write_xml_text(fp, info, @"format");
            write_xml_text(fp, info, @"bafn");
            fprintf(fp, "</identification>\n");
            
            fprintf(fp, "<bibliographic>\n");
            
            write_xml_text(fp, info, @"title");
            write_xml_text(fp, info, @"author");
            write_xml_text(fp, info, @"language");
            write_xml_text(fp, info, @"headline");
            write_xml_text(fp, info, @"firstpublished");
            write_xml_text(fp, info, @"genre");
            write_xml_text(fp, info, @"group");
            write_xml_text(fp, info, @"series");
            write_xml_text(fp, info, @"seriesnumber");
            write_xml_text(fp, info, @"forgiveness");
            write_xml_text(fp, info, @"description");
            
            fprintf(fp, "</bibliographic>\n");
            fprintf(fp, "</story>\n\n");
        }
    }
    
    fprintf(fp, "</ifindex>\n");
    
    fclose(fp);
    return YES;
}


/*
 * The list of games is kept separate from metadata.
 * We save them as dictionaries mapping IFIDs to filenames.
 */

- (void) playGameWithIFID: (NSString*)ifid
{
    GlkController *gctl;
    NSDictionary *info = metadata[ifid];
    NSString *path = games[ifid];
    NSString *terp;
    
    NSLog(@"playgame %@ %@", ifid, info);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
    {
        NSRunAlertPanel(@"Cannot find the file.",
                        @"The file could not be found at its original location. Maybe it has been moved since it was added to the library.",
                        @"Okay", NULL, NULL);
        return;
    }
    
    if (![[NSFileManager defaultManager] isReadableFileAtPath: path])
    {
        NSRunAlertPanel(@"Cannot read the file.",
                        @"The file exists but can not be read.",
                        @"Okay", NULL, NULL);
        return;
    }
    
    terp = gExtMap[path.pathExtension];
    if (!terp)
        terp = gFormatMap[info[@"format"]];
    
    if (!terp)
    {
        NSRunAlertPanel(@"Cannot play the file.",
                        @"The game is not in a recognized file format; cannot find a suitable interpreter.",
                        @"Okay", NULL, NULL);
        return;
    }
    
    gctl = [[GlkController alloc] initWithWindowNibName: @"GameWindow"];
    [gctl runTerp:terp withGameFile:path IFID:ifid info:info];
    [gctl showWindow: self];
    
    // gctl releases itself when the game closes
}

- (void) importAndPlayGame: (NSString*)path
{
    NSEnumerator *enumerator;
    NSString *ifid;
    
    enumerator = [games keyEnumerator];
    while ((ifid = [enumerator nextObject]))
    {
        if ([games[ifid] isEqualToString: path])
        {
            [self playGameWithIFID: ifid];
            return;
        }
    }
    
    ifid = [self importGame: path reportFailure: YES];
    if (ifid)
    {
        [self updateTableViews];
        [self deselectGames];
        [self selectGameWithIFID: ifid];
        [self playGameWithIFID: ifid];
    }
}

- (NSString*) importGame: (NSString*)path reportFailure: (BOOL)report
{
    char buf[TREATY_MINIMUM_EXTENT];
    NSMutableDictionary *dict;
    NSString *ifid;
    char *format;
    char *s;
    int mdlen;
    int rv;
    
    if ([path.pathExtension.lowercaseString isEqualToString: @"ifiction"])
    {
        [self importMetadataFromFile: path];
        return nil;
    }
    
    if ([path.pathExtension.lowercaseString isEqualToString: @"d$$"])
    {
        path = [self convertAGTFile: path];
        if (!path)
        {
            if (report)
                NSRunAlertPanel(@"Conversion failed.",
                                @"This old style AGT file could not be converted to the new AGX format.",
                                @"Okay", NULL, NULL);
            return nil;
        }
    }
    
    if (![gGameFileTypes containsObject: path.pathExtension.lowercaseString])
    {
        if (report)
            NSRunAlertPanel(@"Unknown file format.",
                            @"Can not recognize the file extension.",
                            @"Okay", NULL, NULL);
        return nil;
    }
    
    format = babel_init((char*)path.UTF8String);
    if (!format || !babel_get_authoritative())
    {
        if (report)
            NSRunAlertPanel(@"Unknown file format.",
                            @"Babel can not identify the file format.",
                            @"Okay", NULL, NULL);
        babel_release();
        return nil;
    }
    
    s = strchr(format, ' ');
    if (s) format = s+1;
    
    rv = babel_treaty(GET_STORY_FILE_IFID_SEL, buf, sizeof buf);
    if (rv <= 0)
    {
        if (report)
            NSRunAlertPanel(@"Fatal error.",
                            @"Can not compute IFID from the file.",
                            @"Okay", NULL, NULL);
        babel_release();
        return nil;
    }
    
    s = strchr(buf, ',');
    if (s) *s = 0;
    ifid = @(buf);
    
    NSLog(@"libctl: import game %@ (%s)", path, format);
    
    mdlen = babel_treaty(GET_STORY_FILE_METADATA_EXTENT_SEL, NULL, 0);
    if (mdlen > 0)
    {
        char *mdbuf = malloc(mdlen);
        if (!mdbuf)
        {
            if (report)
                NSRunAlertPanel(@"Out of memory.",
                                @"Can not allocate memory for the metadata text.",
                                @"Okay", NULL, NULL);
            babel_release();
            return nil;
        }
        
        rv = babel_treaty(GET_STORY_FILE_METADATA_SEL, mdbuf, mdlen);
        if (rv > 0)
        {
            cursrc = kInternal;
            [self importMetadataFromXML: mdbuf];
            cursrc = 0;
        }
        
        free(mdbuf);
    }
    
    dict = metadata[ifid];
    if (!dict)
    {
        dict = [NSMutableDictionary dictionary];
        cursrc = kDefault;
        [self addMetadata: dict forIFIDs: @[ifid]];
        cursrc = 0;
    }
    
    if (!dict[@"format"])
        dict[@"format"] = @(format);
    if (!dict[@"title"])
        dict[@"title"] = path.lastPathComponent;
    
    babel_release();
    
    games[ifid] = path;
    gameTableDirty = YES;
    
    return ifid;
}

- (void) addFile: (NSString*)path select: (NSMutableArray*)select
{
    NSString *ifid = [self importGame: path reportFailure: NO];
    if (ifid)
        [select addObject: ifid];
}

- (void) addFiles: (NSArray*)paths select: (NSMutableArray*)select root: (NSString*)root
{
    NSFileManager *filemgr = [NSFileManager defaultManager];
    BOOL isdir;
    NSInteger count;
    NSInteger i;
    
    count = paths.count;
    for (i = 0; i < count; i++)
    {
        NSString *path = [root stringByAppendingPathComponent: [paths[i] path]];
        
        if (![filemgr fileExistsAtPath: path isDirectory: &isdir])
            continue;
        
        if (isdir)
        {
            NSArray *contents = [filemgr contentsOfDirectoryAtPath: path error:nil];
            [self addFiles: contents select: select root: path];
        }
        else
        {
            [self addFile: path select: select];
        }
    }
}

- (void) addFiles: (NSArray*)paths
{
    NSInteger count;
    NSInteger i;
    
    NSLog(@"libctl: adding %lu files", (unsigned long)[paths count]);
    
    NSMutableArray *select = [NSMutableArray arrayWithCapacity: paths.count];
    
    [self deselectGames];
    
    [self addFiles: paths select: select root: @""];
    
    [self updateTableViews];
    
    count = select.count;
    for (i = 0; i < count; i++)
        [self selectGameWithIFID: select[i]];
}

- (void) addFile: (NSString*)path
{
    [self addFiles: @[path]];
}

/*
 * Table magic
 */

- (IBAction) searchForGames: (id)sender
{
    NSString *value = [sender stringValue];
    [searchStrings release];
    searchStrings = nil;
    
    if (value.length)
        searchStrings = [[value componentsSeparatedByString: @" "] retain];
    
    gameTableDirty = YES;
    [self updateTableViews];
}

- (void) deselectGames
{
    [gameTableView deselectAll: self];
}

- (void) selectGameWithIFID: (NSString*)ifid
{
    NSInteger i, count;
    count = gameTableModel.count;
    for (i = 0; i < count; i++)
        if ([gameTableModel[i] isEqualToString: ifid])
            [gameTableView selectRow: i byExtendingSelection: YES];
}

static NSInteger Strstr(NSString *haystack, NSString *needle)
{
    if (haystack)
        return [haystack rangeOfString: needle options: NSCaseInsensitiveSearch].length;
    return 0;
}

static NSInteger Strcmp(NSString *a, NSString *b)
{
    if ([a hasPrefix: @"The "] || [a hasPrefix: @"the "])
        a = [a substringFromIndex: 4];
    if ([b hasPrefix: @"The "] || [b hasPrefix: @"the "])
        b = [b substringFromIndex: 4];
    return [a caseInsensitiveCompare: b];
}

static NSInteger compareDicts(NSDictionary * a, NSDictionary * b, id key)
{
    NSString * ael = [a[key] description];
    NSString * bel = [b[key] description];
    if ((!ael || ael.length == 0) && (!bel || bel.length == 0))
        return 0;
    if (!ael || ael.length == 0) return 1;
    if (!bel || bel.length == 0) return -1;
    return Strcmp(ael, bel);
}

static NSInteger compareGames(NSString *aid, NSString *bid, void *ctx)
{
    LibController *self = ctx;
    NSDictionary *a = self->metadata[aid];
    NSDictionary *b = self->metadata[bid];
    NSInteger cmp;
    if (self->gameSortColumn)
    {
        cmp = compareDicts(a, b, self->gameSortColumn);
        if (cmp) return cmp;
    }
    cmp = compareDicts(a, b, @"title");
    if (cmp) return cmp;
    cmp = compareDicts(a, b, @"author");
    if (cmp) return cmp;
    cmp = compareDicts(a, b, @"seriesnumber");
    if (cmp) return cmp;
    cmp = compareDicts(a, b, @"firstpublished");
    if (cmp) return cmp;
    return compareDicts(a, b, @"format");
}

- (void) updateTableViews
{
    NSEnumerator *enumerator;
    NSMutableDictionary *meta;
    NSString *selifid;
    NSString *needle;
    NSString *ifid;
    NSInteger searchcount;
    NSInteger selrow;
    NSInteger count;
    NSInteger found;
    NSInteger i;
    
    if (!gameTableDirty)
        return;
    
    selifid = nil;
    selrow = gameTableView.selectedRow;
    if (selrow >= 0)
        selifid = gameTableModel[selrow];
    
    [gameTableModel removeAllObjects];
    
    if (searchStrings)
        searchcount = searchStrings.count;
    else
        searchcount = 0;
    
    enumerator = [games keyEnumerator];
    while ((ifid = [enumerator nextObject]))
    {
        meta = metadata[ifid];
        if (searchcount > 0)
        {
            count = 0;
            for (i = 0; i < searchcount; i++)
            {
                found = NO;
                needle = searchStrings[i];
                if (Strstr(meta[@"format"], needle)) found++;
                if (Strstr(meta[@"title"], needle)) found++;
                if (Strstr(meta[@"author"], needle)) found++;
                if (Strstr(meta[@"firstpublished"], needle)) found++;
                if (Strstr(meta[@"group"], needle)) found++;
                if (Strstr(meta[@"genre"], needle)) found++;
                if (Strstr(meta[@"series"], needle)) found++;
                if (Strstr(meta[@"forgiveness"], needle)) found++;
                if (Strstr(meta[@"language"], needle)) found++;
                if (found)
                    count ++;
            }
            if (count == searchcount)
                [gameTableModel addObject: ifid];
        }
        else
        {
            [gameTableModel addObject: ifid];
        }
    }
    
    [gameTableModel sortUsingFunction: compareGames context: self];
    [gameTableView reloadData];
    
    [gameTableView deselectAll: self];
    count = gameTableModel.count;
    for (i = 0; i < count; i++)
        if (gameTableModel[i] == selifid)
            [gameTableView selectRow: i byExtendingSelection: NO];
    
    gameTableDirty = NO;
}

- (void) tableView: (NSTableView*)tableView
didClickTableColumn: (NSTableColumn*)tableColumn
{
    if (tableView == gameTableView)
    {
        [gameSortColumn release];
        gameSortColumn = [tableColumn.identifier retain];
        gameTableView.highlightedTableColumn = tableColumn;
        gameTableDirty = YES;
        [self updateTableViews];
    }
}
- (NSInteger) numberOfRowsInTableView: (NSTableView*)tableView
{
    if (tableView == gameTableView)
        return gameTableModel.count;
    return 0;
}

- (id) tableView: (NSTableView*)tableView
objectValueForTableColumn: (NSTableColumn*)column
             row: (int)row
{
    if (tableView == gameTableView)
    {
        NSString *gameifid = gameTableModel[row];
        NSDictionary *gamemeta = metadata[gameifid];
        return gamemeta[column.identifier];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)value
   forTableColumn:(NSTableColumn *)tableColumn
              row:(int)row
{
    if (tableView == gameTableView)
    {
        NSString *ifid = gameTableModel[row];
        NSDictionary *info = metadata[ifid];
        NSString *key = tableColumn.identifier;
        NSString *oldval = info[key];
        if (oldval == nil && ((NSString*)value).length == 0)
            return;
        if ([value isEqualTo: oldval])
            return;
        [self setMetadataValue: value forKey: key forIFID: ifid];
    }
}

- (void) tableViewSelectionDidChange: (id)notification
{
    NSTableView *tableView = [notification object];
    NSIndexSet *rows = tableView.selectedRowIndexes;
    if (tableView == gameTableView)
    {
        infoButton.enabled = rows.count > 0;
        playButton.enabled = rows.count == 1;
    }
}

/*
 * Some stuff that doesn't really fit anywhere else.
 */

- (NSString*) convertAGTFile: (NSString*)origpath
{
    NSLog(@"libctl: converting agt to agx");
    char rapeme[] = "/tmp/cugelcvtout.agx"; /* babel will clobber this, so we can't send a const string */
    
    NSString *exepath = [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"agt2agx"];
    NSString *dirpath;
    NSString *cvtpath;
    NSTask *task;
    char *format;
    int status;
    
    task = [[NSTask alloc] init];
    task.launchPath = exepath;
    task.arguments = @[@"-o", @"/tmp/cugelcvtout.agx", origpath];
    [task launch];
    [task waitUntilExit];
    status = task.terminationStatus;
    [task release];
    
    if (status != 0)
    {
        NSLog(@"libctl: agt2agx failed");
        return nil;
    }
    
    format = babel_init(rapeme);
    if (!strcmp(format, "agt"))
    {
        char buf[TREATY_MINIMUM_EXTENT];
        int rv = babel_treaty(GET_STORY_FILE_IFID_SEL, buf, sizeof buf);
        if (rv == 1)
        {
            dirpath = [homepath.path stringByAppendingPathComponent: @"Converted"];
            
            [[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:dirpath isDirectory:YES] withIntermediateDirectories:YES attributes:nil error:NULL];
            
            cvtpath =
            [dirpath stringByAppendingPathComponent:
             [@(buf)
              stringByAppendingPathExtension: @"agx"]];
            
            babel_release();
            
            NSURL *url = [NSURL fileURLWithPath:cvtpath];
            
            [[NSFileManager defaultManager]  removeItemAtURL: url error: nil];
            
            status = [[NSFileManager defaultManager] moveItemAtPath: @"/tmp/cugelcvtout.agx"
                                                             toPath: cvtpath
                                                              error: nil];
            
            if (!status)
            {
                NSLog(@"libctl: could not move converted file");
                return nil;
            }
            return cvtpath;
        }
    }
    else
    {
        NSLog(@"libctl: babel did not like the converted file");
    }
    babel_release();
    
    return nil;
}

@end
