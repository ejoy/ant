//
//  AppDelegate.h
//  fileserver
//
//  Created by ejoy on 2018/5/24.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#ifndef AppDelegate_h
#define AppDelegate_h
#import <UIKit/UIKit.h>
#import "LuaRender.h"

@interface View : UIView
{
    CADisplayLink* m_displayLink;
    LuaRender* m_Render;
}

@property (nonatomic, retain) LuaRender* m_Render;
@end

@interface AppDelegate : UIResponder<UIApplicationDelegate>
{
    UIWindow* m_window;
    View* m_view;
}

@property (nonatomic, retain) UIWindow* m_window;
@property (nonatomic, retain) View* m_view;
@end

#endif /* AppDelegate_h */
