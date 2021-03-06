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
    PHImageRequestOptions *requestOptions;
    DGActivityIndicatorView *activityIndicatorView;
    PHFetchResult *assets;
    PHFetchOptions *fetchOptions;
    PhotoCollectionViewCell *cell;
    BOOL newMedia;
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
@property (strong, nonatomic) UISwipeGestureRecognizer* swipeLeft;
@property (strong, nonatomic) UISwipeGestureRecognizer* swipeRight;
@property (strong, nonatomic) UITapGestureRecognizer* tapToPhoto;
//Data
@property (assign, nonatomic) NSUInteger selectedPhotoIndex;
//Photos framework
@property (strong, nonatomic) PHImageManager *imageManager;
@property (strong, nonatomic) PHCachingImageManager *cachingImageManager;
@property (strong, nonatomic) PHAsset *asset;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupLoaderActivityIndicator];
    [activityIndicatorView startAnimating];
    [self collectionViewLayoutSettings];
    [self scrollViewSettings];
    [self initializeGesture];
    _cachingImageManager = [[PHCachingImageManager alloc] init];
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
                [self settingOptionsForAssets];
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

- (void)settingOptionsForAssets {
    self.imageManager = [PHImageManager defaultManager];
    self.cachingImageManager = [[PHCachingImageManager alloc] init];
    fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode   = PHImageRequestOptionsResizeModeExact;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
    requestOptions.synchronous  = YES;
    requestOptions.networkAccessAllowed = YES;
    assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:fetchOptions];
}

#pragma mark - ImagePickerController Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
        UIImage *image = [info
                          objectForKey:UIImagePickerControllerOriginalImage];
        if (newMedia)
            UIImageWriteToSavedPhotosAlbum(image,
                                           self,
                                           @selector(image:finishedSavingWithError:contextInfo:),
                                           nil);
    [self dismissViewControllerAnimated:YES completion:^{
        [self viewDidLoad];
    }];
}

-(void)image:(UIImage *)image
finishedSavingWithError:(NSError *)error
 contextInfo:(void *)contextInfo
{
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:NSLocalizedString(@"Save failed", nil)
                              message: NSLocalizedString(@"Failed to save image", nil)
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
    }
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

- (void)takeAPhoto {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:picker animated:YES completion:nil];
    newMedia = YES;
}

- (void)openConcretePhotoWithAnimation {
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
    
    [self openConcretePhotoWithSwipeDirection:0];
}

- (void)openConcretePhotoWithSwipeDirection:(UISwipeGestureRecognizerDirection) direction {
    [self.scrollVieww setHidden:NO];
    [self.imageViewForZooming setHidden:NO];
    [self.deleteButton setEnabled:YES];
    [self.deleteButton setTintColor: [UIColor darkTextColor]];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    [self imageViewSettings];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageManager requestImageForAsset:self.asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            [self.imageViewForZooming setImage:result];
        }];
    });
    
    if (direction == UISwipeGestureRecognizerDirectionLeft)
        [UIView transitionWithView:self.concretePhotoScrollView duration:0.3 options:UIViewAnimationOptionTransitionFlipFromRight animations:^{
            [self.concretePhotoScrollView addSubview:self.imageViewForZooming];
        } completion:nil];
    else {
        [UIView transitionWithView:self.concretePhotoScrollView duration:0.3 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            [self.concretePhotoScrollView addSubview:self.imageViewForZooming];
        } completion:nil];
        
    }
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
    [self.imageViewForZooming removeFromSuperview];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}


- (void)imageViewSettings {
    self.imageViewForZooming = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.scrollVieww.frame.size.width, self.scrollVieww.frame.size.height)];
    self.imageViewForZooming.userInteractionEnabled = YES;
    [self.imageViewForZooming setClipsToBounds:YES];
    [self.imageViewForZooming setContentMode:UIViewContentModeScaleAspectFit];
    [self.imageViewForZooming setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
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
    self.concretePhotoScrollView.scrollEnabled = YES;
    self.concretePhotoScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollVieww addSubview:self.concretePhotoScrollView];
}

#pragma mark - UICollectionView Delegate & Datasource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    cell= (PhotoCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:fetchOptions];
    self.asset = assets[indexPath.item];
    [self.imageManager requestImageForAsset:self.asset
                              targetSize:CGSizeMake(150, 150)
                              contentMode:PHImageContentModeAspectFill
                              options:nil
                              resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.imageView.image = result;
    }];
    if (cell.imageView.image) {
        [activityIndicatorView stopAnimating];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedPhotoIndex = indexPath.row;
    self.asset = assets[indexPath.item];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageManager requestImageForAsset:self.asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            [self.imageViewForZooming setImage:result];
        }];
    });
    [self openConcretePhotoWithAnimation];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSArray* myAssets = [assets objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, assets.count)]];
    [self.cachingImageManager startCachingImagesForAssets:myAssets
                              targetSize:PHImageManagerMaximumSize
                              contentMode:PHImageContentModeAspectFill
                              options:requestOptions];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSArray* myAssets = [assets objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, assets.count)]];
    [self.cachingImageManager stopCachingImagesForAssets:myAssets
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
    
    self.swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [self.swipeLeft setNumberOfTouchesRequired:1];
    [self.swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    
    self.swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [self.swipeRight setNumberOfTouchesRequired:1];
    [self.swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    
    [self.concretePhotoScrollView addGestureRecognizer:self.swipeDown];
    [self.concretePhotoScrollView addGestureRecognizer:self.swipeLeft];
    [self.concretePhotoScrollView addGestureRecognizer:self.swipeRight];
    [self.concretePhotoScrollView addGestureRecognizer:self.tapToPhoto];
}

- (void)handleSwipe:(UISwipeGestureRecognizer*)swipe {
    switch (swipe.direction) {
        case UISwipeGestureRecognizerDirectionDown:
            [self closeConcretePhoto];
            break;
        case UISwipeGestureRecognizerDirectionLeft: {
            if (self.selectedPhotoIndex<(assets.count-1)) {
                [self.imageViewForZooming removeFromSuperview];
                self.asset = assets[++self.selectedPhotoIndex];
                [self openConcretePhotoWithSwipeDirection:UISwipeGestureRecognizerDirectionLeft];
            }
        }
            break;
        case UISwipeGestureRecognizerDirectionRight: {
            if (self.selectedPhotoIndex>0) {
                [self.imageViewForZooming removeFromSuperview];
                self.asset = assets[--self.selectedPhotoIndex];
                [self openConcretePhotoWithSwipeDirection:UISwipeGestureRecognizerDirectionRight];
            }
        }
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

#pragma mark - ScrollView Delegate
- (UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollVieww {
    return self.concretePhotoScrollView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    self.concretePhotoScrollView.center = self.scrollVieww.center;
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

