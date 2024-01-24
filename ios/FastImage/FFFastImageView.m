#import "FFFastImageView.h"
#import <SDWebImage/UIImage+MultiFormat.h>
#import <SDWebImage/UIView+WebCache.h>

@interface FFFastImageView ()

@property(nonatomic, assign) BOOL hasSentOnLoadStart;
@property(nonatomic, assign) BOOL hasCompleted;
@property(nonatomic, assign) BOOL hasErrored;
// Whether the latest change of props requires the image to be reloaded
@property(nonatomic, assign) BOOL needsReload;

@property(nonatomic, strong) NSDictionary* onLoadEvent;

@end

@implementation FFFastImageView

- (id) init {
    self = [super init];
    self.resizeMode = RCTResizeModeCover;
    self.clipsToBounds = YES;
    return self;
}

- (void) setResizeMode: (RCTResizeMode)resizeMode {
    if (_resizeMode != resizeMode) {
        _resizeMode = resizeMode;
        self.contentMode = (UIViewContentMode) resizeMode;
    }
}

- (void) setOnFastImageLoadEnd: (RCTDirectEventBlock)onFastImageLoadEnd {
    _onFastImageLoadEnd = onFastImageLoadEnd;
    if (self.hasCompleted) {
        _onFastImageLoadEnd(@{});
    }
}

- (void) setOnFastImageLoad: (RCTDirectEventBlock)onFastImageLoad {
    _onFastImageLoad = onFastImageLoad;
    if (self.hasCompleted) {
        _onFastImageLoad(self.onLoadEvent);
    }
}

- (void) setOnFastImageError: (RCTDirectEventBlock)onFastImageError {
    _onFastImageError = onFastImageError;
    if (self.hasErrored) {
        _onFastImageError(@{});
    }
}

- (void) setOnFastImageLoadStart: (RCTDirectEventBlock)onFastImageLoadStart {
    if (_source && !self.hasSentOnLoadStart) {
        _onFastImageLoadStart = onFastImageLoadStart;
        onFastImageLoadStart(@{});
        self.hasSentOnLoadStart = YES;
    } else {
        _onFastImageLoadStart = onFastImageLoadStart;
        self.hasSentOnLoadStart = NO;
    }
}

- (void) setImageColor: (UIColor*)imageColor {
    if (imageColor != nil) {
        _imageColor = imageColor;
        if (super.image) {
            super.image = [self makeImage: super.image withTint: self.imageColor];
        }
    }
}

- (void) setHexagonMaskEnabled: (BOOL)hexagonMaskEnabled {
    if (hexagonMaskEnabled != nil) {
        _hexagonMaskEnabled = hexagonMaskEnabled;
        if (super.image) {
            super.image = [self createRoundedHexagonMaskForImage: super.image];
        }
    }
}

- (UIImage*) makeImage: (UIImage*)image withTint: (UIColor*)color {
    UIImage* newImage = [image imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
    UIGraphicsBeginImageContextWithOptions(image.size, NO, newImage.scale);
    [color set];
    [newImage drawInRect: CGRectMake(0, 0, image.size.width, newImage.size.height)];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void) setImage: (UIImage*)image {
    if (self.imageColor != nil) {
        super.image = [self makeImage: image withTint: self.imageColor];
    } else if(self.hexagonMaskEnabled) {
        super.image = [self createRoundedHexagonMaskForImage: image];
    }
    else {
        super.image = image;
    }
}


- (UIImage *)createRoundedHexagonMaskForImage:(UIImage *)image {
		// Создаем новый контекст с размерами изображения
	UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0);
	CGContextRef context = UIGraphicsGetCurrentContext();


		// Рисуем шестиугольник
	CGFloat centerX = image.size.width / 2;
	CGFloat centerY = image.size.height / 2;
	CGFloat radius = MIN(image.size.width, image.size.height) / 2;
	CGFloat angle = 2.0 * M_PI / 6.0; // 360 degrees divided by number of sides (6 for hexagon)
	CGFloat cornerRadius = self.superview.bounds.size.width; // Adjust as needed

	CGContextMoveToPoint(context, centerX + radius * sinf(0 * angle), centerY - radius * cosf(0 * angle));

	for (int i = 1; i <= 7; ++i) {
		CGFloat x1 = centerX + radius * sinf((i - 1) * angle);
		CGFloat y1 = centerY - radius * cosf((i - 1) * angle);
		CGFloat x2 = centerX + radius * sinf(i * angle);
		CGFloat y2 = centerY - radius * cosf(i * angle);
		CGContextAddArcToPoint(context, x1, y1, x2, y2, cornerRadius);
	}


		// Обрезаем изображение по шестиугольнику
	CGContextClip(context);

		// Рисуем изображение
	[image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];

		// Получаем новое изображение
	UIImage *maskedImage = UIGraphicsGetImageFromCurrentImageContext();

		// Завершаем контекст
	UIGraphicsEndImageContext();

	return maskedImage;
}

- (void) sendOnLoad: (UIImage*)image {
    self.onLoadEvent = @{
            @"width": [NSNumber numberWithDouble: image.size.width],
            @"height": [NSNumber numberWithDouble: image.size.height]
    };
    if (self.onFastImageLoad) {
        self.onFastImageLoad(self.onLoadEvent);
    }
}

- (void) setSource: (FFFastImageSource*)source {
    if (_source != source) {
        _source = source;
        _needsReload = YES;
    }
}

- (void) setDefaultSource: (UIImage*)defaultSource {
    if (_defaultSource != defaultSource) {
        _defaultSource = defaultSource;
        _needsReload = YES;
    }
}

- (void) didSetProps: (NSArray<NSString*>*)changedProps {
    if (_needsReload) {
        [self reloadImage];
    }
}

- (void) reloadImage {
    _needsReload = NO;

    if (_source) {
        // Load base64 images.
        NSString* url = [_source.url absoluteString];
        if (url && [url hasPrefix: @"data:image"]) {
            if (self.onFastImageLoadStart) {
                self.onFastImageLoadStart(@{});
                self.hasSentOnLoadStart = YES;
            } else {
                self.hasSentOnLoadStart = NO;
            }
            // Use SDWebImage API to support external format like WebP images
            UIImage* image = [UIImage sd_imageWithData: [NSData dataWithContentsOfURL: _source.url]];
            [self setImage: image];
            if (self.onFastImageProgress) {
                self.onFastImageProgress(@{
                        @"loaded": @(1),
                        @"total": @(1)
                });
            }
            self.hasCompleted = YES;
            [self sendOnLoad: image];

            if (self.onFastImageLoadEnd) {
                self.onFastImageLoadEnd(@{});
            }
            return;
        }

        // Set headers.
        NSDictionary* headers = _source.headers;
        SDWebImageDownloaderRequestModifier* requestModifier = [SDWebImageDownloaderRequestModifier requestModifierWithBlock: ^NSURLRequest* _Nullable (NSURLRequest* _Nonnull request) {
            NSMutableURLRequest* mutableRequest = [request mutableCopy];
            for (NSString* header in headers) {
                NSString* value = headers[header];
                [mutableRequest setValue: value forHTTPHeaderField: header];
            }
            return [mutableRequest copy];
        }];
        SDWebImageContext* context = @{SDWebImageContextDownloadRequestModifier: requestModifier};

        // Set priority.
        SDWebImageOptions options = SDWebImageRetryFailed | SDWebImageHandleCookies;
        switch (_source.priority) {
            case FFFPriorityLow:
                options |= SDWebImageLowPriority;
                break;
            case FFFPriorityNormal:
                // Priority is normal by default.
                break;
            case FFFPriorityHigh:
                options |= SDWebImageHighPriority;
                break;
        }

        switch (_source.cacheControl) {
            case FFFCacheControlWeb:
                options |= SDWebImageRefreshCached;
                break;
            case FFFCacheControlCacheOnly:
                options |= SDWebImageFromCacheOnly;
                break;
            case FFFCacheControlImmutable:
                break;
        }

        if (self.onFastImageLoadStart) {
            self.onFastImageLoadStart(@{});
            self.hasSentOnLoadStart = YES;
        } else {
            self.hasSentOnLoadStart = NO;
        }
        self.hasCompleted = NO;
        self.hasErrored = NO;

        [self downloadImage: _source options: options context: context];
    } else if (_defaultSource) {
        [self setImage: _defaultSource];
    }
}

- (void) downloadImage: (FFFastImageSource*)source options: (SDWebImageOptions)options context: (SDWebImageContext*)context {
    __weak typeof(self) weakSelf = self; // Always use a weak reference to self in blocks
    [self sd_setImageWithURL: _source.url
            placeholderImage: _defaultSource
                     options: options
                     context: context
                    progress: ^(NSInteger receivedSize, NSInteger expectedSize, NSURL* _Nullable targetURL) {
                        if (weakSelf.onFastImageProgress) {
                            weakSelf.onFastImageProgress(@{
                                    @"loaded": @(receivedSize),
                                    @"total": @(expectedSize)
                            });
                        }
                    } completed: ^(UIImage* _Nullable image,
                    NSError* _Nullable error,
                    SDImageCacheType cacheType,
                    NSURL* _Nullable imageURL) {
                if (error) {
                    weakSelf.hasErrored = YES;
                    if (weakSelf.onFastImageError) {
                        weakSelf.onFastImageError(@{});
                    }
                    if (weakSelf.onFastImageLoadEnd) {
                        weakSelf.onFastImageLoadEnd(@{});
                    }
                } else {
                    weakSelf.hasCompleted = YES;
                    [weakSelf sendOnLoad: image];
                    if (weakSelf.onFastImageLoadEnd) {
                        weakSelf.onFastImageLoadEnd(@{});
                    }
                }
            }];
}

- (void) dealloc {
    [self sd_cancelCurrentImageLoad];
}

@end
