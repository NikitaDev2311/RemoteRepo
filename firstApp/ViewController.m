//
//  ViewController.m
//  firstApp
//
//  Created by Никита on 28.11.17.
//  Copyright © 2017 Никита. All rights reserved.
//

#import "ViewController.h"
#import "PhotoCollectionViewCell.h"
#import <Photos/Photos.h>

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UIScrollViewDelegate, UIGestureRecognizerDelegate, UIAlertViewDelegate>
{
    CGSize itemSizeForPortraitMode;
    CGSize itemSizeForLandscapeMode;
    PHImageRequestOptions *requestOptions;
}
//UI
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) UIScrollView *scrollVieww;
@property (strong, nonatomic) UIScrollView *concretePhotoScrollView;
@property (strong, nonatomic) UIImageView* imageViewForZooming;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *takePhotoButton;
//Gesture
@property (strong, nonatomic) UISwipeGestureRecognizer* swipeDown;
@property (strong, nonatomic) UITapGestureRecognizer* tapToPhoto;


//Data
@property (assign, nonatomic) CGSize imageSize;
@property (assign, nonatomic) CGFloat xPositionOnScrollView;
@property (strong, nonatomic) NSMutableArray* photos;
@property (assign, nonatomic) NSUInteger selectedPhotoIndex;
@property (assign, nonatomic) NSIndexPath* selectedIndexPath;

//Photos framework
@property (strong, nonatomic) PHFetchResult *assetsFetchResults;
@property (strong, nonatomic) PHCachingImageManager *imageManager;
@property (strong, nonatomic) PHAsset *asset;
//@property (retain, nonatomic) UIImagePickerController* imagePickerController;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL* appSettings = [NSURL URLWithString:[UIApplicationOpenSettingsURLString stringByAppendingString:[NSBundle mainBundle].bundleIdentifier]];
    UIAlertAction* confirm = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        if ([[UIApplication sharedApplication] canOpenURL:appSettings]) {
                                                            [[UIApplication sharedApplication] openURL:appSettings options:@{} completionHandler:nil];
                                                        }
                                                    }];
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    if (status == PHAuthorizationStatusAuthorized) {
        self.xPositionOnScrollView = 0.0;
        [self initializeGesture];
        [self initializeImageManager];
        self.photos = [[NSMutableArray alloc] init];
        [self prepareScrollViewForZooming];
        self.collectionView.delegate = self;
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
        [self.collectionView reloadData];
    }
    else if (status == PHAuthorizationStatusNotDetermined) {
        
        // Access has not been determined.
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            
            if (status == PHAuthorizationStatusAuthorized) {
                [self.collectionView reloadData];
            }
            [self showConfirmAlertWithMessage:NSLocalizedString(@"You have denied permission to use the photo library. Go to the settings to change it", nil) title:NSLocalizedString(@"Permission", nil) withConfirmAction:confirm];
        }];
    }
    
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateCollectionViewLayoutWithSize:size];
}

- (void)updateCollectionViewLayoutWithSize:(CGSize)size {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    layout.itemSize = (size.width < size.height) ? itemSizeForPortraitMode : itemSizeForLandscapeMode;
    [layout invalidateLayout];
}

- (void) orientationChanged:(NSNotification *)note
{
    UIDevice * device = note.object;
    switch(device.orientation)
    {
        case UIDeviceOrientationPortrait:
            [self.collectionView.collectionViewLayout invalidateLayout];
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            [self.collectionView.collectionViewLayout invalidateLayout];
            break;
            
        default:
            break;
    };
}


#pragma mark - Assets

- (void)deletePhotoWithAsset:(PHAsset*)asset {
    //__weak typeof(self) weakSelf = self;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest deleteAssets:@[asset]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil)
                                                          message:NSLocalizedString(@"Image was deleted successfully", nil) preferredStyle:UIAlertControllerStyleAlert];
           
            UIAlertAction* action = [UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                       [self.collectionView reloadData];
                                                   }];
            [alert addAction:action];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

- (void)loadingAllImages {
    requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode   = PHImageRequestOptionsResizeModeExact;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    requestOptions.synchronous = YES;
    PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    NSMutableArray* images = [[NSMutableArray alloc] initWithCapacity:[result count]];
    
    __block UIImage *imageForArray;
    for (PHAsset* asset in result) {
        
        [self.imageManager requestImageForAsset:(PHAsset*)asset
                                     targetSize:PHImageManagerMaximumSize
                                    contentMode:PHImageContentModeAspectFill
                                        options:requestOptions
                                  resultHandler:^(UIImage *result, NSDictionary *info) {
                                      imageForArray = result;
                                      [images addObject:imageForArray];
                                  }];
    }
    self.photos = [images copy];
}

- (UIImage*)getPhotoFromLibrary {
    requestOptions = [[PHImageRequestOptions alloc] init];
    
    PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    __block UIImage *imageForArray;
    for (PHAsset* asset in self.assetsFetchResults) {
        [self.imageManager requestImageForAsset:self.asset
                                     targetSize:PHImageManagerMaximumSize
                                    contentMode:PHImageContentModeAspectFill
                                        options:requestOptions
                                  resultHandler:^(UIImage *result, NSDictionary *info) {
                                      imageForArray = result;
                                  }];
    }
    return imageForArray;
}

- (void)takeAPhoto {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:picker animated:NO completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.photos addObject:(UIImage*)info[UIImagePickerControllerOriginalImage]];
}   

#pragma mark - Actions
- (IBAction)deleteButtonPressed:(id)sender {
   
    UIAlertAction* confirm = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self deletePhotoWithAsset:self.asset];
                                                        NSLog(@"Current image was deleted");
                                                        [self closeConcretePhoto];
                                                    }];
    [self showConfirmAlertWithMessage:NSLocalizedString(@"Are you sure want delete this photo?", nil)
                         title:NSLocalizedString(@"Warning", nil) withConfirmAction:confirm];
}

- (IBAction)takePhotoButtonPressed:(id)sender {
    [self takeAPhoto];
}
#pragma mark - Submethods

- (void)showConfirmAlertWithMessage:(NSString*)message title:(NSString*)title withConfirmAction:(UIAlertAction*) confirmAction {
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                       NSLog(@"Current image did not deleted");
                                                   }];
    [alertController addAction:confirmAction];
    [alertController addAction:cancel];
    [self presentViewController:alertController animated:YES completion:nil];
    
}

- (void)initializeImageManager {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    self.assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
    self.imageManager = [[PHCachingImageManager alloc] init];
}

- (void)prepareScrollViewForZooming {
    [self scrollViewSettings];
    [self loadingAllImages];
    [self prepareContentForScrollView];
}

- (void)scrollViewSettings {
    [self.deleteButton setEnabled:NO];
    [self.deleteButton setTintColor: [UIColor clearColor]];
    
    self.concretePhotoScrollView = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.scrollVieww.delegate = self;
    self.scrollVieww.pagingEnabled = YES;
    self.scrollVieww.clipsToBounds = YES;
    self.scrollVieww.canCancelContentTouches = YES;
    self.scrollVieww.delaysContentTouches = NO;
    self.scrollVieww = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.scrollVieww.contentMode = UIViewContentModeScaleAspectFit;
    self.scrollVieww.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)prepareContentForScrollView {
    
    [self.scrollVieww setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:1]];
    [self.scrollVieww setContentSize:CGSizeMake([UIScreen mainScreen].bounds.size.width * [self.photos count], self.scrollVieww.frame.size.height)];
    self.scrollVieww.delegate = self;
    [self.scrollVieww setPagingEnabled:YES];
    [self.scrollVieww setMinimumZoomScale:0.5];
    [self.scrollVieww setMaximumZoomScale:10.0];
    
    self.concretePhotoScrollView.frame = self.scrollVieww.frame;
    self.concretePhotoScrollView.contentSize = CGSizeMake([UIScreen mainScreen].bounds.size.width * [self.photos count], self.scrollVieww.frame.size.height);
    self.concretePhotoScrollView.clipsToBounds = YES;
    self.concretePhotoScrollView.userInteractionEnabled = YES;
    self.concretePhotoScrollView.pagingEnabled = YES;
    
    for (int i=0;i<[self.photos count];i++) {
        self.xPositionOnScrollView = i * self.scrollVieww.frame.size.width;
        self.imageViewForZooming = [[UIImageView alloc] initWithFrame:CGRectMake(self.xPositionOnScrollView, 0, self.scrollVieww.frame.size.width, self.scrollVieww.frame.size.height)];
        [self.imageViewForZooming setImage:[self.photos objectAtIndex:i]];
        [self.imageViewForZooming setClipsToBounds:YES];
        [self.imageViewForZooming setContentMode:UIViewContentModeScaleAspectFit];
        [self.imageViewForZooming setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
        [self.concretePhotoScrollView addSubview:self.imageViewForZooming];
        [self.concretePhotoScrollView addGestureRecognizer:self.swipeDown];
        [self.concretePhotoScrollView addGestureRecognizer:self.tapToPhoto];
    }
    [self.scrollVieww addSubview:self.concretePhotoScrollView];
}


#pragma mark - UICollectionView Delegate & Datasource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.assetsFetchResults count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PhotoCollectionViewCell *cell= (PhotoCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    self.asset = self.assetsFetchResults[indexPath.item];
    cell.imageView.image = [self.photos objectAtIndex:indexPath.row];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedPhotoIndex = indexPath.row;
    self.selectedIndexPath = indexPath;
    PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    self.asset = result[indexPath.item];
    [self openConcretePhoto];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    itemSizeForPortraitMode = CGSizeMake([UIScreen mainScreen].bounds.size.width/6,[UIScreen mainScreen].bounds.size.width/6);
    itemSizeForPortraitMode = CGSizeMake([UIScreen mainScreen].bounds.size.width/8,[UIScreen mainScreen].bounds.size.width/8);
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            return itemSizeForPortraitMode;
            break;
        case UIDeviceOrientationLandscapeLeft:
            return itemSizeForLandscapeMode;
        default:
            return itemSizeForPortraitMode;
            break;
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 5.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 5.0;
}


#pragma mark - Gesture

- (void)initializeGesture {
    self.swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [self.swipeDown setNumberOfTouchesRequired:1];
    [self.swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    
    self.tapToPhoto = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.tapToPhoto setNumberOfTouchesRequired:1];
}

- (void)handleSwipe:(UISwipeGestureRecognizer*)swipe {
    switch (swipe.direction) {
        case UISwipeGestureRecognizerDirectionDown:
            [self closeConcretePhoto];
            break;
            //TEST
        case UISwipeGestureRecognizerDirectionRight:
            NSLog(@"right");
            break;
        case UISwipeGestureRecognizerDirectionLeft:
            NSLog(@"left");
            break;
        default:
            break;
    }
}

- (void)handleTap:(UITapGestureRecognizer*)tap {
    if (self.navigationController.navigationBarHidden) {
        
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    else {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    }
    if (self.deleteButton.enabled) {
        self.takePhotoButton.enabled = NO;
        [self.takePhotoButton setTintColor:[UIColor clearColor]];
    }
    else {
        self.takePhotoButton.enabled = YES;
        [self.takePhotoButton setTintColor:[UIColor darkTextColor]];
    }
}

#pragma mark - ScrollView methods

- (void)openConcretePhoto {
    [self.scrollVieww setHidden:NO];
    [self.imageViewForZooming setHidden:NO];
    [self.deleteButton setEnabled:YES];
    [self.deleteButton setTintColor: [UIColor darkTextColor]];
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.concretePhotoScrollView setContentOffset:CGPointMake(self.view.frame.size.width*self.selectedPhotoIndex, 0.0f) animated:NO];
    [UIView animateWithDuration:0.1
                          delay:0
                        options:0
                     animations:^{
                         [self.view addSubview:self.scrollVieww];
                         self.concretePhotoScrollView.transform = CGAffineTransformMakeScale(0.5, 0.5);
                     }
                     completion:^(BOOL finished){
                         [UIView animateWithDuration:0.3 animations:^{
                             self.concretePhotoScrollView.transform = CGAffineTransformMakeScale(1, 1);
                             
                         }];
                         
                     }];
}



- (void)closeConcretePhoto {
    [self.deleteButton setEnabled:NO];
    [self.deleteButton setTintColor: [UIColor clearColor]];
    CGAffineTransform originalTransform = self.scrollVieww.transform;
    CGAffineTransform scaleTransform = CGAffineTransformScale(originalTransform, 0.05, 0.05);
    CGAffineTransform scaleAndTranslateTransform = CGAffineTransformTranslate(scaleTransform, 0, 0);
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.scrollVieww.transform = scaleAndTranslateTransform;
                     }
                     completion:^(BOOL finished) {
                         self.scrollVieww.transform = CGAffineTransformIdentity;
                         [self.scrollVieww setHidden:YES];
                         
                     }];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}



#pragma mark - ScrollView Delegate
- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollVieww {
    return self.concretePhotoScrollView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    self.concretePhotoScrollView.center = self.scrollVieww.center;
}


- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    self.concretePhotoScrollView.center = self.scrollVieww.center;
    if (scrollView.zoomScale<1) {
        [UIView animateWithDuration:0.05
                              delay:0
                            options:0
                         animations:^{
                             self.concretePhotoScrollView.transform = CGAffineTransformMakeScale(0.5, 0.5);
                         }
                         completion:^(BOOL finished){
                             [UIView animateWithDuration:0.05 animations:^{
                                 self.concretePhotoScrollView.transform = CGAffineTransformMakeScale(1, 1);
                             }];
                         }];
    }
}
#pragma mark - Default
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

