- (void)convertVideoToLowQuailtyWithInputURL:(NSURL*)inputURL
                               outputURL:(NSURL*)outputURL
{
//setup video writer
AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:inputURL options:nil];

AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

CGSize videoSize = videoTrack.naturalSize;

NSDictionary *videoWriterCompressionSettings =  [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1250000], AVVideoAverageBitRateKey, nil];

NSDictionary *videoWriterSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey, videoWriterCompressionSettings, AVVideoCompressionPropertiesKey, [NSNumber numberWithFloat:videoSize.width], AVVideoWidthKey, [NSNumber numberWithFloat:videoSize.height], AVVideoHeightKey, nil];

AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
                                         assetWriterInputWithMediaType:AVMediaTypeVideo
                                         outputSettings:videoWriterSettings];

videoWriterInput.expectsMediaDataInRealTime = YES;

videoWriterInput.transform = videoTrack.preferredTransform;

AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:nil];

[videoWriter addInput:videoWriterInput];

//setup video reader
NSDictionary *videoReaderSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];

AVAssetReaderTrackOutput *videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:videoReaderSettings];

AVAssetReader *videoReader = [[AVAssetReader alloc] initWithAsset:videoAsset error:nil];

[videoReader addOutput:videoReaderOutput];

//setup audio writer
AVAssetWriterInput* audioWriterInput = [AVAssetWriterInput
                                        assetWriterInputWithMediaType:AVMediaTypeAudio
                                        outputSettings:nil];

audioWriterInput.expectsMediaDataInRealTime = NO;

[videoWriter addInput:audioWriterInput];

//setup audio reader
AVAssetTrack* audioTrack = [[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];

AVAssetReaderOutput *audioReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];

AVAssetReader *audioReader = [AVAssetReader assetReaderWithAsset:videoAsset error:nil];

[audioReader addOutput:audioReaderOutput];

[videoWriter startWriting];

//start writing from video reader
[videoReader startReading];

[videoWriter startSessionAtSourceTime:kCMTimeZero];

dispatch_queue_t processingQueue = dispatch_queue_create("processingQueue1", NULL);

[videoWriterInput requestMediaDataWhenReadyOnQueue:processingQueue usingBlock:
 ^{

     while ([videoWriterInput isReadyForMoreMediaData]) {

         CMSampleBufferRef sampleBuffer;

         if ([videoReader status] == AVAssetReaderStatusReading &&
             (sampleBuffer = [videoReaderOutput copyNextSampleBuffer])) {

             [videoWriterInput appendSampleBuffer:sampleBuffer];
             CFRelease(sampleBuffer);
         }

         else {

             [videoWriterInput markAsFinished];

             if ([videoReader status] == AVAssetReaderStatusCompleted) {

                 //start writing from audio reader
                 [audioReader startReading];

                 [videoWriter startSessionAtSourceTime:kCMTimeZero];

                 dispatch_queue_t processingQueue = dispatch_queue_create("processingQueue2", NULL);

                 [audioWriterInput requestMediaDataWhenReadyOnQueue:processingQueue usingBlock:^{

                     while (audioWriterInput.readyForMoreMediaData) {

                         CMSampleBufferRef sampleBuffer;

                         if ([audioReader status] == AVAssetReaderStatusReading &&
                             (sampleBuffer = [audioReaderOutput copyNextSampleBuffer])) {

                            [audioWriterInput appendSampleBuffer:sampleBuffer];
                                    CFRelease(sampleBuffer);
                         }

                         else {

                             [audioWriterInput markAsFinished];

                             if ([audioReader status] == AVAssetReaderStatusCompleted) {

                                 [videoWriter finishWritingWithCompletionHandler:^(){
                                     [self sendMovieFileAtURL:outputURL];
                                 }];

                             }
                         }
                     }

                 }
                  ];
             }
         }
     }
 }
 ];
}
