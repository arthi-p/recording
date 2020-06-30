/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

#import "recordvc.h"
#import <AVKit/AVKit.h>
@interface recordvc ()

@end

@implementation recordvc

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


-(void)convertVideoToLowQuailtyWithInputURL:(AVAsset *)inputURL
                               outputURL:(NSURL*)outputURL
{
//setup video writer
  AVAsset *videoAsset = inputURL;

AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

CGSize videoSize = videoTrack.naturalSize;

NSDictionary *videoWriterCompressionSettings =  [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:810000], AVVideoAverageBitRateKey, nil];

  NSDictionary *videoWriterSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecTypeH264, AVVideoCodecKey, videoWriterCompressionSettings, AVVideoCompressionPropertiesKey, [NSNumber numberWithFloat:videoSize.width], AVVideoWidthKey, [NSNumber numberWithFloat:videoSize.height], AVVideoHeightKey, nil];

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
//               [videoWriter finishWritingWithCompletionHandler:^(){
//                                                  // [self sendMovieFileAtURL:outputURL];
//                                               }];

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
                                    // [self sendMovieFileAtURL:outputURL];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
