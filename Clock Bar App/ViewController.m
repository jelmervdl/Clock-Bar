#import "ViewController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
@import ServiceManagement;
@import EventKit;

@interface NSImage (TintExtension)

- (NSImage *)tint:(NSColor*)color;

@end

@implementation ViewController

- (void)awakeFromNib {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(activate:)
                                                 name:kEventShowPreferences
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(initEventStore:)
                                                 name:kEventInitEventStore
                                               object:nil];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [[self.view window] setTitle:@"Clock Bar"];
    [[self.view window] center];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    [[self.view window] setTitle:@"Clock Bar"];
}

- (IBAction)activate:(id)sender {
    [[self.view window] makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (IBAction)quitPressed:(id)sender {
    [NSApp terminate:nil];
}

- (void)initEventStore:(NSNotification *)notification {
    _eventStore = [notification.userInfo objectForKey:@"eventStore"];
    [self fetchCalendarsFromEventStore];
}

- (void)fetchCalendarsFromEventStore {
    if (_eventStore == nil)
        return;
    
    NSMutableArray *sources = [NSMutableArray array];
    
    for (EKSource *source in [_eventStore sources]) {
        NSArray *calendars = [[source calendarsForEntityType:EKEntityTypeEvent] allObjects];
        if ([calendars count] > 0) {
            [sources addObject:@{
                @"title": source.title,
                @"calendars": calendars
            }];
        }
    }
    
    _eventSources = sources;
    
    if (_calendarTable) {
        NSOutlineView *calendarTable = _calendarTable;
        [calendarTable reloadData];
        [calendarTable expandItem:nil expandChildren:YES];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return [_eventSources objectAtIndex:(NSUInteger)index];
    } else {
        return [[(NSDictionary*)item objectForKey:@"calendars"] objectAtIndex:(NSUInteger)index];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable id)item {
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[NSDictionary class]];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (_eventSources == nil) {
        return 0;
    } else if (item == nil) {
        return (NSInteger)[_eventSources count];
    } else {
        return (NSInteger)[[(NSDictionary*)item objectForKey:@"calendars"] count];
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if (item == nil)
        return nil;
    
    NSTableCellView *view;
    
    if ([item isKindOfClass:[NSDictionary class]]) {
        view = [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];
        view.textField.stringValue = [(NSDictionary*)item objectForKey:@"title"];
    } else if ([item isKindOfClass:[EKCalendar class]]) {
        NSDictionary<NSString*,NSNumber*> *enabledCalendars = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kPrefCalendars];
        NSNumber *val = enabledCalendars != nil ? enabledCalendars[[(EKCalendar*) item calendarIdentifier]] : nil;
        
        view = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
        NSButton *checkbox = (NSButton*)[view.subviews objectAtIndex:0];
        
        checkbox.title = [(EKCalendar*) item title];
        checkbox.state = val == nil || [val boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        
        NSSize size = NSMakeSize(14,14);
        checkbox.image = [self makeCheckboxImageWithSize:size color:[(EKCalendar*)item color] enabled:NO];
        checkbox.alternateImage = [self makeCheckboxImageWithSize:size color:[(EKCalendar*)item color] enabled:YES];
    }
    
    return view;
}

- (IBAction)calendarToggled:(id)sender {
    NSInteger row = [self.calendarTable rowForView:sender];
    
    if (row < 0)
        return;
    
    id item = [self.calendarTable itemAtRow:row];
    if (![item isKindOfClass:[EKCalendar class]])
        return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary<NSString*,NSNumber*> *calendars = [defaults dictionaryForKey:kPrefCalendars];
    NSMutableDictionary *enabledCalendars = calendars != nil ? [calendars mutableCopy] : [[NSMutableDictionary alloc] init];
    enabledCalendars[[(EKCalendar*)item calendarIdentifier]] = @([(NSButton*)sender state] == NSControlStateValueOn);
    [defaults setObject:enabledCalendars forKey:kPrefCalendars];
}

- (NSImage*) makeCheckboxImageWithSize:(NSSize)size color:(NSColor *)color enabled:(BOOL)enabled {
    NSImage* background = [[NSImage alloc] initWithSize:size];
    [background lockFocus];
    [color set];
    
    // Background
    NSBezierPath* rect = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1, 1, size.width-2, size.height-2) xRadius:2 yRadius:2];
    [rect fill];
    
    // Slightly darker outline around background
    [[color blendedColorWithFraction:0.2 ofColor:[NSColor blackColor]] set];
    [rect setLineWidth:1];
    [rect stroke];
    
    // Checkmark if enabeld (tinted white, TODO needs outline as well?)
    if (enabled) {
        [[[NSImage imageNamed:@"NSMenuOnStateTemplate"] tint:[NSColor whiteColor]]
         drawInRect:NSMakeRect(3, 3, size.width - 5, size.height - 5)];
    }
    
    [background unlockFocus];
    return background;
}

@end

@implementation NSImage (TintExtension)

- (NSImage *)tint:(NSColor*)color {
    NSImage *image = [self copy];
    [image lockFocus];
    [color setFill];
    NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height);
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceAtop);
    [image unlockFocus];
    [image setTemplate:NO];
    return image;
}

@end
