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
#import "AppDelegate.h"
#import <DGActivityIndicatorView.h>

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UIScrollViewDelegate, UIGestureRecognizerDelegate, UIAlertViewDelegate>
{
    CGSize itemSizeForPortraitMode;
    CGSize itemSizeForLandscapeMode;
    PHImageRequestOptions *requestOptions;
    DGActivityIndicatorView *activityIndicatorView;
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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupLoaderActivityIndicator];
    [activityIndicatorView startAnimating];
    [self collectionViewLayoutSettings];
    [self scrollViewSettings];
   
    NSURL* appSettings = [NSURL URLWithString:[UIApplicationOpenSettingsURLString stringByAppendingString:[NSBundle mainBundle].bundleIdentifier]];
    //Confirm action for app settings Alert
    UIAlertAction* confirm = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        if ([[UIApplication sharedApplication] canOpenURL:appSettings]) {
                                                            [[UIApplication sharedApplication] openURL:appSettings options:@{} completionHandler:nil];
                                                        }
                                                    }];
    
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.xPositionOnScrollView = 0.0;
                [self initializeGesture];
                [self initializeImageManager];
                self.photos = [[NSMutableArray alloc] init];
                [self prepareScrollViewForZooming];
                [self.collectionView reloadData];
            });
            if (status == PHAuthorizationStatusDenied) {
                [self showConfirmAlertWithMessage:NSLocalizedString(@"You have denied permission to use the photo library. Go to the settings to change it", nil) title:NSLocalizedString(@"Permission", nil) withConfirmAction:confirm];
            }
        }];
    
}

#pragma mark - Assets

- (void)deletePhotoWithAsset:(PHAsset*)asset {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest deleteAssets:@[asset]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil)
                                                          message:NSLocalizedString(@"Image was deleted successfully", nil) preferredStyle:UIAlertControllerStyleAlert];
           
            UIAlertAction* action = [UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                       [activityIndicatorView startAnimating];
                                                       [self.collectionView performBatchUpdates:^{
                                                           [self.collectionView reloadData];
                                                       } completion:^(BOOL finished) {
                                                           [activityIndicatorView stopAnimating];
                                                       }];
                                                   }];
            [alert addAction:action];
            if (success) {
                [self presentViewController:alert animated:YES completion:^{
                    [self viewDidLoad];
                }];
            }
        });
    }];
}

- (void)loadingAllImages {
    requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode   = PHImageRequestOptionsResizeModeFast;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    requestOptions.synchronous  = YES;
    PHFetchResult *result  = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    NSMutableArray* images = [[NSMutableArray alloc] initWithCapacity:[result count]];
    __block UIImage *imageForArray;
    [result enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.imageManager requestImageForAsset:obj
                                     targetSize:PHImageManagerMaximumSize
                                    contentMode:PHImageContentModeAspectFill
                                        options:requestOptions
                                  resultHandler:^(UIImage *result, NSDictionary *info) {
                                      imageForArray = result;
                                      if (imageForArray) {
                                      [images addObject:imageForArray];
                                      }
                                  }];
        }];
    self.photos = [images copy];
}

- (void)takeAPhoto {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - ImagePickerController Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.photos addObject:(UIImage*)info[UIImagePickerControllerOriginalImage]];
}   

#pragma mark - Actions
- (IBAction)deleteButtonPressed:(id)sender {
    [self deletePhotoWithAsset:self.asset];
    [self closeConcretePhoto];
}

- (IBAction)takePhotoButtonPressed:(id)sender {
    [self takeAPhoto];
}
#pragma mark - Submethods

- (void)collectionViewLayoutSettings {
    UICollectionViewFlowLayout* layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setSectionInset:UIEdgeInsetsMake(0, 0, 0, 0)];
    [layout setMinimumLineSpacing:0.5];
    [layout setMinimumInteritemSpacing:0.5];
    self.collectionView.collectionViewLayout = layout;
}

- (void)setupLoaderActivityIndicator {
    CGSize sizeForIndicator = CGSizeMake([UIScreen mainScreen].bounds.size.height/20, [UIScreen mainScreen].bounds.size.height/20);
    activityIndicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeBallSpinFadeLoader tintColor:[UIColor darkTextColor] size:40.0f];
    activityIndicatorView.frame = CGRectMake(0, 0, sizeForIndicator.width, sizeForIndicator.height);
    activityIndicatorView.center = CGPointMake(self.collectionView.frame.size.width / 2.0, self.collectionView.frame.size.height / 2.0);
    [self.collectionView addSubview:activityIndicatorView];
    [self.collectionView bringSubviewToFront:activityIndicatorView];
}


- (void)showConfirmAlertWithMessage:(NSString*)message title:(NSString*)title withConfirmAction:(UIAlertAction*) confirmAction {
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
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
    [self loadingAllImages];
    [self prepareContentForScrollView];
}

- (void)scrollViewSettings {
    self.concretePhotoScrollView = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.scrollVieww = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.scrollVieww.delegate = self;
    self.scrollVieww.pagingEnabled = YES;
    self.scrollVieww.clipsToBounds = YES;
    self.scrollVieww.canCancelContentTouches = YES;
    self.scrollVieww.delaysContentTouches = NO;
    [self.scrollVieww setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:1]];
    [self.scrollVieww setMinimumZoomScale:0.5];
    [self.scrollVieww setMaximumZoomScale:3.0];
    self.scrollVieww.contentMode = UIViewContentModeScaleAspectFit;
    self.scrollVieww.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.concretePhotoScrollView.frame = self.scrollVieww.frame;
    self.concretePhotoScrollView.clipsToBounds = YES;
    self.concretePhotoScrollView.userInteractionEnabled = YES;
    self.concretePhotoScrollView.pagingEnabled = YES;
    self.concretePhotoScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)prepareContentForScrollView {
     self.concretePhotoScrollView.contentSize = CGSizeMake([UIScreen mainScreen].bounds.size.width * [self.photos count], self.scrollVieww.frame.size.height);
    //prepare scrollview with photos
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
    PHFetchResult *result  = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    self.asset = result[indexPath.item];
    cell.imageView.image = [self.photos objectAtIndex:indexPath.row];
    if (cell.imageView.image) {
        [activityIndicatorView stopAnimating];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedPhotoIndex = indexPath.row;
    PHFetchResult *result  = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    self.asset = result[indexPath.item];
    [self openConcretePhoto];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSArray* assets = [self.assetsFetchResults objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.assetsFetchResults.count)]];
    [self.imageManager startCachingImagesForAssets:assets
                       targetSize:PHImageManagerMaximumSize
                       contentMode:PHImageContentModeAspectFill
                       options:requestOptions];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSArray* assets = [self.assetsFetchResults objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.assetsFetchResults.count)]];
    [self.imageManager stopCachingImagesForAssets:assets
                                       targetSize:PHImageManagerMaximumSize
                                      contentMode:PHImageContentModeAspectFill
                                          options:requestOptions];
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
    [self.takePhotoButton setEnabled:YES];
    [self.takePhotoButton setTintColor:[UIColor darkTextColor]];
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
    self.scrollVieww.pagingEnabled = NO;

}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    self.concretePhotoScrollView.center = self.scrollVieww.center;
    self.scrollVieww.pagingEnabled = YES;
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

