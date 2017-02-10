# SCPhotoBrowser
拆分YYKit中的图片浏览器,去掉了大部分依赖库，添加YYWebImage即可使用。

# Usage
引用头文件`#import "SCPhotoBrowserView.h"`
```
 self.items = [NSMutableArray new];
    for (NSInteger i = 0; i < 5; i++) {
        SCPhotoGroupItem *item = [SCPhotoGroupItem new];
        item.thumbView = self.button;
        item.largeImageURL = [NSURL URLWithString:@"http://pic2.cxtuku.com/00/02/31/b945758fd74d.jpg"];
        item.largeImageSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
        [self.items addObject:item];
    }
    // 调用
    SCPhotoBrowserView *browerView = [[SCPhotoBrowserView alloc] initWithGroupItems:self.items];
    [browerView presentFromImageView:self.button toContainer:self.navigationController.view animated:YES completion:nil];
    ```
    
