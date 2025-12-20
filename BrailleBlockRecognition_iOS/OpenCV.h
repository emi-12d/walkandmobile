// OpenCV.h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCV : NSObject
//+ or - (返り値 *)関数名:(引数の型 *)引数名;
//+ : クラスメソッド
//- : インスタンスメソッド
//reader　点字ブロック読み取り
- (NSArray *)reader:(UIImage *)img;
@end
