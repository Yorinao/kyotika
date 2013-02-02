//
//  KMTreasureHunterAnnotationView.m
//  KyotoMap
//
//  Created by kunii on 2013/01/20.
//  Copyright (c) 2013年 國居貴浩. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "KMTreasureHunterAnnotationView.h"
#import "KMTreasureHunterAnnotation.h"


@interface KMTreasureHunterAnnotationView() {
    CALayer* _walker;
    CALayer*     _searcher;
    int _direction;
}
@end


@implementation KMTreasureHunterAnnotationView
- (UIImage*)image
{
    static UIImage* walkerImage;
    if (walkerImage == nil)
        walkerImage = [UIImage imageNamed:@"vx_chara07_b_cvt_0_1"];
    return walkerImage;
}

- (NSArray*)contentsRectArrayStand
{
    static NSMutableArray* array = nil;
    if (array == nil) {
        array = [NSMutableArray arrayWithCapacity:4];
        CGRect r = {0,0,0.25,0.25};
        for (int i = 0; i < 4; i++) {
            [array addObject:[NSValue valueWithCGRect:r]];
            r.origin.y += 0.25;
        }
    }
    return array;
}

- (NSArray*)contentsRectArrayWalkWithDirection:(int)direction
{
    static NSArray* array[] = {nil, nil, nil, nil};
    if (array[direction] == nil) {
        NSMutableArray* tmparray = [NSMutableArray arrayWithCapacity:4];
        CGRect r = {0,0,0.25,0.25};
        r.origin.y = 0.25 * direction;
        for (int i = 0; i < 4; i++) {
            [tmparray addObject:[NSValue valueWithCGRect:r]];
            r.origin.x += 0.25;
        }
        array[direction] = tmparray;
    }
    return array[direction];
}


- (id)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString*)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        // フレームサイズを適切な値に設定する
        CGRect myFrame = self.frame;
        myFrame.size.width = 40;
        myFrame.size.height = 40;
        self.frame = myFrame;
        // 不透過プロパティをNOに設定することで、地図コンテンツが、レンダリング対象外のビューの領域を透かして見えるようになる。
        self.opaque = NO;
        
        _walker = [CALayer layer];
        _walker.frame = CGRectMake(0, 0, 32, 48);
        _walker.contents = (id)self.image.CGImage;
        _walker.contentsRect = [(NSValue*)[self.contentsRectArrayStand objectAtIndex:0] CGRectValue];
        _direction = -1;
        
        self.layer.cornerRadius = myFrame.size.width / 2;
        [self.layer addSublayer:_walker];
        
        UITapGestureRecognizer* tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)];
        [self addGestureRecognizer:tapGestureRecognizer];
    }
    return self;
}

- (void)tap
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"KMTreasureHunterAnnotationViewTapNotification" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_hunterAnnotation, @"annotation", nil]];
}

- (void)setCourse:(CLLocationDirection)course
{
    if (course < 0)     //  使用不可
        return;
    int index = ((int)course % 360) / 45;        //  0 - 359     0, [1, 2], 3, 4, [5, 6], 7
    int directions[] = {0,3,3,2,2,1,1,0};
    int direction = directions[index];
    if (_direction == direction)
        return;
    _direction = direction;
    CAKeyframeAnimation * walkAnimation =[CAKeyframeAnimation animationWithKeyPath:@"contentsRect"];
    walkAnimation.values = [self contentsRectArrayWalkWithDirection:_direction];
    walkAnimation.calculationMode = kCAAnimationDiscrete;
    
    walkAnimation.duration= 1;
    walkAnimation.repeatCount = HUGE_VALF;
    [_walker removeAnimationForKey:@"walk"];
    [_walker addAnimation:walkAnimation forKey:@"walk"];
}

- (void)startAnimation
{
    CAKeyframeAnimation * walkAnimation =[CAKeyframeAnimation animationWithKeyPath:@"contentsRect"];
    walkAnimation.values = self.contentsRectArrayStand;
    walkAnimation.calculationMode = kCAAnimationDiscrete;    //  kCAAnimationLinear
    
    walkAnimation.duration= 1;
    walkAnimation.repeatCount = HUGE_VALF;
    [_walker addAnimation:walkAnimation forKey:@"walk"];
}

- (void)stopAnimation
{
    [_walker removeAnimationForKey:@"walk"];
}

- (void)setRegion:(MKCoordinateRegion)region
{
    if (region.span.latitudeDelta > 0.0050) {
        [_searcher removeFromSuperlayer];
        return;
    }
    if (_searcher.superlayer) {
        return;
    }
    if (_searcher == nil) {
        _searcher = [CALayer layer];
        _searcher.frame = CGRectInset(self.bounds, -20, -20);
        _searcher.contents = (id)[UIImage imageNamed:@"searcher"].CGImage;
    }
    [self.layer insertSublayer:_searcher below:_walker];

    CAKeyframeAnimation * searchAnimation =[CAKeyframeAnimation animationWithKeyPath:@"transform"];
    NSArray* keyAttributes = @[
                               [NSValue valueWithCATransform3D:CATransform3DIdentity],
                               [NSValue valueWithCATransform3D:CATransform3DMakeRotation(3.14, 0, 0, 1) ],
                               [NSValue valueWithCATransform3D:CATransform3DMakeRotation(3.14 * 2, 0, 0, 1)]
                               ];
    searchAnimation.values = keyAttributes;
    searchAnimation.duration= 3;
    searchAnimation.repeatCount = HUGE_VALF;
    [_searcher addAnimation:searchAnimation forKey:@"searcher"];
}
@end

