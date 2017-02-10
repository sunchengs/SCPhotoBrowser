//
//  SCPhotoBrowserView.m
//  SCPhotoBrowser
//
//  Created by 孙程 on 2017/2/10.
//  Copyright © 2017年 suncheng. All rights reserved.
//

#import "SCPhotoBrowserView.h"
#import "YYWebImage.h"
#include <sys/sysctl.h>
#import <ImageIO/ImageIO.h>
#import <Accelerate/Accelerate.h>
#import <CoreText/CoreText.h>
#import <objc/runtime.h>

static NSString *kLayerAnimationKey = @"fade";
static CGFloat const kPadding = 20;
static void _yy_cleanupBuffer(void *userData, void *buf_data) {
    free(buf_data);
}

#define WS(weakSelf)  __weak __typeof(&*self)weakSelf = self
#ifndef YY_CLAMP // return the clamped value
#define YY_CLAMP(_x_, _low_, _high_)  (((_x_) > (_high_)) ? (_high_) : (((_x_) < (_low_)) ? (_low_) : (_x_)))
#endif

#ifndef YY_SWAP // swap two value
#define YY_SWAP(_a_, _b_)  do { __typeof__(_a_) _tmp_ = (_a_); (_a_) = (_b_); (_b_) = _tmp_; } while (0)
#endif


@interface SCPhotoGroupItem()<NSCopying>

@property (nonatomic, readonly) UIImage *thumbImage;
@property (nonatomic, readonly) BOOL thumbClippedToTop;

- (BOOL)shouldClipToTop:(CGSize)imageSize forView:(UIView *)view;

@end

@implementation SCPhotoGroupItem

- (UIImage *)thumbImage {
    if ([_thumbView respondsToSelector:@selector(image)]) {
        return ((UIImageView *)_thumbView).image;
    }
    return nil;
}

- (BOOL)thumbClippedToTop {
    if (_thumbView) {
        if (_thumbView.layer.contentsRect.size.height < 1) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)shouldClipToTop:(CGSize)imageSize forView:(UIView *)view {
    if (imageSize.width < 1 || imageSize.height < 1) return NO;
    if (view.frame.size.width < 1 || view.frame.size.height < 1) return NO;
    return imageSize.height / imageSize.width > view.frame.size.width / view.frame.size.height;
}

- (id)copyWithZone:(NSZone *)zone {
    SCPhotoGroupItem *item = [self.class new];
    return item;
}

@end


@interface SCPhotoGroupCell : UIScrollView <UIScrollViewDelegate>
@property (nonatomic, strong) UIView *imageContainerView;
@property (nonatomic, strong) YYAnimatedImageView *imageView;
@property (nonatomic, assign) NSInteger page;

@property (nonatomic, assign) BOOL showProgress;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) CAShapeLayer *progressLayer;

@property (nonatomic, strong) SCPhotoGroupItem *item;
@property (nonatomic, readonly) BOOL itemDidLoad;

- (void)resizeSubviewSize;

@end

@implementation SCPhotoGroupCell

- (instancetype)init {
    self = super.init;
    if (!self) return nil;
    self.delegate = self;
    self.bouncesZoom = YES;
    self.maximumZoomScale = 3;
    self.multipleTouchEnabled = YES;
    self.alwaysBounceVertical = NO;
    self.showsVerticalScrollIndicator = YES;
    self.showsHorizontalScrollIndicator = NO;
    self.frame = [UIScreen mainScreen].bounds;
    
    _imageContainerView = [UIView new];
    _imageContainerView.clipsToBounds = YES;
    [self addSubview:_imageContainerView];
    
    _imageView = [YYAnimatedImageView new];
    _imageView.clipsToBounds = YES;
    _imageView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.500];
    [_imageContainerView addSubview:_imageView];
    
    _progressLayer = [CAShapeLayer layer];
    _progressLayer.frame = CGRectMake(0, 0, 40, 40);
    _progressLayer.cornerRadius = 20;
    _progressLayer.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.500].CGColor;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_progressLayer.bounds, 7, 7) cornerRadius:(40 / 2 - 7)];
    _progressLayer.path = path.CGPath;
    _progressLayer.fillColor = [UIColor clearColor].CGColor;
    _progressLayer.strokeColor = [UIColor whiteColor].CGColor;
    _progressLayer.lineWidth = 4;
    _progressLayer.lineCap = kCALineCapRound;
    _progressLayer.strokeStart = 0;
    _progressLayer.strokeEnd = 0;
    _progressLayer.hidden = YES;
    [self.layer addSublayer:_progressLayer];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _progressLayer.frame = CGRectMake((self.frame.size.width - _progressLayer.frame.size.width) / 2.0, (self.frame.size.height - _progressLayer.frame.size.height) / 2.0, _progressLayer.frame.size.width, _progressLayer.frame.size.height);
    
}

- (void)setItem:(SCPhotoGroupItem *)item {
    if (_item == item) return;
    _item = item;
    _itemDidLoad = NO;
    
    
    [self setZoomScale:1.0 animated:NO];
    self.maximumZoomScale = 1;
    
    [_imageView yy_cancelCurrentImageRequest];
    [_imageView.layer removeAnimationForKey:kLayerAnimationKey];
    
    
    _progressLayer.hidden = NO;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _progressLayer.strokeEnd = 0;
    _progressLayer.hidden = YES;
    [CATransaction commit];
    
    if (!_item) {
        _imageView.image = nil;
        return;
    }
    
    WS(ws);
    [_imageView yy_setImageWithURL:item.largeImageURL placeholder:item.thumbImage options:kNilOptions progress:^(NSInteger receivedSize, NSInteger expectedSize) {
        if (!ws) return;
        CGFloat progress = receivedSize / (float)expectedSize;
        progress = progress < 0.01 ? 0.01 : progress > 1 ? 1 : progress;
        if (isnan(progress)) progress = 0;
        ws.progressLayer.hidden = NO;
        ws.progressLayer.strokeEnd = progress;
    } transform:nil completion:^(UIImage *image, NSURL *url, YYWebImageFromType from, YYWebImageStage stage, NSError *error) {
        if (!ws) return;
        ws.progressLayer.hidden = YES;
        if (stage == YYWebImageStageFinished) {
            ws.maximumZoomScale = 3;
            if (image) {
                self->_itemDidLoad = YES;
                [ws resizeSubviewSize];
                [self layer:ws.imageView.layer addFadeAnimationWithDuration:0.1 curve:UIViewAnimationCurveLinear];
            }
        }
        
    }];
    [self resizeSubviewSize];
}

- (void)resizeSubviewSize {
    CGRect frame = _imageContainerView.frame;
    frame.origin = CGPointZero;
    frame.size.width = self.frame.size.width;
    _imageContainerView.frame = frame;
    
    UIImage *image = _imageView.image;
    if (image.size.height / image.size.width > self.frame.size.height / self.frame.size.width) {
        frame.size.height = floor(image.size.height / (image.size.width / self.frame.size.width));
        _imageContainerView.frame = frame;
    } else {
        CGFloat height = image.size.height / image.size.width * self.frame.size.width;
        if (height < 1 || isnan(height)) height = self.frame.size.height;
        height = floor(height);
        frame.size.height = height;
        _imageContainerView.frame = frame;
        _imageContainerView.center = CGPointMake(_imageContainerView.center.x, self.frame.size.height / 2);
    }
    if (_imageContainerView.frame.size.height > self.frame.size.height && _imageContainerView.frame.size.height - self.frame.size.height <= 1) {
        frame.size.height = self.frame.size.height;
        _imageContainerView.frame = frame;
    }
    self.contentSize = CGSizeMake(self.frame.size.width, MAX(_imageContainerView.frame.size.height, self.frame.size.height));
    [self scrollRectToVisible:self.bounds animated:NO];
    
    if (_imageContainerView.frame.size.height <= self.frame.size.height) {
        self.alwaysBounceVertical = NO;
    } else {
        self.alwaysBounceVertical = YES;
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _imageView.frame = _imageContainerView.bounds;
    [CATransaction commit];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{
    return _imageContainerView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    UIView *subView = _imageContainerView;
    
    CGFloat offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width)?
    (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0;
    
    CGFloat offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height)?
    (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0;
    
    subView.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
                                 scrollView.contentSize.height * 0.5 + offsetY);
}

// CALayer Animation

- (void)layer:(CALayer *)layer addFadeAnimationWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve {
    if (duration <= 0) return;
    
    NSString *mediaFunction;
    switch (curve) {
        case UIViewAnimationCurveEaseInOut: {
            mediaFunction = kCAMediaTimingFunctionEaseInEaseOut;
        } break;
        case UIViewAnimationCurveEaseIn: {
            mediaFunction = kCAMediaTimingFunctionEaseIn;
        } break;
        case UIViewAnimationCurveEaseOut: {
            mediaFunction = kCAMediaTimingFunctionEaseOut;
        } break;
        case UIViewAnimationCurveLinear: {
            mediaFunction = kCAMediaTimingFunctionLinear;
        } break;
        default: {
            mediaFunction = kCAMediaTimingFunctionLinear;
        } break;
    }
    
    CATransition *transition = [CATransition animation];
    transition.duration = duration;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:mediaFunction];
    transition.type = kCATransitionFade;
    [layer addAnimation:transition forKey:kLayerAnimationKey];
}

@end

@interface SCPhotoBrowserView() <UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, weak) UIView *fromView;
@property (nonatomic, weak) UIView *toContainerView;

@property (nonatomic, strong) UIImage *snapshotImage;
@property (nonatomic, strong) UIImage *snapshorImageHideFromView;

@property (nonatomic, strong) UIImageView *background;
@property (nonatomic, strong) UIImageView *blurBackground;

@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *cells;
@property (nonatomic, strong) UIPageControl *pager;
@property (nonatomic, assign) CGFloat pagerCurrentPage;
@property (nonatomic, assign) BOOL fromNavigationBarHidden;

@property (nonatomic, assign) NSInteger fromItemIndex;
@property (nonatomic, assign) BOOL isPresented;

@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, assign) CGPoint panGestureBeginPoint;

@end

@implementation SCPhotoBrowserView

- (instancetype)initWithGroupItems:(NSArray *)groupItems {
    self = [super init];
    if (groupItems.count == 0) return nil;
    _groupItems = groupItems.copy;
    _blurEffectBackground = YES;
    NSString *model = [self machineModel];
    static NSMutableSet *oldDevices;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        oldDevices = [NSMutableSet new];
        [oldDevices addObject:@"iPod1,1"];
        [oldDevices addObject:@"iPod2,1"];
        [oldDevices addObject:@"iPod3,1"];
        [oldDevices addObject:@"iPod4,1"];
        [oldDevices addObject:@"iPod5,1"];
        
        [oldDevices addObject:@"iPhone1,1"];
        [oldDevices addObject:@"iPhone1,1"];
        [oldDevices addObject:@"iPhone1,2"];
        [oldDevices addObject:@"iPhone2,1"];
        [oldDevices addObject:@"iPhone3,1"];
        [oldDevices addObject:@"iPhone3,2"];
        [oldDevices addObject:@"iPhone3,3"];
        [oldDevices addObject:@"iPhone4,1"];
        
        [oldDevices addObject:@"iPad1,1"];
        [oldDevices addObject:@"iPad2,1"];
        [oldDevices addObject:@"iPad2,2"];
        [oldDevices addObject:@"iPad2,3"];
        [oldDevices addObject:@"iPad2,4"];
        [oldDevices addObject:@"iPad2,5"];
        [oldDevices addObject:@"iPad2,6"];
        [oldDevices addObject:@"iPad2,7"];
        [oldDevices addObject:@"iPad3,1"];
        [oldDevices addObject:@"iPad3,2"];
        [oldDevices addObject:@"iPad3,3"];
    });
    if ([oldDevices containsObject:model]) {
        _blurEffectBackground = NO;
    }
    
    self.backgroundColor = [UIColor clearColor];
    self.frame = [UIScreen mainScreen].bounds;
    self.clipsToBounds = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];
    
    UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    tap2.delegate = self;
    tap2.numberOfTapsRequired = 2;
    [tap requireGestureRecognizerToFail: tap2];
    [self addGestureRecognizer:tap2];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress)];
    press.delegate = self;
    [self addGestureRecognizer:press];
    
    if ([UIDevice currentDevice].systemVersion.floatValue >= 7) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [self addGestureRecognizer:pan];
        _panGesture = pan;
    }
    
    
    _cells = @[].mutableCopy;
    
    _background = UIImageView.new;
    _background.frame = self.bounds;
    _background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _blurBackground = UIImageView.new;
    _blurBackground.frame = self.bounds;
    _blurBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _contentView = UIView.new;
    _contentView.frame = self.bounds;
    _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _scrollView = UIScrollView.new;
    _scrollView.frame = CGRectMake(-kPadding / 2, 0, self.frame.size.width + kPadding, self.frame.size.height);
    _scrollView.delegate = self;
    _scrollView.scrollsToTop = NO;
    _scrollView.pagingEnabled = YES;
    _scrollView.alwaysBounceHorizontal = groupItems.count > 1;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.delaysContentTouches = NO;
    _scrollView.canCancelContentTouches = YES;
    
    _pager = [[UIPageControl alloc] init];
    _pager.hidesForSinglePage = YES;
    _pager.userInteractionEnabled = NO;
    
    CGRect frame = _pager.frame;
    frame.size.width = self.frame.size.width - 36;
    frame.size.height = 10;
    _pager.frame = frame;
    _pager.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height - 18);
    _pager.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    [self addSubview:_background];
    [self addSubview:_blurBackground];
    [self addSubview:_contentView];
    [_contentView addSubview:_scrollView];
    [_contentView addSubview:_pager];
    return self;
}



- (void)presentFromImageView:(UIView *)fromView
                 toContainer:(UIView *)toContainer
                    animated:(BOOL)animated
                  completion:(void (^)(void))completion
{
    
    if (!toContainer) return;
    
    _fromView = fromView;
    _toContainerView = toContainer;
    
    NSInteger page = -1;
    for (NSUInteger i = 0; i < self.groupItems.count; i++) {
        if (fromView == ((SCPhotoGroupItem *)self.groupItems[i]).thumbView) {
            page = (int)i;
            break;
        }
    }
    if (page == -1) page = 0;
    _fromItemIndex = page;
    
    _snapshotImage = [self snapshotImage:_toContainerView afterScreenUpdates:NO];
    BOOL fromViewHidden = fromView.hidden;
    fromView.hidden = YES;
    _snapshorImageHideFromView = [self snapshotImage:_toContainerView];
    fromView.hidden = fromViewHidden;
    
    _background.image = _snapshorImageHideFromView;
    if (_blurEffectBackground) {
        _blurBackground.image = [self imageByBlurDark:_snapshorImageHideFromView]; //Same to UIBlurEffectStyleDark
    } else {
        _blurBackground.image = [self imageWithColor:[UIColor blackColor] size:CGSizeMake(1, 1)];
    }
    
    CGRect frame = self.frame;
    frame.size = _toContainerView.frame.size;
    self.frame = frame;
    self.blurBackground.alpha = 0;
    self.pager.alpha = 0;
    self.pager.numberOfPages = self.groupItems.count;
    self.pager.currentPage = page;
    [_toContainerView addSubview:self];
    
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * self.groupItems.count, _scrollView.frame.size.height);
    [_scrollView scrollRectToVisible:CGRectMake(_scrollView.frame.size.width * _pager.currentPage, 0, _scrollView.frame.size.width, _scrollView.frame.size.height) animated:NO];
    [self scrollViewDidScroll:_scrollView];
    
    [UIView setAnimationsEnabled:YES];
    _fromNavigationBarHidden = [UIApplication sharedApplication].statusBarHidden;
    //    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    
    
    SCPhotoGroupCell *cell = [self cellForPage:self.currentPage];
    SCPhotoGroupItem *item = _groupItems[self.currentPage];
    
    if (!item.thumbClippedToTop) {
        NSString *imageKey = [[YYWebImageManager sharedManager] cacheKeyForURL:item.largeImageURL];
        if ([[YYWebImageManager sharedManager].cache getImageForKey:imageKey withType:YYImageCacheTypeMemory]) {
            cell.item = item;
        }
    }
    if (!cell.item) {
        cell.imageView.image = item.thumbImage;
        [cell resizeSubviewSize];
    }
    
    if (item.thumbClippedToTop) {
        CGRect fromFrame = [_fromView convertRect:_fromView.bounds toView:cell];
        CGRect originFrame = cell.imageContainerView.frame;
        CGFloat scale = fromFrame.size.width / cell.imageContainerView.frame.size.width;
        
        CGRect cellFrame = cell.frame;
        cellFrame.origin = CGPointMake(CGRectGetMidX(fromFrame), CGRectGetMidY(fromFrame));
        cellFrame.size.height = fromFrame.size.height / scale;
        //        cell.imageContainerView.centerX = CGRectGetMidX(fromFrame);
        //        cell.imageContainerView.height = fromFrame.size.height / scale;
        //        cell.imageContainerView.layer.transformScale = scale;
        [cell.imageContainerView.layer setValue:@(scale) forKeyPath:@"transform.scale"];
        
        //        cell.imageContainerView.centerY = CGRectGetMidY(fromFrame);
        cell.frame = cellFrame;
        
        float oneTime = animated ? 0.25 : 0;
        [UIView animateWithDuration:oneTime delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            _blurBackground.alpha = 1;
        }completion:NULL];
        
        _scrollView.userInteractionEnabled = NO;
        [UIView animateWithDuration:oneTime delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            //            cell.imageContainerView.layer.transformScale = 1;
            [cell.imageContainerView.layer setValue:@(1) forKeyPath:@"transform.scale"];
            
            cell.imageContainerView.frame = originFrame;
            _pager.alpha = 1;
        }completion:^(BOOL finished) {
            _isPresented = YES;
            [self scrollViewDidScroll:_scrollView];
            _scrollView.userInteractionEnabled = YES;
            [self hidePager];
            if (completion) completion();
        }];
        
    } else {
        CGRect fromFrame = [_fromView convertRect:_fromView.bounds toView:cell.imageContainerView];
        
        cell.imageContainerView.clipsToBounds = NO;
        cell.imageView.frame = fromFrame;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        
        float oneTime = animated ? 0.18 : 0;
        [UIView animateWithDuration:oneTime*2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            _blurBackground.alpha = 1;
        }completion:NULL];
        
        _scrollView.userInteractionEnabled = NO;
        [UIView animateWithDuration:oneTime delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            cell.imageView.frame = cell.imageContainerView.bounds;
            //            cell.imageView.layer.transformScale = 1.01;
            [cell.imageContainerView.layer setValue:@(1.01) forKeyPath:@"transform.scale"];
            
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:oneTime delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
                //                cell.imageView.layer.transformScale = 1.0;
                [cell.imageContainerView.layer setValue:@(1.0) forKeyPath:@"transform.scale"];
                
                _pager.alpha = 1;
            }completion:^(BOOL finished) {
                cell.imageContainerView.clipsToBounds = YES;
                _isPresented = YES;
                [self scrollViewDidScroll:_scrollView];
                _scrollView.userInteractionEnabled = YES;
                [self hidePager];
                if (completion) completion();
            }];
        }];
    }
}


- (void)dismissAnimated:(BOOL)animated completion:(void (^)(void))completion {
    [UIView setAnimationsEnabled:YES];
    
    //    [[UIApplication sharedApplication] setStatusBarHidden:_fromNavigationBarHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    NSInteger currentPage = self.currentPage;
    SCPhotoGroupCell *cell = [self cellForPage:currentPage];
    SCPhotoGroupItem *item = _groupItems[currentPage];
    
    UIView *fromView = nil;
    if (_fromItemIndex == currentPage) {
        fromView = _fromView;
    } else {
        fromView = item.thumbView;
    }
    
    [self cancelAllImageLoad];
    _isPresented = NO;
    BOOL isFromImageClipped = fromView.layer.contentsRect.size.height < 1;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (isFromImageClipped) {
        CGRect frame = cell.imageContainerView.frame;
        cell.imageContainerView.layer.anchorPoint = CGPointMake(0.5, 0);
        cell.imageContainerView.frame = frame;
    }
    cell.progressLayer.hidden = YES;
    [CATransaction commit];
    
    
    
    
    if (fromView == nil) {
        self.background.image = _snapshotImage;
        [UIView animateWithDuration:animated ? 0.25 : 0 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut animations:^{
            self.alpha = 0.0;
            //            self.scrollView.layer.transformScale = 0.95;
            [cell.imageContainerView.layer setValue:@(0.95) forKeyPath:@"transform.scale"];
            
            self.scrollView.alpha = 0;
            self.pager.alpha = 0;
            self.blurBackground.alpha = 0;
        }completion:^(BOOL finished) {
            //            self.scrollView.layer.transformScale = 1;
            [cell.imageContainerView.layer setValue:@(1) forKeyPath:@"transform.scale"];
            
            [self removeFromSuperview];
            [self cancelAllImageLoad];
            if (completion) completion();
        }];
        return;
    }
    
    if (_fromItemIndex != currentPage) {
        _background.image = _snapshotImage;
        //        [_background.layer addFadeAnimationWithDuration:0.25 curve:UIViewAnimationCurveEaseOut];
        [self layer:_background.layer addFadeAnimationWithDuration:0.25 curve:UIViewAnimationCurveEaseOut];
    } else {
        _background.image = _snapshorImageHideFromView;
    }
    
    
    if (isFromImageClipped) {
        CGPoint off = cell.contentOffset;
        off.y = 0 - cell.contentInset.top;
        [cell setContentOffset:off animated:NO];
    }
    
    [UIView animateWithDuration:animated ? 0.2 : 0 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut animations:^{
        _pager.alpha = 0.0;
        _blurBackground.alpha = 0.0;
        if (isFromImageClipped) {
            
            CGRect fromFrame = [fromView convertRect:fromView.bounds toView:cell];
            CGFloat scale = fromFrame.size.width / cell.imageContainerView.frame.size.width * cell.zoomScale;
            CGFloat height = fromFrame.size.height / fromFrame.size.width * cell.imageContainerView.frame.size.width;
            if (isnan(height)) height = cell.imageContainerView.frame.size.height;
            
            CGRect cellFrame = cell.frame;
            cellFrame.size.height = height;
            //            cell.imageContainerView.frame.size.height = height;
            cell.imageContainerView.center = CGPointMake(CGRectGetMidX(fromFrame), CGRectGetMinY(fromFrame));
            //            cell.imageContainerView.layer.transformScale = scale;
            [cell.imageContainerView.layer setValue:@(scale) forKeyPath:@"transform.scale"];
            
            cell.frame = cellFrame;
            
        } else {
            CGRect fromFrame = [fromView convertRect:fromView.bounds toView:cell.imageContainerView];
            cell.imageContainerView.clipsToBounds = NO;
            cell.imageView.contentMode = fromView.contentMode;
            cell.imageView.frame = fromFrame;
        }
    }completion:^(BOOL finished) {
        [UIView animateWithDuration:animated ? 0.15 : 0 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            cell.imageContainerView.layer.anchorPoint = CGPointMake(0.5, 0.5);
            [self removeFromSuperview];
            if (completion) completion();
        }];
    }];
    
    
}

- (void)dismiss {
    [self dismissAnimated:YES completion:nil];
}


- (void)cancelAllImageLoad {
    [_cells enumerateObjectsUsingBlock:^(SCPhotoGroupCell *cell, NSUInteger idx, BOOL *stop) {
        [cell.imageView yy_cancelCurrentImageRequest];
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateCellsForReuse];
    
    CGFloat floatPage = _scrollView.contentOffset.x / _scrollView.frame.size.width;
    NSInteger page = _scrollView.contentOffset.x / _scrollView.frame.size.width + 0.5;
    
    for (NSInteger i = page - 1; i <= page + 1; i++) { // preload left and right cell
        if (i >= 0 && i < self.groupItems.count) {
            SCPhotoGroupCell *cell = [self cellForPage:i];
            if (!cell) {
                SCPhotoGroupCell *cell = [self dequeueReusableCell];
                cell.page = i;
                CGRect cellFrame = cell.frame;
                cellFrame = CGRectMake((self.frame.size.width + kPadding) * i + kPadding / 2, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
                cell.frame = cellFrame;
                if (_isPresented) {
                    cell.item = self.groupItems[i];
                }
                [self.scrollView addSubview:cell];
            } else {
                if (_isPresented && !cell.item) {
                    cell.item = self.groupItems[i];
                }
            }
        }
    }
    
    NSInteger intPage = floatPage + 0.5;
    intPage = intPage < 0 ? 0 : intPage >= _groupItems.count ? (int)_groupItems.count - 1 : intPage;
    _pager.currentPage = intPage;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        _pager.alpha = 1;
    }completion:^(BOOL finish) {
    }];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    if (!decelerate) {
        [self hidePager];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self hidePager];
}


- (void)hidePager {
    [UIView animateWithDuration:0.3 delay:0.8 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
        _pager.alpha = 0;
    }completion:^(BOOL finish) {
    }];
}

/// enqueue invisible cells for reuse
- (void)updateCellsForReuse {
    for (SCPhotoGroupCell *cell in _cells) {
        if (cell.superview) {
            CGRect cellFrame = cell.frame;
            
            if (cellFrame.origin.x > _scrollView.contentOffset.x + _scrollView.frame.size.width * 2||
                (cellFrame.origin.x + cellFrame.size.width) < _scrollView.contentOffset.x - _scrollView.frame.size.width) {
                [cell removeFromSuperview];
                cell.page = -1;
                cell.item = nil;
            }
        }
    }
}

/// dequeue a reusable cell
- (SCPhotoGroupCell *)dequeueReusableCell {
    SCPhotoGroupCell *cell = nil;
    for (cell in _cells) {
        if (!cell.superview) {
            return cell;
        }
    }
    
    cell = [SCPhotoGroupCell new];
    cell.frame = self.bounds;
    cell.imageContainerView.frame = self.bounds;
    cell.imageView.frame = cell.bounds;
    cell.page = -1;
    cell.item = nil;
    [_cells addObject:cell];
    return cell;
}

/// get the cell for specified page, nil if the cell is invisible
- (SCPhotoGroupCell *)cellForPage:(NSInteger)page {
    for (SCPhotoGroupCell *cell in _cells) {
        if (cell.page == page) {
            return cell;
        }
    }
    return nil;
}

- (NSInteger)currentPage {
    NSInteger page = _scrollView.contentOffset.x / _scrollView.frame.size.width + 0.5;
    if (page >= _groupItems.count) page = (NSInteger)_groupItems.count - 1;
    if (page < 0) page = 0;
    return page;
}

- (void)longPress {
    if (!_isPresented) return;
    
    SCPhotoGroupCell *tile = [self cellForPage:self.currentPage];
    if (!tile.imageView.image) return;
    
    // try to save original image data if the image contains multi-frame (such as GIF/APNG)
    
    id imageItem = [self image:tile.imageView.image dataRepresentationForSystem:NO];
    YYImageType type = YYImageDetectType((__bridge CFDataRef)(imageItem));
    if (type != YYImageTypePNG &&
        type != YYImageTypeJPEG &&
        type != YYImageTypeGIF) {
        imageItem = tile.imageView.image;
    }
    
    UIActivityViewController *activityViewController =
    [[UIActivityViewController alloc] initWithActivityItems:@[imageItem] applicationActivities:nil];
    
    UIViewController *viewController;
    for (UIView *view = self.toContainerView; view; view = view.superview) {
        UIResponder *nextResponder = [view nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            viewController = (UIViewController *)nextResponder;
        }
    }
    UIViewController *toVC = viewController;
    
    UIViewController *selfViewController;
    for (UIView *view = self; view; view = view.superview) {
        UIResponder *nextResponder = [view nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            selfViewController = (UIViewController *)nextResponder;
        }
    }
    if (!toVC) toVC = selfViewController;
    [toVC presentViewController:activityViewController animated:YES completion:nil];
}

/// @param forSystem YES: used for system album (PNG/JPEG/GIF), NO: used for YYImage (PNG/JPEG/GIF/WebP)
- (NSData *)image:(UIImage *)image dataRepresentationForSystem:(BOOL)forSystem {
    NSData *data = nil;
    if ([self isKindOfClass:[YYImage class]]) {
        YYImage *image = (id)self;
        if (image.animatedImageData) {
            if (forSystem) { // system only support GIF and PNG
                if (image.animatedImageType == YYImageTypeGIF ||
                    image.animatedImageType == YYImageTypePNG) {
                    data = image.animatedImageData;
                }
            } else {
                data = image.animatedImageData;
            }
        }
    }
    if (!data) {
        CGImageRef imageRef = image.CGImage ? (CGImageRef)CFRetain(image.CGImage) : nil;
        if (imageRef) {
            CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
            CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask;
            BOOL hasAlpha = NO;
            if (alphaInfo == kCGImageAlphaPremultipliedLast ||
                alphaInfo == kCGImageAlphaPremultipliedFirst ||
                alphaInfo == kCGImageAlphaLast ||
                alphaInfo == kCGImageAlphaFirst) {
                hasAlpha = YES;
            }
            if (image.imageOrientation != UIImageOrientationUp) {
                CGImageRef rotated = YYCGImageCreateCopyWithOrientation(imageRef, image.imageOrientation, bitmapInfo | alphaInfo);
                if (rotated) {
                    CFRelease(imageRef);
                    imageRef = rotated;
                }
            }
            @autoreleasepool {
                UIImage *newImage = [UIImage imageWithCGImage:imageRef];
                if (newImage) {
                    if (hasAlpha) {
                        data = UIImagePNGRepresentation([UIImage imageWithCGImage:imageRef]);
                    } else {
                        data = UIImageJPEGRepresentation([UIImage imageWithCGImage:imageRef], 0.9); // same as Apple's example
                    }
                }
            }
            CFRelease(imageRef);
        }
    }
    if (!data) {
        data = UIImagePNGRepresentation(image);
    }
    return data;
}


- (void)pan:(UIPanGestureRecognizer *)g {
    switch (g.state) {
        case UIGestureRecognizerStateBegan: {
            if (_isPresented) {
                _panGestureBeginPoint = [g locationInView:self];
            } else {
                _panGestureBeginPoint = CGPointZero;
            }
        } break;
        case UIGestureRecognizerStateChanged: {
            if (_panGestureBeginPoint.x == 0 && _panGestureBeginPoint.y == 0) return;
            CGPoint p = [g locationInView:self];
            CGFloat deltaY = p.y - _panGestureBeginPoint.y;
            CGRect scrollViewFrame = _scrollView.frame;
            scrollViewFrame.origin.y = deltaY;
            _scrollView.frame = scrollViewFrame;
            //            _scrollView.top = deltaY;
            
            CGFloat alphaDelta = 160;
            CGFloat alpha = (alphaDelta - fabs(deltaY) + 50) / alphaDelta;
            alpha = YY_CLAMP(alpha, 0, 1);
            [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear animations:^{
                _blurBackground.alpha = alpha;
                _pager.alpha = alpha;
            } completion:nil];
            
        } break;
        case UIGestureRecognizerStateEnded: {
            if (_panGestureBeginPoint.x == 0 && _panGestureBeginPoint.y == 0) return;
            CGPoint v = [g velocityInView:self];
            CGPoint p = [g locationInView:self];
            CGFloat deltaY = p.y - _panGestureBeginPoint.y;
            
            if (fabs(v.y) > 1000 || fabs(deltaY) > 120) {
                [self cancelAllImageLoad];
                _isPresented = NO;
                //                [[UIApplication sharedApplication] setStatusBarHidden:_fromNavigationBarHidden withAnimation:UIStatusBarAnimationFade];
                
                BOOL moveToTop = (v.y < - 50 || (v.y < 50 && deltaY < 0));
                CGFloat vy = fabs(v.y);
                if (vy < 1) vy = 1;
                CGFloat duration = (moveToTop ? (_scrollView.frame.size.height + _scrollView.frame.origin.y) : self.frame.size.height - _scrollView.frame.origin.y) / vy;
                duration *= 0.8;
                duration = YY_CLAMP(duration, 0.05, 0.3);
                
                [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    _blurBackground.alpha = 0;
                    _pager.alpha = 0;
                    CGRect scrollviewFrame = _scrollView.frame;
                    
                    if (moveToTop) {
                        scrollviewFrame.origin.y = -scrollviewFrame.size.height;
                        //                        _scrollView.bottom = 0;
                    } else {
                        scrollviewFrame.origin.y = self.frame.size.height;
                    }
                    _scrollView.frame = scrollviewFrame;
                } completion:^(BOOL finished) {
                    [self removeFromSuperview];
                }];
                
                _background.image = _snapshotImage;
                [self layer:_background.layer addFadeAnimationWithDuration:0.3 curve:UIViewAnimationCurveEaseInOut];
                
            } else {
                [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:v.y / 1000 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    CGRect scrollviewFrame = _scrollView.frame;
                    scrollviewFrame.origin.y = 0;
                    _scrollView.frame = scrollviewFrame;
                    _blurBackground.alpha = 1;
                    _pager.alpha = 1;
                } completion:^(BOOL finished) {
                    
                }];
            }
            
        } break;
        case UIGestureRecognizerStateCancelled : {
            CGRect scrollviewFrame = _scrollView.frame;
            scrollviewFrame.origin.y = 0;
            _scrollView.frame = scrollviewFrame;
            _blurBackground.alpha = 1;
        }
        default:break;
    }
}


#pragma mark - ========= private method

// 设备,格式如“iPhone4,1”
- (NSString *)machineModel {
    static dispatch_once_t one;
    static NSString *model;
    dispatch_once(&one, ^{
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        model = [NSString stringWithUTF8String:machine];
        free(machine);
    });
    return model;
}

// 截图
- (UIImage *)snapshotImage:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *snap = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snap;
}

- (UIImage *)snapshotImage:(UIView *)view afterScreenUpdates:(BOOL)afterUpdates {
    if (![self respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        return [self snapshotImage];
    }
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:afterUpdates];
    UIImage *snap = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snap;
}

// 纯色图片
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    if (!color || size.width <= 0 || size.height <= 0) return nil;
    CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 文本size
- (CGSize)sizeForFont:(UIFont *)font size:(CGSize)size mode:(NSLineBreakMode)lineBreakMode string:(NSString *)str{
    CGSize result;
    if (!font) font = [UIFont systemFontOfSize:12];
    if ([self respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
        NSMutableDictionary *attr = [NSMutableDictionary new];
        attr[NSFontAttributeName] = font;
        if (lineBreakMode != NSLineBreakByWordWrapping) {
            NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
            paragraphStyle.lineBreakMode = lineBreakMode;
            attr[NSParagraphStyleAttributeName] = paragraphStyle;
        }
        CGRect rect = [str boundingRectWithSize:size
                                        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                     attributes:attr context:nil];
        result = rect.size;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        result = [str sizeWithFont:font constrainedToSize:size lineBreakMode:lineBreakMode];
#pragma clang diagnostic pop
    }
    return result;
}

// 暂时没用
- (void)showHUD:(NSString *)msg {
    if (!msg.length) return;
    UIFont *font = [UIFont systemFontOfSize:17];
    CGSize size = [self sizeForFont:font size:CGSizeMake(200, 200) mode:NSLineBreakByCharWrapping string:msg];
    UILabel *label = [UILabel new];
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect labelFrame = label.frame;
    labelFrame.size = CGSizeMake(ceil(size.width * scale) / scale,
                                 ceil(size.height * scale) / scale);
    label.font = font;
    label.text = msg;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.frame = labelFrame;
    
    UIView *hud = [UIView new];
    CGRect hudFrame = hud.frame;
    hudFrame.size = CGSizeMake(label.frame.size.width + 20, label.frame.size.height + 20);
    hud.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.650];
    hud.clipsToBounds = YES;
    hud.layer.cornerRadius = 8;
    hud.frame = hudFrame;
    
    label.center = CGPointMake(hudFrame.size.width / 2, hudFrame.size.height / 2);
    [hud addSubview:label];
    
    hud.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
    hud.alpha = 0;
    [self addSubview:hud];
    
    [UIView animateWithDuration:0.4 animations:^{
        hud.alpha = 1;
    }];
    double delayInSeconds = 1.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [UIView animateWithDuration:0.4 animations:^{
            hud.alpha = 0;
        } completion:^(BOOL finished) {
            [hud removeFromSuperview];
        }];
    });
}

- (void)doubleTap:(UITapGestureRecognizer *)g {
    if (!_isPresented) return;
    SCPhotoGroupCell *tile = [self cellForPage:self.currentPage];
    if (tile) {
        if (tile.zoomScale > 1) {
            [tile setZoomScale:1 animated:YES];
        } else {
            CGPoint touchPoint = [g locationInView:tile.imageView];
            CGFloat newZoomScale = tile.maximumZoomScale;
            CGFloat xsize = self.frame.size.width / newZoomScale;
            CGFloat ysize = self.frame.size.height / newZoomScale;
            [tile zoomToRect:CGRectMake(touchPoint.x - xsize/2, touchPoint.y - ysize/2, xsize, ysize) animated:YES];
        }
    }
}

// 图片玻璃模糊效果
- (UIImage *)imageByBlurDark:(UIImage *)image {
    return [self image:image byBlurRadius:40 tintColor:[UIColor colorWithWhite:0.11 alpha:0.73] tintMode:kCGBlendModeNormal saturation:1.8 maskImage:nil];
}

- (UIImage *)image:(UIImage *)image
      byBlurRadius:(CGFloat)blurRadius
         tintColor:(UIColor *)tintColor
          tintMode:(CGBlendMode)tintBlendMode
        saturation:(CGFloat)saturation
         maskImage:(UIImage *)maskImage {
    if (self.frame.size.width < 1 || self.frame.size.height < 1) {
        NSLog(@"UIImage+YYAdd error: invalid size: (%.2f x %.2f). Both dimensions must be >= 1: %@", self.frame.size.width, self.frame.size.height, self);
        return nil;
    }
    if (!image.CGImage) {
        NSLog(@"UIImage+YYAdd error: inputImage must be backed by a CGImage: %@", self);
        return nil;
    }
    if (maskImage && !maskImage.CGImage) {
        NSLog(@"UIImage+YYAdd error: effectMaskImage must be backed by a CGImage: %@", maskImage);
        return nil;
    }
    
    // iOS7 and above can use new func.
    BOOL hasNewFunc = (long)vImageBuffer_InitWithCGImage != 0 && (long)vImageCreateCGImageFromBuffer != 0;
    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    BOOL hasSaturation = fabs(saturation - 1.0) > __FLT_EPSILON__;
    
    CGSize size = self.frame.size;
    CGRect rect = { CGPointZero, size };
    CGFloat scale = image.scale;
    CGImageRef imageRef = image.CGImage;
    BOOL opaque = NO;
    
    if (!hasBlur && !hasSaturation) {
        return [self _yy_mergeImage:image imageRef:imageRef tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];
    }
    
    vImage_Buffer effect = { 0 }, scratch = { 0 };
    vImage_Buffer *input = NULL, *output = NULL;
    
    vImage_CGImageFormat format = {
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = NULL,
        .bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, //requests a BGRA buffer.
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault
    };
    
    if (hasNewFunc) {
        vImage_Error err;
        err = vImageBuffer_InitWithCGImage(&effect, &format, NULL, imageRef, kvImagePrintDiagnosticsToConsole);
        if (err != kvImageNoError) {
            NSLog(@"UIImage+YYAdd error: vImageBuffer_InitWithCGImage returned error code %zi for inputImage: %@", err, self);
            return nil;
        }
        err = vImageBuffer_Init(&scratch, effect.height, effect.width, format.bitsPerPixel, kvImageNoFlags);
        if (err != kvImageNoError) {
            NSLog(@"UIImage+YYAdd error: vImageBuffer_Init returned error code %zi for inputImage: %@", err, self);
            return nil;
        }
    } else {
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
        CGContextRef effectCtx = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(effectCtx, 1.0, -1.0);
        CGContextTranslateCTM(effectCtx, 0, -size.height);
        CGContextDrawImage(effectCtx, rect, imageRef);
        effect.data     = CGBitmapContextGetData(effectCtx);
        effect.width    = CGBitmapContextGetWidth(effectCtx);
        effect.height   = CGBitmapContextGetHeight(effectCtx);
        effect.rowBytes = CGBitmapContextGetBytesPerRow(effectCtx);
        
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
        CGContextRef scratchCtx = UIGraphicsGetCurrentContext();
        scratch.data     = CGBitmapContextGetData(scratchCtx);
        scratch.width    = CGBitmapContextGetWidth(scratchCtx);
        scratch.height   = CGBitmapContextGetHeight(scratchCtx);
        scratch.rowBytes = CGBitmapContextGetBytesPerRow(scratchCtx);
    }
    
    input = &effect;
    output = &scratch;
    
    if (hasBlur) {
        // A description of how to compute the box kernel width from the Gaussian
        // radius (aka standard deviation) appears in the SVG spec:
        // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
        //
        // For larger values of 's' (s >= 2.0), an approximation can be used: Three
        // successive box-blurs build a piece-wise quadratic convolution kernel, which
        // approximates the Gaussian kernel to within roughly 3%.
        //
        // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
        //
        // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
        //
        CGFloat inputRadius = blurRadius * scale;
        if (inputRadius - 2.0 < __FLT_EPSILON__) inputRadius = 2.0;
        uint32_t radius = floor((inputRadius * 3.0 * sqrt(2 * M_PI) / 4 + 0.5) / 2);
        radius |= 1; // force radius to be odd so that the three box-blur methodology works.
        int iterations;
        if (blurRadius * scale < 0.5) iterations = 1;
        else if (blurRadius * scale < 1.5) iterations = 2;
        else iterations = 3;
        NSInteger tempSize = vImageBoxConvolve_ARGB8888(input, output, NULL, 0, 0, radius, radius, NULL, kvImageGetTempBufferSize | kvImageEdgeExtend);
        void *temp = malloc(tempSize);
        for (int i = 0; i < iterations; i++) {
            vImageBoxConvolve_ARGB8888(input, output, temp, 0, 0, radius, radius, NULL, kvImageEdgeExtend);
            YY_SWAP(input, output);
        }
        free(temp);
    }
    
    
    if (hasSaturation) {
        // These values appear in the W3C Filter Effects spec:
        // https://dvcs.w3.org/hg/FXTF/raw-file/default/filters/Publish.html#grayscaleEquivalent
        CGFloat s = saturation;
        CGFloat matrixFloat[] = {
            0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
            0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
            0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
            0,                    0,                    0,                    1,
        };
        const int32_t divisor = 256;
        NSUInteger matrixSize = sizeof(matrixFloat) / sizeof(matrixFloat[0]);
        int16_t matrix[matrixSize];
        for (NSUInteger i = 0; i < matrixSize; ++i) {
            matrix[i] = (int16_t)roundf(matrixFloat[i] * divisor);
        }
        vImageMatrixMultiply_ARGB8888(input, output, matrix, divisor, NULL, NULL, kvImageNoFlags);
        YY_SWAP(input, output);
    }
    
    UIImage *outputImage = nil;
    if (hasNewFunc) {
        CGImageRef effectCGImage = NULL;
        effectCGImage = vImageCreateCGImageFromBuffer(input, &format, &_yy_cleanupBuffer, NULL, kvImageNoAllocate, NULL);
        if (effectCGImage == NULL) {
            effectCGImage = vImageCreateCGImageFromBuffer(input, &format, NULL, NULL, kvImageNoFlags, NULL);
            free(input->data);
        }
        free(output->data);
        outputImage = [self _yy_mergeImage:image imageRef:effectCGImage tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];
        
        CGImageRelease(effectCGImage);
    } else {
        CGImageRef effectCGImage;
        UIImage *effectImage;
        if (input != &effect) effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (input == &effect) effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        effectCGImage = effectImage.CGImage;
        outputImage = [self _yy_mergeImage:image imageRef:effectCGImage tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];
    }
    return outputImage;
}


// Helper function to add tint and mask.
- (UIImage *)_yy_mergeImage:(UIImage *)image imageRef:(CGImageRef)effectCGImage
                  tintColor:(UIColor *)tintColor
              tintBlendMode:(CGBlendMode)tintBlendMode
                  maskImage:(UIImage *)maskImage
                     opaque:(BOOL)opaque {
    BOOL hasTint = tintColor != nil && CGColorGetAlpha(tintColor.CGColor) > __FLT_EPSILON__;
    BOOL hasMask = maskImage != nil;
    CGSize size = self.frame.size;
    CGRect rect = { CGPointZero, size };
    CGFloat scale = image.scale;
    
    if (!hasTint && !hasMask) {
        return [UIImage imageWithCGImage:effectCGImage];
    }
    
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -size.height);
    if (hasMask) {
        CGContextDrawImage(context, rect, image.CGImage);
        CGContextSaveGState(context);
        CGContextClipToMask(context, rect, maskImage.CGImage);
    }
    CGContextDrawImage(context, rect, effectCGImage);
    if (hasTint) {
        CGContextSaveGState(context);
        CGContextSetBlendMode(context, tintBlendMode);
        CGContextSetFillColorWithColor(context, tintColor.CGColor);
        CGContextFillRect(context, rect);
        CGContextRestoreGState(context);
    }
    if (hasMask) {
        CGContextRestoreGState(context);
    }
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return outputImage;
}

// CALayer Animation

- (void)layer:(CALayer *)layer addFadeAnimationWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve {
    if (duration <= 0) return;
    
    NSString *mediaFunction;
    switch (curve) {
        case UIViewAnimationCurveEaseInOut: {
            mediaFunction = kCAMediaTimingFunctionEaseInEaseOut;
        } break;
        case UIViewAnimationCurveEaseIn: {
            mediaFunction = kCAMediaTimingFunctionEaseIn;
        } break;
        case UIViewAnimationCurveEaseOut: {
            mediaFunction = kCAMediaTimingFunctionEaseOut;
        } break;
        case UIViewAnimationCurveLinear: {
            mediaFunction = kCAMediaTimingFunctionLinear;
        } break;
        default: {
            mediaFunction = kCAMediaTimingFunctionLinear;
        } break;
    }
    
    CATransition *transition = [CATransition animation];
    transition.duration = duration;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:mediaFunction];
    transition.type = kCATransitionFade;
    [layer addAnimation:transition forKey:kLayerAnimationKey];
}

@end
