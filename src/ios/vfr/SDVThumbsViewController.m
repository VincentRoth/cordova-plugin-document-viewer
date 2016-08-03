//
//  SDVThumbsViewController.m
//
//  implements Sitewaerts Document Viewer runtime options for VFR Reader
//
//  TableView code from http://www.makemegeek.com/uitableview-example-ios/, http://i5insights.com/?p=832
//
//  Created by Philipp Bohnenstengel on 03.11.14.
//
//

#import "SDVThumbsViewController.h"
#import "SDVThumbsMainToolbar.h"
#import "ThumbsMainToolbar+SDVThumbsMainToolbarPassThrough.h"
#import "ReaderDocument.h"
#import "ReaderDocumentOutline.h"

//protocols for table view
@interface SDVThumbsViewController()<UITableViewDataSource,UITableViewDelegate>

@end

@implementation SDVThumbsViewController

#pragma mark - Constants

#define STATUS_HEIGHT 20.0f

#define TOOLBAR_HEIGHT 44.0f

#define PAGE_THUMB_SMALL 160
#define PAGE_THUMB_LARGE 256

//TODO understand how delegation works and why this works if it is not synthesized although none of the delegation stuff of the superclass is in the public header
//@synthesize delegate;
@synthesize viewerOptions;
@synthesize documentOutline;

- (instancetype)initWithReaderDocument:(ReaderDocument *)object options:(NSMutableDictionary *)options
{
    self = [super initWithReaderDocument:object];
    self.viewerOptions = options;
    self.documentOutline = [SDVThumbsViewController flattenOutline:[ReaderDocumentOutline outlineFromFileURL:object.fileURL password: nil]];
    NSLog(@"[pdfviewer] document-outline: %@", self.documentOutline);

    return self;
}

//  override viewDidLoad
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    assert(self.delegate != nil); assert(document != nil);
    
    self.view.backgroundColor = [UIColor grayColor]; // Neutral gray
    
    CGRect scrollViewRect = self.view.bounds; UIView *fakeStatusBar = nil;
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) // iOS 7+
    {
        if ([self prefersStatusBarHidden] == NO) // Visible status bar
        {
            CGRect statusBarRect = self.view.bounds; // Status bar frame
            statusBarRect.size.height = STATUS_HEIGHT; // Default status height
            fakeStatusBar = [[UIView alloc] initWithFrame:statusBarRect]; // UIView
            fakeStatusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            fakeStatusBar.backgroundColor = [UIColor blackColor];
            fakeStatusBar.contentMode = UIViewContentModeRedraw;
            fakeStatusBar.userInteractionEnabled = NO;
            
            scrollViewRect.origin.y += STATUS_HEIGHT; scrollViewRect.size.height -= STATUS_HEIGHT;
        }
    }
    
    NSString *toolbarTitle = [document.fileName stringByDeletingPathExtension];
    
    CGRect toolbarRect = scrollViewRect; // Toolbar frame
    toolbarRect.size.height = TOOLBAR_HEIGHT; // Default toolbar height
//    mainToolbar = [[ThumbsMainToolbar alloc] initWithFrame:toolbarRect title:toolbarTitle]; // ThumbsMainToolbar
    
    //check if document outline is available
    if (documentOutline.count > 0) {
        NSMutableDictionary *outlineOptions = [ [NSMutableDictionary alloc]
                                               initWithObjectsAndKeys :
                                               [NSNumber numberWithBool:YES], @"enabled",
                                               nil
                                               ];
        [viewerOptions setObject:outlineOptions forKey:@"outline"];
    }
    mainToolbar = [[SDVThumbsMainToolbar alloc] initWithFrame:toolbarRect title:toolbarTitle options: viewerOptions]; // ThumbsMainToolbar
    mainToolbar.delegate = self; // ThumbsMainToolbarDelegate
    [self.view addSubview:mainToolbar];
    
    if (fakeStatusBar != nil) [self.view addSubview:fakeStatusBar]; // Add status bar background view
    
    UIEdgeInsets scrollViewInsets = UIEdgeInsetsZero; // Scroll view toolbar insets
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) // iPad
    {
        scrollViewRect.origin.y += TOOLBAR_HEIGHT; scrollViewRect.size.height -= TOOLBAR_HEIGHT;
    }
    else // Set UIScrollView insets for non-UIUserInterfaceIdiomPad case
    {
        scrollViewInsets.top = TOOLBAR_HEIGHT;
    }
    
    theOutlineView = [[UITableView alloc] initWithFrame:scrollViewRect]; //TableView for Document outline
    theOutlineView.delegate = self;
    theOutlineView.dataSource = self;
    theOutlineView.hidden = NO;
    
    [theOutlineView setAutoresizingMask: UIViewAutoresizingFlexibleWidth];
    
    [self.view insertSubview:theThumbsView belowSubview:mainToolbar];
    [self.view insertSubview:theOutlineView belowSubview:mainToolbar];
    
    BOOL large = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
    CGFloat thumbSize = (large ? PAGE_THUMB_LARGE : PAGE_THUMB_SMALL); // Thumb dimensions
    [theThumbsView setThumbSize:CGSizeMake(thumbSize, thumbSize)]; // Set the thumb size
}

//  UITableView protocol methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [documentOutline count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *documentOutlineItem = @"DocumentOutlineItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:documentOutlineItem];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:documentOutlineItem];
    }
    cell.textLabel.text = [[documentOutline objectAtIndex:indexPath.row] title];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //go to associated page
    //copied and modified from didSelectThumbWithIndex
    DocumentOutlineEntry *outlineEntry = [documentOutline objectAtIndex:indexPath.row];
    
    if ([outlineEntry.target isKindOfClass:[NSDictionary class]])
    {
        // Display new PDF at a specific page
        NSLog(@"Outline target is NSDictionary");
    }
    else if ([outlineEntry.target isKindOfClass:[NSString class]])
    {
        // Display new PDF
        // Notify application to let app give new PDF location
        
    }
    else
    {
        // Show the selected page in current PDF
        [self.delegate thumbsViewController:self gotoPage:[outlineEntry.target integerValue]];
    }
    [self.delegate dismissThumbsViewController:self]; // Dismiss thumbs display
}

- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger retValue=1;
    DocumentOutlineEntry *entry=[documentOutline objectAtIndex:indexPath.row];//Store the indent value in a dictionary in your row or implement appropriate logic
    retValue=[entry level];//return the indent
    NSLog(@"[pdf-viewer] outline indentation: %ld", (long)retValue);
    return retValue;
}

//  recursive flattening of document outline
+ (NSArray *) flattenOutline:(NSArray *)outline
{
    NSMutableArray *flatOutline = [NSMutableArray array];
    for (DocumentOutlineEntry *entry in outline) {
        [flatOutline addObject:entry];
        if (entry.children) {
            [flatOutline addObjectsFromArray:[SDVThumbsViewController flattenOutline:entry.children]];
        }
    }
    return flatOutline;
}

// show status bar
- (BOOL)prefersStatusBarHidden
{
    return NO;
}

@end
