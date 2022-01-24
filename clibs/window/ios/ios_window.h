#ifndef _IOS_WINDOW_H_
#define _IOS_WINDOW_H_

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface View : UIView
    @property (nonatomic, retain) CADisplayLink* m_displayLink;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
    @property (nonatomic, retain) UIWindow* m_window;
    @property (nonatomic, retain) View*     m_view;
@end

#endif
