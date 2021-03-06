//
//  PSCKioskPDFViewController.m
//  PSPDFCatalog
//
//  Copyright (c) 2011-2014 PSPDFKit GmbH. All rights reserved.
//
//  The PSPDFKit Sample applications are licensed with a modified BSD license.
//  Please see License for details. This notice may not be removed from this file.
//

#import "PSCKioskPDFViewController.h"
#import "PSCMagazine.h"
#import "PSCSettingsController.h"
#import "PSCGridViewController.h"
#import "PSCSettingsBarButtonItem.h"
#import "PSCAvailability.h"

#ifdef PSPDFCatalog
#import "PSCGoToPageButtonItem.h"
#import "PSCMetadataBarButtonItem.h"
#endif

#if !__has_feature(objc_arc)
#error "Compile this file with ARC"
#endif

@interface PSCKioskPDFViewController () {
    UIBarButtonItem *_closeButtonItem;
    PSCSettingsBarButtonItem *_settingsButtonItem;
#ifdef PSPDFCatalog
    PSCMetadataBarButtonItem *_metadataButtonItem;
#endif
}
@end

@implementation PSCKioskPDFViewController

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)document {
    if ((self = [super initWithDocument:document])) {
        self.delegate = self;

        // Initially update vars.
        [self globalVarChanged];

        // Register for global var change notifications from PSPDFCacheSettingsController.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(globalVarChanged) name:PSCSettingsChangedNotification object:nil];

        // Restore viewState.
        if ([self.document isKindOfClass:PSCMagazine.class]) {
            [self setViewState:((PSCMagazine *)self.document).lastViewState];
        }

        self.leftBarButtonItems = @[_closeButtonItem];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (PSCMagazine *)magazine {
    return (PSCMagazine *)self.document;
}

- (void)close:(id)sender {
    // If parent is PSCGridController, we have a custom animation in place.
    BOOL animated = YES;
    NSUInteger controllerCount = self.navigationController.viewControllers.count;
    if (controllerCount > 1 && [self.navigationController.viewControllers[controllerCount-2] isKindOfClass:[PSCGridViewController class]]) {
        animated = NO;
    }
    // Support the case where we pop in the nav stack
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:animated];
    }else {
        // We might have opened a linked document modally.
        [self.navigationController dismissViewControllerAnimated:YES completion:NULL];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // Save current viewState.
    if ([self.document isKindOfClass:PSCMagazine.class]) {
        ((PSCMagazine *)self.document).lastViewState = self.viewState;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewController

#ifdef PSPDFCatalog
- (void)updateSettingsForRotation:(UIInterfaceOrientation)toInterfaceOrientation force:(BOOL)force {
    // Dynamically adapt toolbar (in landscape mode, we have a lot more space!)
    NSArray *leftToolbarItems = PSCIsIPad() && UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? @[_closeButtonItem, _settingsButtonItem, _metadataButtonItem] : @[_closeButtonItem, _settingsButtonItem];

    // Simple performance optimization.
    if (leftToolbarItems.count != self.leftBarButtonItems.count || force) {
        self.leftBarButtonItems = leftToolbarItems;
    }
}

- (void)updateSettingsForRotation:(UIInterfaceOrientation)toInterfaceOrientation {
    [super updateSettingsForRotation:toInterfaceOrientation];
    [self updateSettingsForRotation:toInterfaceOrientation force:NO];
}
#endif

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

// This is to present the most common features of PSPDFKit.
// iOS is all about choosing the right options for the user. You really shouldn't ship that.
- (void)globalVarChanged {
    // Preserve viewState, but only page, not contentOffset. (since we can change fitToWidth etc here)
    PSPDFViewState *viewState = [self viewState];
    viewState.zoomScale = 1.f;
    viewState.contentOffset = CGPointMake(0.f, 0.f);

    NSMutableDictionary *renderOptions = [NSMutableDictionary dictionaryWithDictionary:self.document.renderOptions];
    NSDictionary *settings = [PSCSettingsController settings];
    [settings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        // renderOptions need special treatment.
        if ([key isEqual:@"renderBackgroundColor"])     renderOptions[PSPDFRenderBackgroundFillColor] = obj;
        else if ([key isEqual:@"renderContentOpacity"]) renderOptions[PSPDFRenderContentOpacity] = obj;
        else if ([key isEqual:@"renderInvertEnabled"])  renderOptions[PSPDFRenderInverted] = obj;

        else if (![key hasSuffix:@"ButtonItem"] && ![key hasPrefix:@"showTextBlocks"]) {
            [self setValue:obj forKey:[PSCSettingsController setterKeyForGetter:key]];
        }
    }];
    self.document.renderOptions = renderOptions;

    // Defaults to nil, this would show the back arrow (but we want a custom animation, thus our own button)
    NSString *closeTitle = PSCIsIPad() ? NSLocalizedString(@"Documents", @"") : NSLocalizedString(@"Back", @"");
    _closeButtonItem = [[UIBarButtonItem alloc] initWithTitle:closeTitle style:UIBarButtonItemStyleBordered target:self action:@selector(close:)];
    _settingsButtonItem = [[PSCSettingsBarButtonItem alloc] initWithPDFViewController:self];

#ifdef PSPDFCatalog
    _metadataButtonItem = [[PSCMetadataBarButtonItem alloc] initWithPDFViewController:self];
    [self updateSettingsForRotation:self.interfaceOrientation force:YES];
#endif

    self.barButtonItemsAlwaysEnabled = @[_closeButtonItem];

    NSMutableArray *rightBarButtonItems = [NSMutableArray array];
    if ([settings[PROPERTY(annotationButtonItem)] boolValue]) {
        [rightBarButtonItems addObject:self.annotationButtonItem];
    }
    if (PSCIsIPad()) {
        if ([settings[PROPERTY(bookmarkButtonItem)] boolValue]) {
            [rightBarButtonItems addObject:self.bookmarkButtonItem];
        }
        if ([settings[PROPERTY(outlineButtonItem)] boolValue]) {
            [rightBarButtonItems addObject:self.outlineButtonItem];
        }
        if ([settings[PROPERTY(searchButtonItem)] boolValue]) {
            [rightBarButtonItems addObject:self.searchButtonItem];
        }
    }

    if ([settings[PROPERTY(additionalActionsButtonItem)] boolValue]) {
        [rightBarButtonItems addObject:self.additionalActionsButtonItem];
    }
    if ([settings[PROPERTY(brightnessButtonItem)] boolValue]) {
        [rightBarButtonItems addObject:self.brightnessButtonItem];
    }
    if ([settings[PROPERTY(activityButtonItem)] boolValue]) {
        [rightBarButtonItems addObject:self.activityButtonItem];
    }
    if ([settings[PROPERTY(viewModeButtonItem)] boolValue]) {
        [rightBarButtonItems addObject:self.viewModeButtonItem];
    }
    self.rightBarButtonItems = rightBarButtonItems;

    // Define additional buttons with an action icon.
    NSMutableArray *additionalRightBarButtonItems = [NSMutableArray array];
    NSMutableArray *activities = [NSMutableArray arrayWithObject:PSPDFActivityTypeGoToPage];
    if ([settings[PROPERTY(additionalActionsButtonItem)] boolValue] || [settings[PROPERTY(activityButtonItem)] boolValue]) {
        if ([settings[PROPERTY(printButtonItem)] boolValue]) {
            [additionalRightBarButtonItems addObject:self.printButtonItem];
            // default activity
        }
        if ([settings[PROPERTY(openInButtonItem)] boolValue]) {
            [additionalRightBarButtonItems addObject:self.openInButtonItem];
            [activities addObject:PSPDFActivityTypeOpenIn];
        }
        if ([settings[PROPERTY(emailButtonItem)] boolValue]) {
            [additionalRightBarButtonItems addObject:self.emailButtonItem];
            // default activity
        }
    }

    if (!PSCIsIPad()) {
        if ([settings[PROPERTY(outlineButtonItem)] boolValue]) {
            [additionalRightBarButtonItems addObject:self.outlineButtonItem];
            [activities addObject:PSPDFActivityTypeOutline];
        }
        if ([settings[PROPERTY(searchButtonItem)] boolValue]) {
            [additionalRightBarButtonItems addObject:self.searchButtonItem];
            [activities addObject:PSPDFActivityTypeSearch];
        }
        if ([settings[PROPERTY(bookmarkButtonItem)] boolValue]) {
            [additionalRightBarButtonItems addObject:self.bookmarkButtonItem];
            [activities addObject:PSPDFActivityTypeBookmarks];
        }
    }

#ifdef PSPDFEnableAllBarButtonItems
    [rightBarButtonItems addObjectsFromArray:additionalRightBarButtonItems];
    self.rightBarButtonItems = rightBarButtonItems;
#endif

#ifdef PSPDFCatalog
    [additionalRightBarButtonItems addObject:[[PSCGoToPageButtonItem alloc] initWithPDFViewController:self]];

    if (![settings[PROPERTY(activityButtonItem)] boolValue]) {
        self.additionalBarButtonItems = additionalRightBarButtonItems;
    }else {
        self.activityButtonItem.applicationActivities = activities;
    }
#endif

    // reload scroll view and restore viewState
    [self reloadData];
    [self setViewState:viewState animated:NO];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewControllerDelegate

- (void)pdfViewControllerWillDismiss:(PSPDFViewController *)pdfController {
    //NSLog(@"Controller is about to be dismissed.");
}

- (void)pdfViewControllerDidDismiss:(PSPDFViewController *)pdfController {
    //NSLog(@"Controller has been dismissed.");
}

// Allow control if a page should be scrolled to.
- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldScrollToPage:(NSUInteger)page {
    return YES;
}

static NSString *PSCStripPDFFileType(NSString *pdfFileName) {
    return [pdfFileName stringByReplacingOccurrencesOfString:@".pdf" withString:@"" options:NSCaseInsensitiveSearch|NSBackwardsSearch range:NSMakeRange(0, pdfFileName.length)];
}

// Time to adjust PSPDFViewController before a PSPDFDocument is displayed.
- (void)pdfViewController:(PSPDFViewController *)pdfController didChangeDocument:(PSPDFDocument *)document {
    pdfController.backgroundColor = PSCDefaultBackgroundColor();

    // show pdf title and fileURL
    if (document) {
        NSString *fileName = PSCStripPDFFileType(document.fileURL.lastPathComponent);
        if (PSCIsIPad() && ![document.title isEqualToString:fileName]) {
            self.title = [NSString stringWithFormat:@"%@ (%@)", document.title, document.fileURL.lastPathComponent];
        }
    }
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnAnnotation:(PSPDFAnnotation *)annotation annotationPoint:(CGPoint)annotationPoint annotationView:(UIView<PSPDFAnnotationViewProtocol> *)annotationView pageView:(PSPDFPageView *)pageView viewPoint:(CGPoint)viewPoint {
    PSCLog(@"didTapOnAnnotation:%@ annotationPoint:%@ annotationView:%@ pageView:%@ viewPoint:%@", annotation, NSStringFromCGPoint(annotationPoint), annotationView, pageView, NSStringFromCGPoint(viewPoint));
    BOOL handled = NO;
    return handled;
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnPageView:(PSPDFPageView *)pageView atPoint:(CGPoint)viewPoint {
    CGPoint screenPoint = [self.view convertPoint:viewPoint fromView:pageView];
    CGPoint pdfPoint = [pageView convertViewPointToPDFPoint:viewPoint];
    PSCLog(@"Page %tu tapped at %@ screenPoint:%@ PDFPoint%@ zoomScale:%.1f.", pageView.page, NSStringFromCGPoint(viewPoint), NSStringFromCGPoint(screenPoint), NSStringFromCGPoint(pdfPoint), pageView.scrollView.zoomScale);

    return NO; // touch not used.
}

static NSString *PSCGestureStateToString(UIGestureRecognizerState state) {
    NSString *label = @"";
    switch (state) {
        case UIGestureRecognizerStateBegan:     label = @"Began"; break;
        case UIGestureRecognizerStateChanged:   label = @"Changed"; break;
        case UIGestureRecognizerStateEnded:     label = @"Ended"; break;
        case UIGestureRecognizerStateCancelled: label = @"Cancelled"; break;
        case UIGestureRecognizerStateFailed:    label = @"Failed"; break;
        case UIGestureRecognizerStatePossible:  label = @"Possible"; break;
    }
    return label;
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didLongPressOnPageView:(PSPDFPageView *)pageView atPoint:(CGPoint)viewPoint gestureRecognizer:(UILongPressGestureRecognizer *)gestureRecognizer {
    // Only show log on start, prevents excessive log statements.
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint screenPoint = [self.view convertPoint:viewPoint fromView:pageView];
        CGPoint pdfPoint = [pageView convertViewPointToPDFPoint:viewPoint];
        PSCLog(@"Page %tu long pressed at %@ screenPoint:%@ PDFPoint%@ zoomScale:%.1f. (state: %@)", pageView.page, NSStringFromCGPoint(viewPoint), NSStringFromCGPoint(screenPoint), NSStringFromCGPoint(pdfPoint), pageView.scrollView.zoomScale, PSCGestureStateToString(gestureRecognizer.state));
    }
    return NO; // Touch not used.
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didShowPageView:(PSPDFPageView *)pageView {
    //PSCLog(@"page %d displayed. (document: %@)", pageView.page, pageView.document.title);
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didRenderPageView:(PSPDFPageView *)pageView {
    //PSCLog(@"Page %d rendered. (document: %@)", pageView.page, pageView.document.title);
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didLoadPageView:(PSPDFPageView *)pageView {
    if ([[PSCSettingsController settings][@"showTextBlocks"] boolValue]) {
        NSArray *visiblePageViews = [self.visiblePageViews copy];
        if ([[PSCSettingsController settings][@"showTextBlocks"] boolValue]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                for (PSPDFPageView *visiblePageView in visiblePageViews) {
                    [self.document textParserForPage:visiblePageView.page];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (PSPDFPageView *visiblePageView in visiblePageViews) {
                        [visiblePageView.selectionView showTextFlowData:YES animated:NO];
                    }
                });
            });
        }else {
            for (PSPDFPageView *visiblePageView in visiblePageViews) {
                [visiblePageView.selectionView showTextFlowData:NO animated:NO];
            }
        }
    }
}

// Helper that allows to get the correct subclass out of various containers.
static id PSCControllerForClass(id theController, Class klass) {
    if ([theController isKindOfClass:klass]) {
        return theController;
    }else if ([theController isKindOfClass:UINavigationController.class]) {
        return PSCControllerForClass(((UINavigationController *)theController).topViewController, klass);
    }else if ([theController isKindOfClass:PSPDFContainerViewController.class]) {
        for (UIViewController *contained in ((PSPDFContainerViewController *)theController).viewControllers) {
            if (PSCControllerForClass(contained, klass)) return PSCControllerForClass(contained, klass);
        }
    }
    return nil;
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldShowController:(id<PSPDFPresentableViewController>)controller embeddedInController:(id<PSPDFHostableViewController>)hostController options:(NSDictionary *)options animated:(BOOL)animated {
    PSCLog(@"shouldShowViewController: %@ embeddedIn:%@ animated: %d.", controller, controller, animated);

    // Example how to customize the PSPDFAnnotationTableViewController.
    PSPDFAnnotationTableViewController *annotCtrl = PSCControllerForClass(controller, PSPDFAnnotationTableViewController.class);
    annotCtrl.showDeleteAllOption = YES;

    return YES;
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didShowController:(id<PSPDFPresentableViewController>)controller embeddedInController:(id<PSPDFHostableViewController>)hostController options:(NSDictionary *)options animated:(BOOL)animated {
    PSCLog(@"didShowViewController: %@ embeddedIn:%@ animated: %d.", controller, hostController, animated);
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didEndPageDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
//    CGPoint targetOffsetPoint = targetContentOffset ? *targetContentOffset : CGPointZero;
//    PSCLog(@"didEndPageDraggingwillDecelerate:%@ velocity:%@ targetContentOffset:%@.", decelerate ? @"YES" : @"NO", NSStringFromCGPoint(velocity), NSStringFromCGPoint(targetOffsetPoint));
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didEndPageZooming:(UIScrollView *)scrollView atScale:(CGFloat)scale {
    PSCLog(@"didEndPageDraggingAtScale: %f", scale);
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldSelectText:(NSString *)text withGlyphs:(NSArray *)glyphs atRect:(CGRect)rect onPageView:(PSPDFPageView *)pageView {
    // Example how to limit text selection.
    // return [text length] > 10;
    return YES;
}

- (NSArray *)pdfViewController:(PSPDFViewController *)pdfController shouldShowMenuItems:(NSArray *)menuItems atSuggestedTargetRect:(CGRect)rect forSelectedText:(NSString *)selectedText inRect:(CGRect)textRect onPageView:(PSPDFPageView *)pageView {
    // This is an example how to customize the text selection menu.
    // It helps for debugging text extraction issues. Don't ship this feature.
    NSMutableArray *newMenuItems = [menuItems mutableCopy];
    if (PSCIsIPad()) { // looks bad on iPhone, no space
        PSPDFMenuItem *menuItem = [[PSPDFMenuItem alloc] initWithTitle:@"Show Text" block:^{
            [[[UIAlertView alloc] initWithTitle:@"Custom Show Text Feature" message:selectedText delegate:nil cancelButtonTitle:PSPDFLocalize(@"Ok") otherButtonTitles:nil] show];
        } identifier:@"Show Text"];
        [newMenuItems addObject:menuItem];
    }
    return newMenuItems;
}

// Annotations

/// Called before an annotation will be selected. (but after didTapOnAnnotation)
- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldSelectAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {
    PSCLog(@"should select %@?", annotation);
    return YES;
}

/// Called after an annotation has been selected.
- (void)pdfViewController:(PSPDFViewController *)pdfController didSelectAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {
    PSCLog(@"did select %@.", annotation);
}

/// Called before we're showing the menu for an annotation.
- (NSArray *)pdfViewController:(PSPDFViewController *)pdfController shouldShowMenuItems:(NSArray *)menuItems atSuggestedTargetRect:(CGRect)rect forAnnotations:(NSArray *)annotations inRect:(CGRect)textRect onPageView:(PSPDFPageView *)pageView {
    //PSCLog(@"showing menu %@ for %@", menuItems, annotation);

    // Print highlight contents
    for (PSPDFAnnotation *annotation in annotations) {
        if ([annotation isKindOfClass:PSPDFHighlightAnnotation.class]) {
            NSString *highlightedString = [(PSPDFHighlightAnnotation *)annotation highlightedString];
            PSCLog(@"Highlighted value: %@", highlightedString);
        }
    }

    // Example how to rename menu items.
    //for (PSPDFMenuItem *menuItem in menuItems) {
    //    menuItem.title = @"Test";
    //}

    return menuItems;
}

// Text Selection

- (void)pdfViewController:(PSPDFViewController *)pdfController didSelectText:(NSString *)text withGlyphs:(NSArray *)glyphs atRect:(CGRect)rect onPageView:(PSPDFPageView *)pageView {
    //NSLog(@"Selected: %@", text);
}

UIColor *PSCDefaultBackgroundColor(void) {
    return [UIColor colorWithWhite:0.12f alpha:1.f];
}

@end
