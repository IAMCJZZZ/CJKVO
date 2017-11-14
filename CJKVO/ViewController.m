//
//  ViewController.m
//  CJKVO
//
//  Created by CJ on 2017/11/8.
//  Copyright © 2017年 CJ. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+CJKVO.h"
#import "Yinker.h"

@interface ViewController ()

@property (nonatomic, strong) Yinker * yinker;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Yinker * yinker = [[Yinker alloc] init];
    _yinker = yinker;
    _yinker.name = @"HH";
    
    // 添加观察者
    [_yinker CJ_addObserver:self forKey:@"name" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@,%@,%@,%@,%@",[NSThread currentThread],observedObject,observedKey,oldValue,newValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.label.text = newValue;
        });
    }];
    
    [_yinker CJ_addObserver:self forKey:@"job" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
    }];
    
}
- (IBAction)modifyName:(id)sender {
    
    // 修改属性值
    _yinker.name = @"CJ";
    
    // 移除观察者
    [_yinker CJ_removeObserver:self forKey:@"name"];
    
    [_yinker CJ_removeObserver:self forKey:@"job"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    /*
     [_yinker addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
     [_yinker addObserver:self forKeyPath:@"job" options:NSKeyValueObservingOptionNew context:nil];
     */
    self.label.text = [change valueForKey:NSKeyValueChangeNewKey];
    NSLog(@"%@,%@,%@,%@,%@",[NSThread currentThread],object,keyPath,[change valueForKey:NSKeyValueChangeOldKey],[change valueForKey:NSKeyValueChangeNewKey]);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
