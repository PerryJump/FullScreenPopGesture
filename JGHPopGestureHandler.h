//
//  JGHPopGestureHandler.h
//  xjf
//
//  Created by PerryJ on 16/7/22.
//  Copyright © 2016年 lcb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UINavigationController (JGHFullscreenPopGesture)
/**
 * the full screen pop gesture recognizer,it is readonly by primary property
 */
@property (nonatomic, strong, readonly) UIPanGestureRecognizer *jgh_fullscreenPopGestureRecognizer;
/**
 *  enabled the base navigation bar appearance,yes by default
 */
@property (nonatomic, assign) BOOL jgh_viewControllerBasedNavigationBarAppearanceEnabled;

@end

@interface UIViewController (JGHFullscreenPopGesture)
/**
 *  disable the pop guesture
 */
@property (nonatomic, assign) BOOL jgh_interactivePopDisabled;
/**
 *  replace system setter method of navigation bar hidden,used in ViewController navigation bar need hidden
 */
@property (nonatomic, assign) BOOL jgh_prefersNavigationBarHidden;
/**
 *  the maxmum distance allowed to pop
 */
@property (nonatomic, assign) CGFloat jgh_interactivePopMaxAllowedInitialDistanceToLeftEdge;

@end
