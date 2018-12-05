//
//  AppDelegate.h
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Framework.h"

@interface View : UIView {
    CADisplayLink* m_DisplayLink;
    FrameWork* m_FrameWork;
}
@property (nonatomic, retain) FrameWork* m_FrameWork;

+(Class) layerClass;
-(void) start;
-(void) updateView;
-(void) stop;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    UIWindow* m_Window;
    View* m_View;
}


@property (strong, nonatomic) UIWindow *m_Window;
@property (strong, nonatomic) View *m_View;

@end

