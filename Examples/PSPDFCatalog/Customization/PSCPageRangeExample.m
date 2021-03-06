//
//  PSCPageRangeExample.m
//  PSPDFCatalog
//
//  Copyright (c) 2011-2014 PSPDFKit GmbH. All rights reserved.
//
//  The PSPDFKit Sample applications are licensed with a modified BSD license.
//  Please see License for details. This notice may not be removed from this file.
//

#import "PSCAssetLoader.h"
#import "PSCExample.h"

@interface PSCPageRangeExample : PSCExample @end
@implementation PSCPageRangeExample

- (id)init {
    if (self = [super init]) {
        self.title = @"Limit pages to 5-10 via pageRange";
        self.category = PSCExampleCategoryPageRange;
    }
    return self;
}

- (UIViewController *)invokeWithDelegate:(id<PSCExampleRunnerDelegate>)delegate {
    PSPDFDocument *document = [PSCAssetLoader sampleDocumentWithName:kHackerMagazineExample];
    document.UID = @"PageRangeExampleUID"; // custom so this won't affect other examples.
    document.pageRange = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(4, 5)];
    PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
    controller.rightBarButtonItems = @[controller.annotationButtonItem, controller.viewModeButtonItem];
    controller.thumbnailBarMode = PSPDFThumbnailBarModeScrollable;
    return controller;
}

@end

