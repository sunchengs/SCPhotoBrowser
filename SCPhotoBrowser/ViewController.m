//
//  ViewController.m
//  SCPhotoBrowser
//
//  Created by 孙程 on 2017/2/10.
//  Copyright © 2017年 suncheng. All rights reserved.
//

#import "ViewController.h"
#import "SCPhotoBrowserView.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *button;
@property (nonatomic, strong) NSMutableArray *items;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.items = [NSMutableArray new];
    for (NSInteger i = 0; i < 5; i++) {
        SCPhotoGroupItem *item = [SCPhotoGroupItem new];
        item.thumbView = self.button;
        item.largeImageURL = [NSURL URLWithString:@"http://pic2.cxtuku.com/00/02/31/b945758fd74d.jpg"];
        item.largeImageSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
        [self.items addObject:item];
    }
}

- (IBAction)showPhotoBrowserView:(id)sender {
    SCPhotoBrowserView *browerView = [[SCPhotoBrowserView alloc] initWithGroupItems:self.items];
    [browerView presentFromImageView:self.button toContainer:self.navigationController.view animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
