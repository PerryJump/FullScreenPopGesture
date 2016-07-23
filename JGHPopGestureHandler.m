//
//  JGHPopGestureHandler.m
//  xjf
//
//  Created by PerryJ on 16/7/22.
//  Copyright © 2016年 lcb. All rights reserved.
//

#import "JGHPopGestureHandler.h"
#import <objc/runtime.h>

@interface _JGHFullscreenPopGestureRecognizerDelegate : NSObject <UIGestureRecognizerDelegate>

@property (nonatomic, weak) UINavigationController *navigationController;

@end

@implementation _JGHFullscreenPopGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (self.navigationController.viewControllers.count <= 1) {
        return NO;
    }
    
    UIViewController *topViewController = self.navigationController.viewControllers.lastObject;
    if (topViewController.jgh_interactivePopDisabled) {
        return NO;
    }
    
    CGPoint beginningLocation = [gestureRecognizer locationInView:gestureRecognizer.view];
    CGFloat maxAllowedInitialDistance = topViewController.jgh_interactivePopMaxAllowedInitialDistanceToLeftEdge;
    if (maxAllowedInitialDistance > 0 && beginningLocation.x > maxAllowedInitialDistance) {
        return NO;
    }
    
    if ([[self.navigationController valueForKey:@"_isTransitioning"] boolValue]) {
        return NO;
    }
    
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    if (translation.x <= 0) {
        return NO;
    }
    
    return YES;
}

@end

typedef void (^_JGHViewControllerWillAppearInjectBlock)(UIViewController *viewController, BOOL animated);

@interface UIViewController (FDFullscreenPopGesturePrivate)

@property (nonatomic, copy) _JGHViewControllerWillAppearInjectBlock jgh_willAppearInjectBlock;

@end

@implementation UIViewController (JGHFullscreenPopGesturePrivate)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(jgh_viewWillAppear:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)jgh_viewWillAppear:(BOOL)animated
{
    // Forward to primary implementation.
    [self jgh_viewWillAppear:animated];
    
    if (self.jgh_willAppearInjectBlock) {
        self.jgh_willAppearInjectBlock(self, animated);
    }
}

- (_JGHViewControllerWillAppearInjectBlock)jgh_willAppearInjectBlock
{
    return objc_getAssociatedObject(self, _cmd);
}
-(void)setJgh_willAppearInjectBlock:(_JGHViewControllerWillAppearInjectBlock)jgh_willAppearInjectBlock {
    objc_setAssociatedObject(self, @selector(jgh_willAppearInjectBlock), jgh_willAppearInjectBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UINavigationController (JGHFullscreenPopGesture)

+ (void)load
{
    // Inject "-pushViewController:animated:"
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(pushViewController:animated:);
        SEL swizzledSelector = @selector(jgh_pushViewController:animated:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)jgh_pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.jgh_fullscreenPopGestureRecognizer]) {
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.jgh_fullscreenPopGestureRecognizer];
        NSArray *internalTargets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id internalTarget = [internalTargets.firstObject valueForKey:@"target"];
        SEL internalAction = NSSelectorFromString(@"handleNavigationTransition:");
        self.jgh_fullscreenPopGestureRecognizer.delegate = self.jgh_popGestureRecognizerDelegate;
        [self.jgh_fullscreenPopGestureRecognizer addTarget:internalTarget action:internalAction];
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    [self jgh_setupViewControllerBasedNavigationBarAppearanceIfNeeded:viewController];
    if (![self.viewControllers containsObject:viewController]) {
        [self jgh_pushViewController:viewController animated:animated];
    }
}

- (void)jgh_setupViewControllerBasedNavigationBarAppearanceIfNeeded:(UIViewController *)appearingViewController
{
    if (!self.jgh_viewControllerBasedNavigationBarAppearanceEnabled) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    _JGHViewControllerWillAppearInjectBlock block = ^(UIViewController *viewController, BOOL animated) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf setNavigationBarHidden:viewController.jgh_prefersNavigationBarHidden animated:animated];
        }
    };
    appearingViewController.jgh_willAppearInjectBlock = block;
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    if (disappearingViewController && !disappearingViewController.jgh_willAppearInjectBlock) {
        disappearingViewController.jgh_willAppearInjectBlock = block;
    }
}

- (_JGHFullscreenPopGestureRecognizerDelegate *)jgh_popGestureRecognizerDelegate
{
    _JGHFullscreenPopGestureRecognizerDelegate *delegate = objc_getAssociatedObject(self, _cmd);
    
    if (!delegate) {
        delegate = [[_JGHFullscreenPopGestureRecognizerDelegate alloc] init];
        delegate.navigationController = self;
        
        objc_setAssociatedObject(self, _cmd, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return delegate;
}

- (UIPanGestureRecognizer *)jgh_fullscreenPopGestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = objc_getAssociatedObject(self, _cmd);
    
    if (!panGestureRecognizer) {
        panGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
        panGestureRecognizer.maximumNumberOfTouches = 1;
        
        objc_setAssociatedObject(self, _cmd, panGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return panGestureRecognizer;
}

- (BOOL)jgh_viewControllerBasedNavigationBarAppearanceEnabled
{
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) {
        return number.boolValue;
    }
    self.jgh_viewControllerBasedNavigationBarAppearanceEnabled = YES;
    return YES;
}
-(void)setJgh_viewControllerBasedNavigationBarAppearanceEnabled:(BOOL)enabled {
    SEL key = @selector(jgh_viewControllerBasedNavigationBarAppearanceEnabled);
    objc_setAssociatedObject(self, key, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIViewController (JGHFullscreenPopGesture)

- (BOOL)jgh_interactivePopDisabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
-(void)setJgh_interactivePopDisabled:(BOOL)disabled {
    objc_setAssociatedObject(self, @selector(jgh_interactivePopDisabled), @(disabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)jgh_prefersNavigationBarHidden
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
-(void)setJgh_prefersNavigationBarHidden:(BOOL)hidden {
    objc_setAssociatedObject(self, @selector(jgh_prefersNavigationBarHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)jgh_interactivePopMaxAllowedInitialDistanceToLeftEdge
{
#if CGFLOAT_IS_DOUBLE
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
#else
    return [objc_getAssociatedObject(self, _cmd) floatValue];
#endif
}
-(void)setJgh_interactivePopMaxAllowedInitialDistanceToLeftEdge:(CGFloat)distance {
    SEL key = @selector(jgh_interactivePopMaxAllowedInitialDistanceToLeftEdge);
    objc_setAssociatedObject(self, key, @(MAX(0, distance)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
