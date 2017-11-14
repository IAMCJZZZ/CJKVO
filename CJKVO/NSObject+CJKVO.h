//
//  NSObject+CJKVO.h
//  CJKVO
//
//  Created by CJ on 2017/11/8.
//  Copyright © 2017年 CJ. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 属性变化后执行的block

 @param observedObject asd 需要被观察的对象
 @param observedKey 观察的属性
 @param oldValue 属性旧值
 @param newValue 属性新值
 */
typedef void(^CJObservingBlock)(id observedObject, NSString * observedKey, id oldValue, id newValue);

@interface NSObject (CJKVO)

/**
 添加观察者

 @param observer 需要添加的观察者
 @param key 观察的属性
 @param block 属性变化后执行的block
 */
- (void)CJ_addObserver:(NSObject *)observer
                forKey:(NSString *)key
             withBlock:(CJObservingBlock)block;

/**
 移除观察者

 @param observer 需要移除的观察者
 @param key 观察的属性
 */
- (void)CJ_removeObserver:(NSObject *)observer forKey:(NSString *)key;

@end








