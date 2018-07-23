//
//  LuaRender.h
//  fileserver
//
//  Created by ejoy on 2018/5/24.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#ifndef LuaRender_h
#define LuaRender_h
#import <UIKit/UIKit.h>

@interface LuaRender : NSObject
{
    @private
        NSMutableArray* MsgArray;
}
- (void) InitScript:(CALayer*) layer size:(CGSize)view_size;
- (void) Update;
- (void) Terminate;
- (void) SendLog:(NSString*) log_str;
- (void) HandleInput;
- (void) AddInputMessage:(NSString*) msg x_pos:(CGFloat) x y_pos:(CGFloat) y;
@end

@interface InputMsg : NSObject {
    @public
        NSString* msg;
        CGFloat x_pos;
        CGFloat y_pos;
}
-(id) initWithArgs:(NSString*) in_msg x_pos:(CGFloat) in_x y_pos:(CGFloat) in_y;
@end
#endif /* LuaRender_h */
