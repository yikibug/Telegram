#import "TGVideoMessageViewModel.h"

#import "TGVideoMediaAttachment.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGImageUtils.h"

#import "TGMessage.h"

#import "TGModernImageViewModel.h"
#import "TGMessageImageViewModel.h"
#import "TGModernRemoteImageViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernLabelViewModel.h"
#import "TGModernTextViewModel.h"

#import "TGModernRemoteImageView.h"
#import "TGModernRemoteImageViewModel.h"
#import "TGModernColorViewModel.h"
#import "TGInstantPreviewTouchAreaModel.h"
#import "TGModernButtonViewModel.h"

#import "TGReusableLabel.h"

#import "TGMessageImageView.h"

@interface TGVideoMessageViewModel ()
{
    TGVideoMediaAttachment *_video;
    int _videoSize;
    
    bool _progressVisible;
    
    CGPoint _boundOffset;
    
    int _messageLifetime;
}

@end

@implementation TGVideoMessageViewModel

- (NSString *)filePathForVideoId:(int64_t)videoId local:(bool)local
{
    static NSString *videosDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
        videosDirectory = [documentsDirectory stringByAppendingPathComponent:@"video"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:videosDirectory])
            [[NSFileManager defaultManager] createDirectoryAtPath:videosDirectory withIntermediateDirectories:true attributes:nil error:nil];
    });
    
    return [videosDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%@%" PRIx64 ".mov", local ? @"local" : @"remote", videoId]];
}

- (instancetype)initWithMessage:(TGMessage *)message imageInfo:(TGImageInfo *)imageInfo video:(TGVideoMediaAttachment *)video author:(TGUser *)author context:(TGModernViewContext *)context
{
    TGImageInfo *previewImageInfo = imageInfo;
    
    NSString *legacyVideoFilePath = [self filePathForVideoId:video.videoId != 0 ? video.videoId : video.localVideoId local:video.videoId == 0];
    NSString *legacyThumbnailCacheUri = [imageInfo closestImageUrlWithSize:CGSizeZero resultingSize:NULL];
    
    if (video.videoId != 0 || video.localVideoId != 0)
    {
        previewImageInfo = [[TGImageInfo alloc] init];
        
        NSMutableString *previewUri = [[NSMutableString alloc] initWithString:@"video-thumbnail://?"];
        if (video.videoId != 0)
            [previewUri appendFormat:@"id=%" PRId64 "", video.videoId];
        else
            [previewUri appendFormat:@"local-id=%" PRId64 "", video.localVideoId];
        
        CGSize thumbnailSize = CGSizeZero;
        CGSize renderSize = CGSizeZero;
        [TGImageMessageViewModel calculateImageSizesForImageSize:video.dimensions thumbnailSize:&thumbnailSize renderSize:&renderSize];
        
        [previewUri appendFormat:@"&width=%d&height=%d&renderWidth=%d&renderHeight=%d", (int)thumbnailSize.width, (int)thumbnailSize.height, (int)renderSize.width, (int)renderSize.height];
        
        [previewUri appendFormat:@"&legacy-video-file-path=%@", legacyVideoFilePath];
        if (legacyThumbnailCacheUri != nil)
            [previewUri appendFormat:@"&legacy-thumbnail-cache-url=%@", legacyThumbnailCacheUri];
        
        if (message.messageLifetime != 0)
            [previewUri appendString:@"&secret=1"];
        
        [previewImageInfo addImageWithSize:renderSize url:previewUri];
    }
    
    self = [super initWithMessage:message imageInfo:previewImageInfo author:author context:context];
    if (self != nil)
    {
        static UIImage *dateBackgroundImage = nil;
        static UIImage *videoIconImage = nil;
        static TGTelegraphConversationMessageAssetsSource *assetsSource = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            dateBackgroundImage = [[UIImage imageNamed:@"ModernMessageImageDateBackground.png"] stretchableImageWithLeftCapWidth:9 topCapHeight:9];
            videoIconImage = [UIImage imageNamed:@"ModernMessageVideoIcon.png"];
            
            assetsSource = [TGTelegraphConversationMessageAssetsSource instance];
        });
        
        _video = video;
        [_video.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:&_videoSize];
        
        _messageLifetime = message.messageLifetime;
        
        if (_messageLifetime != 0)
        {
            self.isSecret = true;
            
            if (message.outgoing)
                self.previewEnabled = false;
            else
                [self enableInstantPreview];
        }
        
        int minutes = video.duration / 60;
        int seconds = video.duration % 60;
        
        if (self.isSecret)
            [self.imageModel setAdditionalDataString:[self defaultAdditionalDataString]];
        else
            [self.imageModel setAdditionalDataString:[[NSString alloc] initWithFormat:@"%d:%02d", minutes, seconds]];
    }
    return self;
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage
{
    [super updateMessage:message viewStorage:viewStorage];
    
    TGVideoMediaAttachment *video = nil;
    
    
    if (video != nil)
    {
        TGImageInfo *previewImageInfo = video.thumbnailInfo;
        
        NSString *legacyVideoFilePath = [self filePathForVideoId:video.videoId != 0 ? video.videoId : video.localVideoId local:video.videoId == 0];
        NSString *legacyThumbnailCacheUri = [video.thumbnailInfo closestImageUrlWithSize:CGSizeZero resultingSize:NULL];
        
        if (video.videoId != 0 || video.localVideoId != 0)
        {
            previewImageInfo = [[TGImageInfo alloc] init];
            
            NSMutableString *previewUri = [[NSMutableString alloc] initWithString:@"video-thumbnail://?"];
            if (video.videoId != 0)
                [previewUri appendFormat:@"id=%" PRId64 "", video.videoId];
            else
                [previewUri appendFormat:@"local-id=%" PRId64 "", video.localVideoId];
            
            CGSize thumbnailSize = CGSizeZero;
            CGSize renderSize = CGSizeZero;
            [TGImageMessageViewModel calculateImageSizesForImageSize:video.dimensions thumbnailSize:&thumbnailSize renderSize:&renderSize];
            
            [previewUri appendFormat:@"&width=%d&height=%d&renderWidth=%d&renderHeight=%d", (int)thumbnailSize.width, (int)thumbnailSize.height, (int)renderSize.width, (int)renderSize.height];
            
            [previewUri appendFormat:@"&legacy-video-file-path=%@", legacyVideoFilePath];
            if (legacyThumbnailCacheUri != nil)
                [previewUri appendFormat:@"&legacy-thumbnail-cache-url=%@", legacyThumbnailCacheUri];
            
            if (message.messageLifetime != 0)
                [previewUri appendString:@"&secret=1"];
            
            [previewImageInfo addImageWithSize:renderSize url:previewUri];
        }
        
        [self updateImageInfo:previewImageInfo];
    }
}

- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    //_touchAreaModel.touchesBeganAction = mediaIsAvailable ? @"openMediaRequested" : @"mediaDownloadRequested";
    
    [super updateMediaAvailability:mediaIsAvailable viewStorage:viewStorage];
}

- (void)updateProgress:(bool)progressVisible progress:(float)progress viewStorage:(TGModernViewStorage *)viewStorage
{
    _progressVisible = progressVisible;
    
    NSString *labelText = nil;
    
    if (progressVisible)
    {
        if (_videoSize < 1024 * 1024)
        {
            labelText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Conversation.DownloadProgressKilobytes"), (int)(_videoSize * progress / 1024), (int)(_videoSize / 1024)];
        }
        else
        {
            labelText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Conversation.DownloadProgressMegabytes"), (float)_videoSize * progress / (1024 * 1024), (float)_videoSize / (1024 * 1024)];
        }
    }
    else
    {
        if (self.isSecret)
            labelText = [self defaultAdditionalDataString];
        else
        {
            int minutes = _video.duration / 60;
            int seconds = _video.duration % 60;
            labelText = [[NSString alloc] initWithFormat:@"%d:%02d", minutes, seconds];
        }
    }
    
    [self.imageModel setAdditionalDataString:labelText];
    
    [super updateProgress:progressVisible progress:progress viewStorage:viewStorage];
}

- (NSString *)filterForMessage:(TGMessage *)message imageSize:(CGSize)imageSize sourceSize:(CGSize)sourceSize
{
    if (message.messageLifetime == 0)
        return [super filterForMessage:message imageSize:imageSize sourceSize:sourceSize];
    
    return [[NSString alloc] initWithFormat:@"%@:%dx%d,%dx%d", @"secretAttachmentImageOutgoing", (int)imageSize.width, (int)imageSize.height, (int)sourceSize.width, (int)sourceSize.height];
}

- (CGSize)minimumImageSizeForMessage:(TGMessage *)message
{
    if (message.messageLifetime == 0)
        return [super minimumImageSizeForMessage:message];
    
    return CGSizeMake(120, 120);
}

- (bool)instantPreviewGesture
{
    return _messageLifetime != 0;
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    _boundOffset = itemPosition;
    
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    _boundOffset = CGPointZero;
    
    [super bindViewToContainer:container viewStorage:viewStorage];
}

- (int)defaultOverlayActionType
{
    if (self.isSecret)
        return [super defaultOverlayActionType];
    
    return TGMessageImageViewOverlayPlay;
}

@end
