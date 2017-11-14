//
//  NSObject+CJKVO.m
//  CJKVO
//
//  Created by CJ on 2017/11/8.
//  Copyright © 2017年 CJ. All rights reserved.
//

#import "NSObject+CJKVO.h"
#import <objc/message.h>

static NSString * const kCJKVOClassPrefix = @"CJKVONotifying_";
static NSString * const kCJKVOObservations = @"kCJKVOObservations";

@interface CJObservation : NSObject

// 观察者
@property (nonatomic, weak) NSObject *observer;
// 属性key
@property (nonatomic, copy) NSString *key;
// 回调block
@property (nonatomic, copy) CJObservingBlock block;

@end

@implementation CJObservation

- (instancetype)initWithObserver:(NSObject *)observer key:(NSString *)key block:(CJObservingBlock)block {
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end

@implementation NSObject (CJKVO)

//添加观察者
- (void)CJ_addObserver:(NSObject *)observer forKey:(NSString *)key withBlock:(CJObservingBlock)block {
    
    // 检查对象的类有没有相应的 setter 方法
    SEL setterSelector = NSSelectorFromString([self setter:key]);
    // 因为重写了 class，所以[self class]获取的一直是父类
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
        NSLog(@"key 没有相应的 setter 方法");
        return;
    }
    
    // 获取当前类的 name
    Class clazz = object_getClass(self);
    NSString * clazzName = NSStringFromClass(clazz);
    
    // 如果当前类不是 kvo子类。（如果添加了多次观察者，kvo子类在第一次添加观察者的时候就创建了）
    if (![clazzName hasPrefix:kCJKVOClassPrefix]) {
        // 生成 kvo子类
        clazz = [self setKVOClassWithOriginalClassName:clazzName];
        // 让 isa 指向 kvo子类
        object_setClass(self, clazz);
    }
    
    // 如果 kvo子类 没有对应的 setter 方法，则添加。（同一个 key 可能会被添加多次）
    if (![self hasSelector:setterSelector]) {
        const char * types = method_getTypeEncoding(setterMethod);
        class_addMethod(clazz, setterSelector, (IMP)kvo_setter, types);
    }
    
    // 创建观察者组合
    CJObservation * observation = [[CJObservation alloc] initWithObserver:observer key:key block:block];
    // 获取所有观察者组合
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(kCJKVOObservations));
    if (!observations) {
        observations = [NSMutableArray array];
        // 添加关联所有观察者组合
        objc_setAssociatedObject(self, (__bridge const void *)(kCJKVOObservations), observations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observations addObject:observation];
}

// 移除观察者
- (void)CJ_removeObserver:(NSObject *)observer forKey:(NSString *)key {
    
    // 获取所有观察者组合
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(kCJKVOObservations));
    
    // 根据 key 移除观察者组合
    CJObservation * observationShouldRemove;
    for (CJObservation * observation in observations) {
        if (observation.observer == observer && [observation.key isEqual:key]) {
            observationShouldRemove = observation;
            break;
        }
    }
    [observations removeObject:observationShouldRemove];
    
    //在移除所有观察者之后，让对象的 isa 指针重新指向它原本的类。
    if (observations && observations.count == 0) {
        // 获取当前类的 name
        Class clazz = object_getClass(self);
        NSString * clazzName = NSStringFromClass(clazz);
        
        // 如果当前类是 kvo子类
        if ([clazzName hasPrefix:kCJKVOClassPrefix]) {
            // 获取对象原本的类
            clazz = NSClassFromString([clazzName substringFromIndex:kCJKVOClassPrefix.length]);
            // 让 isa 指向原本的类
            object_setClass(self, clazz);
        }
    }
}

// 获取当前类的父类
static Class kvo_class(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

// 实现 setter 方法
static void kvo_setter(id self, SEL _cmd, id newValue) {
    
    // 根据 setter 获取 getter，_cmd 代表本方法的名称
    NSString * setterName = NSStringFromSelector(_cmd);
    NSString * getterName = [self getter:setterName];
    if (!getterName) {
        NSLog(@"key 没有相应的 getter 方法");
        return;
    }
    
    // 根据 key 获取对应的旧值
    id oldValue = [self valueForKey:getterName];
    
    // 构造 objc_super 的结构体
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self)),
    };
    
    // 对 objc_msgSendSuper 进行类型转换，解决编译器报错的问题
    void (* objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    // id objc_msgSendSuper(struct objc_super *super, SEL op, ...) ,传入结构体、方法名称，和参数等
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
    
    // 调用之前传入的 block
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(kCJKVOObservations));
    for (CJObservation * observation in observations) {
        if ([observation.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                observation.block(self, getterName, oldValue, newValue);
            });
        }
    }
}

// 生成 kvo子类
- (Class)setKVOClassWithOriginalClassName:(NSString *)originalClazzName {
    
    //1.拼接 kvo 子类并生成
    NSString * kvoClazzName = [NSString stringWithFormat:@"%@%@",kCJKVOClassPrefix,originalClazzName];
    Class kvoClazz =NSClassFromString(kvoClazzName);
    
    //2.如果已经存在则返回
    if (kvoClazz) {
        return kvoClazz;
    }
    
    //3.如果不存在，则传一个父类，类名，然后额外的空间（通常为 0），它返回给你一个子类。
    Class originalClazz = object_getClass(self);
    kvoClazz = objc_allocateClassPair(originalClazz, kvoClazzName.UTF8String, 0);
    
    //4.重写了 class 方法，隐藏这个新的子类
    Method clazzMethod = class_getInstanceMethod(originalClazz, @selector(class));
    const char * types = method_getTypeEncoding(clazzMethod);
    class_addMethod(kvoClazz, @selector(class), (IMP)kvo_class, types);
    
    //5.注册到 runtime 告诉 runtime 这个类的存在
    objc_registerClassPair(kvoClazz);
    
    return kvoClazz;
}

//获取 setter 方法字符串
- (NSString *)setter:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    
    // key 第一个大写
    NSString * firstStr = [[key substringToIndex:1] uppercaseString];
    // 截取 key 第二到最后
    NSString * remainingStr = [key substringFromIndex:1];
    // 拼接成 setter
    NSString * setter = [NSString stringWithFormat:@"set%@%@:", firstStr, remainingStr];
    
    return setter;
}

//获取 getter 方法字符串
- (NSString *)getter:(NSString *)setter {
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    // 先截掉 set，获取后面属性字符
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString * key = [setter substringWithRange:range];
    
    // 把第一个字符换成小写
    NSString * firstStr = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstStr];
    
    return key;
}

// 是否包含 selector 方法
- (BOOL)hasSelector:(SEL)selector {
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    // 获取方法列表
    Method* methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    free(methodList);
    return NO;
}


@end






/*
- (NSString *)description {
    
    NSString *str = [NSString stringWithFormat:@"%@: %@\n\tNSObject class %s\n\tRuntime class %s\n\timplements methods <%@>\n\n", self, self, class_getName([self class]), class_getName(object_getClass(self)),[[self classMethodNames:object_getClass(self)] componentsJoinedByString:@", "]];
    
    return [NSString stringWithUTF8String:[str UTF8String]];
}

- (NSArray *)classMethodNames:(Class)c {
    NSMutableArray *array = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(c, &methodCount);
    unsigned int i;
    for(i = 0; i < methodCount; i++) {
        [array addObject: NSStringFromSelector(method_getName(methodList[i]))];
    }
    free(methodList);
    
    return array;
}
 
 */






