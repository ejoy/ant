//
//  Framework.h
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#ifndef Framework_h
#define Framework_h
#import <UIKit/UIKit.h>
#import <luavm.h>

@interface FrameWork : NSObject {

}

-(void)InitFrameWork:(CALayer* )layer size:(CGSize) view_size;
-(void)Update;
-(void)Terminate;
@end

#endif /* Framework_h */
