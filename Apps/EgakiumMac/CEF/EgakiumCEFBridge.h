#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Loads and initializes the official CEF framework for the existing AppKit
/// event loop. Returns NO with an NSError when CEF cannot be used. There is no
/// alternate renderer.
FOUNDATION_EXPORT BOOL EgakiumCEFInitialize(void);

/// True after CefInitialize succeeds and before shutdown starts.
FOUNDATION_EXPORT BOOL EgakiumCEFIsAvailable(void);

/// Stable diagnostic for an initialization failure, or nil when no failure
/// has been recorded.
FOUNDATION_EXPORT NSString * _Nullable EgakiumCEFInitializationError(void);

/// Closes every CEF browser, calls CefShutdown on the browser-process main
/// thread, then invokes completion. Completion is always delivered on the main
/// thread, including when initialization never succeeded.
FOUNDATION_EXPORT void EgakiumCEFShutdown(dispatch_block_t completion);

/// True after the CEF shutdown sequence has completed (or when CEF never
/// initialized) and AppKit may perform its final process termination.
FOUNDATION_EXPORT BOOL EgakiumCEFShutdownIsComplete(void);

/// Re-enters AppKit's standard termination only after CEF has shut down. The
/// Egakium application delegate will then return terminateNow synchronously.
FOUNDATION_EXPORT void EgakiumCEFCompleteApplicationTermination(void);

/// A native AppKit parent for one official CEF child browser. Session files are
/// exposed only through the private egakium://canvas scheme rooted at the
/// supplied directory; file:// and network requests are not used.
@interface EgakiumCEFView : NSView {
 @private
  void *_cefClientStorage;
  NSString *_cefRootPath;
  NSString *_cefIndexURL;
  NSTextField *_cefStatusLabel;
  BOOL _cefCreationRequested;
  BOOL _cefClosed;
}

- (BOOL)loadCanvasIndexURL:(NSURL *)indexURL
            readAccessURL:(NSURL *)readAccessURL;

- (void)reloadCanvas;
- (void)closeBrowser;

@end

NS_ASSUME_NONNULL_END
