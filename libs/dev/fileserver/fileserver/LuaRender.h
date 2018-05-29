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
- (void) InitScript:(CALayer*) layer size:(CGSize)view_size;
- (void) Update;
- (void) Terminate;
- (void) SendLog:(NSString*) log_str;
@end


#endif /* LuaRender_h */
