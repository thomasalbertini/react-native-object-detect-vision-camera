#import <Foundation/Foundation.h>
#import <TensorFlowLiteTaskVision/TensorFlowLiteTaskVision.h>
#import <VisionCamera/Frame.h>
#import <VisionCamera/FrameProcessorPlugin.h>

@interface objectDetectVisionCameraPlugin : NSObject
+ (TFLObjectDetector*)detector:(NSDictionary*)config;
+ (UIImage*)resizeFrameToUIimage:(Frame*)frame;
@end

@implementation objectDetectVisionCameraPlugin

+ (TFLObjectDetector*)detector:(NSDictionary*)config {
  static TFLObjectDetector* detector = nil;
  if (detector == nil) {
    NSString* filename = config[@"modelFile"];
    NSString* extension = [filename pathExtension];
    NSString* modelName = [filename stringByDeletingPathExtension];
    NSString* modelPath = [[NSBundle mainBundle] pathForResource:modelName
                                                          ofType:extension];
    
      NSLog(@"Model path: %@", modelPath);
    

    NSNumber* scoreThreshold = config[@"scoreThreshold"];
    NSNumber* maxResults = config[@"maxResults"];
    NSNumber* numThreads = config[@"numThreads"];
    TFLObjectDetectorOptions* options =
        [[TFLObjectDetectorOptions alloc] initWithModelPath:modelPath];
    options.classificationOptions.scoreThreshold =
        scoreThreshold.floatValue;
    options.classificationOptions.maxResults =
        maxResults.intValue;
    options.baseOptions.computeSettings.cpuSettings.numThreads = numThreads.intValue;
      NSError *detectorError;
      detector = [TFLObjectDetector objectDetectorWithOptions:options error:&detectorError];
      if (!detector) {
          NSLog(@"Detector initialization failed with error: %@", detectorError);
      }
      
      NSLog(@"Model path options: %@", options);
  }
    NSLog(@"Model path detector: %@", detector);
    
    return detector;
}

+ (UIImage *)resizeFrameToUIimage:(Frame *)frame {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(frame.buffer);

    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:[ciImage extent]];
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);

    CGSize newSize = CGSizeMake(150, 150);
    CGRect rect = CGRectMake(0, 0, newSize.width, newSize.height);

    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0);
    [uiImage drawInRect:rect];

    // Normalize the image pixel values
    UIGraphicsEndImageContext();
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0);
    [newImage drawInRect:rect];

    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    TFLImage *tflImage = [[TFLImage alloc] initWithImage:normalizedImage];

        return tflImage;

    return normalizedImage;
}

- (id _Nullable)callback:(Frame* _Nonnull)frame withArguments:(NSDictionary* _Nullable)arguments {
NSDictionary* config = [args objectAtIndex:0];

  UIImageOrientation orientation = frame.orientation;

  UIImage* resizedImageResult =
      [RealtimeObjectDetectionProcessorPlugin resizeFrameToUIimage:frame];
  GMLImage* gmlImage = [[GMLImage alloc] initWithImage:resizedImageResult];
  gmlImage.orientation = orientation;

  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(frame.buffer);

  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);

  NSError* error;
  TFLDetectionResult* detectionResult = [[RealtimeObjectDetectionProcessorPlugin
      detector:config] detectWithGMLImage:gmlImage error:&error];

    NSLog(@"Something To Print");
    NSLog(@"detection results: %@", detectionResult);
    
  if (!detectionResult) {
    return @[];
  }
  NSMutableArray* results =
      [NSMutableArray arrayWithCapacity:detectionResult.detections.count];
  for (TFLDetection* detection in detectionResult.detections) {
    NSMutableArray* labels =
        [NSMutableArray arrayWithCapacity:detection.categories.count];

    if (detection.categories.count != 0) {
      for (TFLCategory* category in detection.categories) {
        [labels addObject:@{
          @"index" : [NSNumber numberWithLong:category.index],
          @"label" : category.label,
          @"confidence" : [NSNumber numberWithFloat:category.score]
        }];
      }

      [results addObject:@{
        @"width" : [NSNumber numberWithFloat:(detection.boundingBox.size.width /
                                              gmlImage.width)],
        @"height" :
            [NSNumber numberWithFloat:(detection.boundingBox.size.height /
                                       gmlImage.height)],
        @"top" : [NSNumber
            numberWithFloat:(detection.boundingBox.origin.y / gmlImage.height)],
        @"left" : [NSNumber
            numberWithFloat:(detection.boundingBox.origin.x / gmlImage.width)],
        @"frameRotation" : [NSNumber numberWithFloat:frame.orientation],
        @"labels" : labels
      }];
    }
  }

  return results;
}

VISION_EXPORT_FRAME_PROCESSOR(objectDetectVisionCameraPlugin, detectObjects)

@end