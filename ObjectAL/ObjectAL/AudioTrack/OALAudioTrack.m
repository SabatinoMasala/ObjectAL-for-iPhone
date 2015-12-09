//
//  OALAudioTrack.m
//  ObjectAL
//
//  Created by Karl Stenerud on 10-08-21.
//
//  Copyright (c) 2009 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// Attribution is not required, but appreciated :)
//

#import "OALAudioTrack.h"
#import "OALAudioActions.h"
#import "OALAudioTracks.h"
#import "OALTools.h"
#import "OALUtilityActions.h"
#import "ObjectALMacros.h"

#pragma mark Asynchronous Operations

/** \cond */
/**
 * (INTERNAL USE) NSOperation for running an audio operation asynchronously.
 */
@interface OAL_AsyncAudioTrackOperation: NSOperation
{
	/** The audio track object to perform the operation on */
	OALAudioTrack* audioTrack;
	/** The URL of the sound file to play */
	NSURL* url;
	/** The seekTime of the sound file */
	NSTimeInterval seekTime;
	/** The target to inform when the operation completes */
	id target;
	/** The selector to call when the operation completes */
	SEL selector;
}

/** (INTERNAL USE) Create a new Asynchronous Operation.
 *
 * @param track the audio track to perform the operation on.
 * @param seekTime the position in the file to start playing at.
 * @param url the URL containing the sound file.
 * @param target the target to inform when the operation completes.
 * @param selector the selector to call when the operation completes.
 */ 
+ (id) operationWithTrack:(OALAudioTrack*) track url:(NSURL*) url seekTime:(NSTimeInterval)seekTime target:(id) target selector:(SEL) selector;

/** (INTERNAL USE) Initialize an Asynchronous Operation.
 *
 * @param track the audio track to perform the operation on.
 * @param seekTime the position in the file to start playing at.
 * @param url the URL containing the sound file.
 * @param target the target to inform when the operation completes.
 * @param selector the selector to call when the operation completes.
 */ 
- (id) initWithTrack:(OALAudioTrack*) track url:(NSURL*) url seekTime:(NSTimeInterval)seekTime target:(id) target selector:(SEL) selector;

@end

@implementation OAL_AsyncAudioTrackOperation

+ (id) operationWithTrack:(OALAudioTrack*) track url:(NSURL*) url seekTime:(NSTimeInterval)seekTime target:(id) target selector:(SEL) selector
{
	return [[self alloc] initWithTrack:track url:url seekTime:seekTime target:target selector:selector];
}

- (id) initWithTrack:(OALAudioTrack*) track url:(NSURL*) urlIn seekTime:(NSTimeInterval)seekTimeIn target:(id) targetIn selector:(SEL) selectorIn
{
	if(nil != (self = [super init]))
	{
		audioTrack = track;
		url = urlIn;
		seekTime = seekTimeIn;
		target = targetIn;
		selector = selectorIn;
	}
	return self;
}

@end


/**
 * (INTERNAL USE) NSOperation for playing an audio file asynchronously.
 */
@interface OAL_AsyncAudioTrackPlayOperation : OAL_AsyncAudioTrackOperation
{
	/** The number of times to loop during playback */
	NSInteger loops;
}

/**
 * (INTERNAL USE) Create an asynchronous play operation.
 *
 * @param track the audio track to perform the operation on.
 * @param url The URL of the file to play.
 * @param loops The number of times to loop playback (-1 = forever).
 * @param target The target to inform when playback finishes.
 * @param selector the selector to call when playback finishes.
 * @return a new operation.
 */
+ (id) operationWithTrack:(OALAudioTrack*) track url:(NSURL*) url loops:(NSInteger) loops target:(id) target selector:(SEL) selector;

/**
 * (INTERNAL USE) Initialize an asynchronous play operation.
 *
 * @param track the audio track to perform the operation on.
 * @param url The URL of the file to play.
 * @param loops The number of times to loop playback (-1 = forever).
 * @param target The target to inform when playback finishes.
 * @param selector the selector to call when playback finishes.
 * @return The initialized operation.
 */
- (id) initWithTrack:(OALAudioTrack*) track url:(NSURL*) url loops:(NSInteger) loops target:(id) target selector:(SEL) selector;

@end


@implementation OAL_AsyncAudioTrackPlayOperation

+ (id) operationWithTrack:(OALAudioTrack*) track url:(NSURL*) url loops:(NSInteger) loops target:(id) target selector:(SEL) selector
{
	return [[self alloc] initWithTrack:track url:url loops:loops target:target selector:selector];
}

- (id) initWithTrack:(OALAudioTrack*) track url:(NSURL*) urlIn loops:(NSInteger) loopsIn target:(id) targetIn selector:(SEL) selectorIn
{
	if(nil != (self = [super initWithTrack:track url:urlIn seekTime:0 target:targetIn selector:selectorIn]))
	{
		loops = loopsIn;
	}
	return self;
}

- (id) initWithTrack:(OALAudioTrack*) track url:(NSURL*) urlIn target:(id) targetIn selector:(SEL) selectorIn
{
	return [self initWithTrack:track url:urlIn loops:0 target:targetIn selector:selectorIn];
}

- (void)main
{
	[audioTrack playUrl:url loops:loops];
	[target performSelectorOnMainThread:selector withObject:audioTrack waitUntilDone:NO];
}

@end


/**
 * (INTERNAL USE) NSOperation for preloading an audio file asynchronously.
 */
@interface OAL_AsyncAudioTrackPreloadOperation : OAL_AsyncAudioTrackOperation
{
}

@end


@implementation OAL_AsyncAudioTrackPreloadOperation

- (void)main
{
	[audioTrack preloadUrl:url seekTime:seekTime];
	[target performSelectorOnMainThread:selector withObject:audioTrack waitUntilDone:NO];
}

@end

#pragma mark -
#pragma mark Private Methods

/**
 * (INTERNAL USE) Private interface to OALAudioTrack.
 */
@interface OALAudioTrack (Private)

/** (INTERNAL USE) Called by SuspendHandler.
 */
- (void) setSuspended:(bool) value;

@end
/** \endcond */

#pragma mark -
#pragma mark AudioTrack

@implementation OALAudioTrack

#pragma mark Object Management

+ (id) track
{
	return [[self alloc] init];
}

- (id) init
{
	if(nil != (self = [super init]))
	{
		OAL_LOG_DEBUG(@"%@: Init", self);
		
		suspendHandler = [[OALSuspendHandler alloc] initWithTarget:self selector:@selector(setSuspended:)];

		operationQueue = [[NSOperationQueue alloc] init];
		operationQueue.maxConcurrentOperationCount = 1;
		gain = 1.0f;
		numberOfLoops = 0;
		currentTime = 0.0;
		
		[[OALAudioTracks sharedInstance] notifyTrackInitializing:self];
		[[OALAudioTracks sharedInstance] addSuspendListener:self];
	}
	return self;
}

- (void) dealloc
{
	OAL_LOG_DEBUG(@"%@: Dealloc", self);
	[[OALAudioTracks sharedInstance] removeSuspendListener:self];
	[[OALAudioTracks sharedInstance] notifyTrackDeallocating:self];

    player.delegate = nil;
    [player stop];

	[gainAction stopAction];
	[panAction stopAction];
}


- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@: %p: %@>", [self class], self, [currentlyLoadedUrl lastPathComponent]];
}

#pragma mark Properties

@synthesize currentlyLoadedUrl;

@synthesize autoPreload;

@synthesize preloaded;

- (id<AVAudioPlayerDelegate>) delegate
{
    return delegate;
}

- (void) setDelegate:(id<AVAudioPlayerDelegate>) value
{
    delegate = value;
}

- (float) pan
{
    return pan;
}

- (void) setPan:(float) value
{
	@synchronized(self)
	{
        pan = value;
        player.pan = pan;
	}
}

- (float) volume
{
	return self.gain;
}

- (float) gain
{
    return gain;
}

- (void) setVolume:(float) value
{
	self.gain = value;
}

- (void) setGain:(float) value
{
	@synchronized(self)
	{
		gain = value;
		if(muted)
		{
			value = 0;
		}
		player.volume = value;
	}
}

- (bool) muted
{
    return muted;
}

- (void) setMuted:(bool) value
{
	@synchronized(self)
	{
		muted = value;
		if(muted)
		{
			[self stopActions];
		}
		// Force a re-evaluation of gain.
		[self setGain:gain];
	}
}

- (NSInteger) numberOfLoops
{
    return numberOfLoops;
}

- (void) setNumberOfLoops:(NSInteger) value
{
	@synchronized(self)
	{
		player.numberOfLoops = numberOfLoops = value;
	}
}

- (bool) paused
{
    return paused;
}

- (void) setPaused:(bool) value
{
	@synchronized(self)
	{
		if(paused != value)
		{
			paused = value;
			if(paused)
			{
				OAL_LOG_DEBUG(@"%@: Pause", self);
				[player pause];
				if(playing)
				{
					[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:)
																		   withObject:[NSNotification notificationWithName:OALAudioTrackStoppedPlayingNotification object:self] waitUntilDone:NO];
				}
			}
			else if(playing)
			{
				OAL_LOG_DEBUG(@"%@: Unpause", self);
				playing = [player play];
				if(playing)
				{
					[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:)
																		   withObject:[NSNotification notificationWithName:OALAudioTrackStartedPlayingNotification object:self] waitUntilDone:NO];
				}
			}
		}
	}
}

@synthesize player;

@synthesize playing;

- (NSTimeInterval) currentTime
{
	@synchronized(self)
	{
		return (nil == player) ? currentTime : player.currentTime;
	}
}

- (void) setCurrentTime:(NSTimeInterval) value
{
	@synchronized(self)
	{
		currentTime = value;
		if(nil != player)
		{
			player.currentTime = currentTime;
		}
	}
}

- (NSTimeInterval) deviceCurrentTime
{
	@synchronized(self)
	{
        return player.deviceCurrentTime;
	}
}

- (NSTimeInterval) duration
{
	@synchronized(self)
	{
		return player.duration;
	}
}

- (NSUInteger) numberOfChannels
{
	@synchronized(self)
	{
		return player.numberOfChannels;
	}
}


#pragma mark Suspend Handler

- (void) addSuspendListener:(id<OALSuspendListener>) listenerIn
{
	[suspendHandler addSuspendListener:listenerIn];
}

- (void) removeSuspendListener:(id<OALSuspendListener>) listenerIn
{
	[suspendHandler removeSuspendListener:listenerIn];
}

- (bool) manuallySuspended
{
	return suspendHandler.manuallySuspended;
}

- (void) setManuallySuspended:(bool) value
{
	suspendHandler.manuallySuspended = value;
}

- (bool) interrupted
{
	return suspendHandler.interrupted;
}

- (void) setInterrupted:(bool) value
{
	suspendHandler.interrupted = value;
}

- (bool) suspended
{
	return suspendHandler.suspended;
}

- (void) setSuspended:(bool) value
{
	/* Suspend gets a bit complicated here.
	 * If multiple AVAudioPlayers are playing when an interrupt begins,
	 * only one of them will resume when the interrupt finishes.
	 * To counter this, we destroy the player and rebuild it on resume.
	 *
	 * Note: This has the unfortunate side effect that the OALAudioTrack
	 * using hardware playback on resume may not be the same one!
	 *
	 * TODO: Need to find a way to avoid this situation.
	 */
	@synchronized(self)
	{
        if(value)
        {
            if(preloaded)
            {
                currentTime = player.currentTime;
                if(self.playing)
                {
                    [player stop];
                }
            }
        }
        else
        {
            if(preloaded)
            {
                NSError* error;
                player = [[AVAudioPlayer alloc] initWithContentsOfURL:currentlyLoadedUrl error:&error];
                if(nil == player)
                {
                    OAL_LOG_ERROR(@"%@: Could not reload URL %@: %@",
                                  self, currentlyLoadedUrl, [error localizedDescription]);
                    player = nil;
                    preloaded = NO;
                    playing = NO;
                    paused = NO;
                    return;
                }

                player.volume = muted ? 0 : gain;
                player.numberOfLoops = numberOfLoops;
                player.meteringEnabled = meteringEnabled;
                player.delegate = self;
                player.pan = pan;

                player.currentTime = currentTime;

                if(![player prepareToPlay])
                {
                    OAL_LOG_ERROR(@"%@: Failed to prepareToPlay on resume: %@", self, currentlyLoadedUrl);
                    player = nil;
                    preloaded = NO;
                    playing = NO;
                    paused = NO;
                    return;
                }
                
                if(playing)
                {
                    playing = [player play];
                    if(paused)
                    {
                        [player pause];
                    }
                }
            }
        }
        
        
        /*
        if(value)
        {
            if(self.playing && !self.paused)
            {
                currentTime = player.currentTime;
                [player pause];
            }
        }
        else
        {
            if(self.playing && !self.paused)
            {
                player.currentTime = currentTime;
                [player play];
            }
        }
         */
    }
}


#pragma mark Playback

- (bool) preloadUrl:(NSURL*) url
{
	return [self preloadUrl:url seekTime:0];
}

- (bool) preloadUrl:(NSURL*) url seekTime:(NSTimeInterval)seekTime
{
	if(nil == url)
	{
		OAL_LOG_ERROR(@"%@: Cannot open NULL file / url", self);
		return NO;
	}
	
	@synchronized(self)
	{
		// Bug: No longer re-using AVAudioPlayer because of bugs when using multiple players.
		// Playing two tracks, then stopping one and starting it again will cause prepareToPlay to fail.
		
		bool wasPlaying = playing;

		[self stopActions];
		
		if(playing || paused)
		{
			[player stop];
		}

		if(wasPlaying)
		{
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackStoppedPlayingNotification object:self] waitUntilDone:NO];
		}
		
		NSError* error;
		player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
		if(nil == player)
		{
			OAL_LOG_ERROR(@"%@: Could not load URL %@: %@", self, url, [error localizedDescription]);
			return NO;
		}
		
		player.volume = muted ? 0 : gain;
		player.numberOfLoops = numberOfLoops;
		player.meteringEnabled = meteringEnabled;
		player.delegate = self;
        player.pan = pan;

		currentlyLoadedUrl = url;
		
		self.currentTime = seekTime;
		playing = NO;
		paused = NO;

		BOOL allOK = [player prepareToPlay];
		if(!allOK)
		{
			OAL_LOG_ERROR(@"%@: Failed to prepareToPlay: %@", self, url);
		}
		else
		{
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackSourceChangedNotification object:self] waitUntilDone:NO];
		}
		preloaded = allOK;
		return allOK;
	}
}

- (bool) preloadFile:(NSString*) path
{
	return [self preloadFile:path seekTime:0];
}

- (bool) preloadFile:(NSString*) path seekTime:(NSTimeInterval)seekTime
{
	return [self preloadUrl:[OALTools urlForPath:path] seekTime:seekTime];
}

- (bool) preloadUrlAsync:(NSURL*) url target:(id) target selector:(SEL) selector
{
	return [self preloadUrlAsync:url seekTime:0 target:target selector:selector];
}

- (bool) preloadUrlAsync:(NSURL*) url seekTime:(NSTimeInterval)seekTime target:(id) target selector:(SEL) selector
{
	@synchronized(self)
	{
		[operationQueue addOperation:[OAL_AsyncAudioTrackPreloadOperation operationWithTrack:self url:url seekTime:seekTime target:target selector:selector]];
		return NO;
	}
}

- (bool) preloadFileAsync:(NSString*) path target:(id) target selector:(SEL) selector
{
	return [self preloadFileAsync:path seekTime:0 target:target selector:selector];
}

- (bool) preloadFileAsync:(NSString*) path seekTime:(NSTimeInterval)seekTime target:(id) target selector:(SEL) selector
{
	return [self preloadUrlAsync:[OALTools urlForPath:path] seekTime:seekTime target:target selector:selector];
}

- (bool) playUrl:(NSURL*) url
{
	return [self playUrl:url loops:0];
}

- (bool) playUrl:(NSURL*) url loops:(NSInteger) loops
{
	@synchronized(self)
	{
		if([self preloadUrl:url])
		{
			self.numberOfLoops = loops;
			return [self play];
		}
		return NO;
	}
}

- (bool) playFile:(NSString*) path
{
	return [self playUrl:[OALTools urlForPath:path]];
}

- (bool) playFile:(NSString*) path loops:(NSInteger) loops
{
	return [self playUrl:[OALTools urlForPath:path] loops:loops];
}

- (void) playUrlAsync:(NSURL*) url target:(id) target selector:(SEL) selector
{
	[self playUrlAsync:url loops:0 target:target selector:selector];
}

- (void) playUrlAsync:(NSURL*) url loops:(NSInteger) loops target:(id) target selector:(SEL) selector
{
	[operationQueue addOperation:[OAL_AsyncAudioTrackPlayOperation operationWithTrack:self url:url loops:loops target:target selector:selector]];
}

- (void) playFileAsync:(NSString*) path target:(id) target selector:(SEL) selector
{
	[self playFileAsync:path loops:0 target:target selector:selector];
}

- (void) playFileAsync:(NSString*) path loops:(NSInteger) loops target:(id) target selector:(SEL) selector
{
	[self playUrlAsync:[OALTools urlForPath:path] loops:loops target:target selector:selector];
}

- (bool) play
{
	@synchronized(self)
	{
		[self stopActions];
        [player stop];
		player.currentTime = currentTime;
		player.volume = muted ? 0 : gain;
		player.numberOfLoops = numberOfLoops;
		paused = NO;
		playing = [player play];
        // Kick deviceCurrentTime so that it's valid next call
        [self deviceCurrentTime];
		if(playing)
		{
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackStartedPlayingNotification object:self] waitUntilDone:NO];
		}
		return playing;
	}
}

- (bool) playAtTime:(NSTimeInterval) time
{
	@synchronized(self)
	{
        [self stopActions];
        [player stop];
        player.currentTime = currentTime;
        player.volume = muted ? 0 : gain;
        player.numberOfLoops = numberOfLoops;
        paused = NO;
        playing = [player playAtTime:time];
        if(playing)
        {
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackStartedPlayingNotification object:self] waitUntilDone:NO];
        }
        return playing;
	}
}

- (bool) playAfterTrack:(OALAudioTrack*) track
{
    return [self playAfterTrack:track timeAdjust:0];
}

- (bool) playAfterTrack:(OALAudioTrack*) track timeAdjust:(NSTimeInterval) timeAdjust
{
    NSTimeInterval deviceTime = track.deviceCurrentTime;
    NSTimeInterval trackTimeRemaining = track.duration - track.currentTime;
    return [self playAtTime:deviceTime + trackTimeRemaining + timeAdjust];
}


- (void) stop
{
	@synchronized(self)
	{
		[self stopActions];
		[player stop];
		if(playing)
		{
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackStoppedPlayingNotification object:self] waitUntilDone:NO];
		}
		
		self.currentTime = 0;
		player.currentTime = 0;
		paused = NO;
		playing = NO;
		preloaded = NO;
	}
}

- (void) stopActions
{
	[self stopFade];
	[self stopPan];
}


- (void) fadeTo:(float) value
	   duration:(float) duration
		 target:(id) target
	   selector:(SEL) selector
{
	// Must always be synchronized
	@synchronized(self)
	{
		[self stopFade];
		gainAction = [OALSequentialActions actions:
                      [OALPropertyAction gainActionWithDuration:duration endValue:value],
                      [OALCallAction actionWithCallTarget:target selector:selector withObject:self],
                      nil];
		[gainAction runWithTarget:self];
	}
}

- (void) stopFade
{
	// Must always be synchronized
	@synchronized(self)
	{
		[gainAction stopAction];
		gainAction = nil;
	}
}

- (void) panTo:(float) value
	  duration:(float) duration
		target:(id) target
	  selector:(SEL) selector
{
    // Must always be synchronized
    @synchronized(self)
    {
        [self stopPan];
        panAction = [OALSequentialActions actions:
                     [OALPropertyAction panActionWithDuration:duration endValue:value],
                     [OALCallAction actionWithCallTarget:target selector:selector withObject:self],
                     nil];
        [panAction runWithTarget:self];
    }
}

- (void) stopPan
{
    // Must always be synchronized
    @synchronized(self)
    {
        [panAction stopAction];
        panAction = nil;
    }
}

- (void) clear
{
	@synchronized(self)
	{
		[self stopActions];
		currentlyLoadedUrl = nil;
		
		[player stop];
		player = nil;
		playing = NO;
		paused = NO;
		muted = NO;

		if(playing)
		{
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackStoppedPlayingNotification object:self] waitUntilDone:NO];
		}
		
		self.currentTime = 0;
	}
}


#pragma mark Metering

- (bool) meteringEnabled
{
    return meteringEnabled;
}

- (void) setMeteringEnabled:(bool) value
{
	@synchronized(self)
	{
		meteringEnabled = value;
		player.meteringEnabled = meteringEnabled;
	}
}

- (void) updateMeters
{
    [player updateMeters];
}

- (float) averagePowerForChannel:(NSUInteger)channelNumber
{
	@synchronized(self)
	{
		return [player averagePowerForChannel:channelNumber];
	}
}

- (float) peakPowerForChannel:(NSUInteger)channelNumber
{
	@synchronized(self)
	{
		return [player peakPowerForChannel:channelNumber];
	}
}


#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void) audioPlayerDecodeErrorDidOccur:(AVAudioPlayer*) playerIn error:(NSError*) error
{
	if([delegate respondsToSelector:@selector(audioPlayerDecodeErrorDidOccur:error:)])
	{
		[delegate audioPlayerDecodeErrorDidOccur:playerIn error:error];
	}
}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer*) playerIn successfully:(BOOL) flag
{
	@synchronized(self)
	{
		playing = NO;
		paused = NO;
		preloaded = NO;
		if(autoPreload)
		{
			preloaded = [player prepareToPlay];
			if(!preloaded)
			{
				OAL_LOG_ERROR(@"%@: Failed to prepareToPlay: %@", self, currentlyLoadedUrl);
			}
		}
	}
	if([delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:successfully:)])
	{
		[delegate audioPlayerDidFinishPlaying:playerIn successfully:flag];
	}
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:OALAudioTrackFinishedPlayingNotification object:self] waitUntilDone:NO];
}

@end
