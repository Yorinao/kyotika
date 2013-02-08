//
//  KMVaults.m
//  KyotoMap
//
//  Created by kunii on 2013/01/20.
//  Copyright (c) 2013年 國居貴浩. All rights reserved.
//

#import "KMVaults.h"
#import "KMTreasureAnnotation.h"
#import "KMAreaAnnotation.h"
#import "Landmark.h"

static const CLLocationDegrees groupThresholdDegree = 0.02;             ///  KMTreasureAnnotationではなく、KMAreaAnnotationを返すしきい値
static const CLLocationDegrees findingModeThresholdDegree = 0.0050;     ///  検索モードのしきい値設定（角度）この角度以内の表示領域なら検索モードとなる
static const CLLocationDistance nearThresholdMeter = 200.0;             ///  200m四方が基本の近接範囲

@implementation KMVaults {
    __weak NSManagedObjectContext* _moc;
    NSMutableArray* _treasureAnnotations;
    NSDictionary*  _groupAnnotations[3];
}

- (id)initWithContext:(NSManagedObjectContext *)moc
{
    self = [super init];
    if (self) {
        _moc = moc;
        
        //  今回は、いったん全部KMTreasureAnnotation化し_treasureAnnotationsに蓄える。千件以上ならキャッシュ機能をつけるべき。
        NSArray* array = [Landmark allFound:_moc];
        _treasureAnnotations = [NSMutableArray arrayWithCapacity:[array count]];
        for (Landmark *l in array) {
            l.found = [NSNumber numberWithBool:NO];
            KMTreasureAnnotation *a = [[KMTreasureAnnotation alloc] init];
            a.landmark = l;
            a.title = l.name;
            a.coordinate = CLLocationCoordinate2DMake([l.latitude doubleValue],
                                                      [l.longitude doubleValue]);
            [_treasureAnnotations addObject:a];
        }
        //  横20 x 縦20の区画でランドマークをまとめてグループ注釈として返す
    }
    return self;
}

- (void)makeArea:(MKCoordinateRegion)region
{
    _groupAnnotations[0] = [self groupAnnotations:region latitudeDivCount:20 longitudeDivCount:24];
    _groupAnnotations[1] = [self groupAnnotations:region latitudeDivCount:10 longitudeDivCount:12];
    _groupAnnotations[2] = [self groupAnnotations:region latitudeDivCount:5 longitudeDivCount:6];
}

- (NSDictionary*)groupAnnotations:(MKCoordinateRegion)region latitudeDivCount:(int)latitudeDivCount longitudeDivCount:(int)longitudeDivCount
{
    NSMutableDictionary* groupAnnotations = [NSMutableDictionary dictionaryWithCapacity:latitudeDivCount * longitudeDivCount];
    
    CLLocationDegrees top = region.center.latitude - (region.span.latitudeDelta / 2);
    CLLocationDegrees latitudeDelta = region.span.latitudeDelta / latitudeDivCount;
    
    CLLocationDegrees left = region.center.longitude - (region.span.longitudeDelta / 2);
    CLLocationDegrees longitudeDelta = region.span.longitudeDelta / longitudeDivCount;
    
    for (KMTreasureAnnotation* a in _treasureAnnotations) {
        CLLocationDegrees v = a.coordinate.latitude - top;
        v /= latitudeDelta;
        if (v < 0.0) continue;
        if (v >= latitudeDivCount) continue;
        
        CLLocationDegrees h = a.coordinate.longitude - left;
        h /= longitudeDelta;
        if (h < 0.0) continue;
        if (h >= longitudeDivCount) continue;
        
        NSString* key = [NSString stringWithFormat:@"%dx%d", (int)h, (int)v];
        if ([groupAnnotations valueForKey:key] == nil) {
            KMAreaAnnotation* pin = [[KMAreaAnnotation alloc] init];
            CLLocationDegrees latitude = (int)v * latitudeDelta;
            CLLocationDegrees longitude = (int)h * longitudeDelta;
            pin.coordinate = CLLocationCoordinate2DMake(latitude + top + (latitudeDelta / 2.0),
                                                        longitude + left + (longitudeDelta / 2.0));
            pin.title = nil;
            [groupAnnotations setValue:pin forKey:key];
        }
    }
    return groupAnnotations;
}

- (int)gropuIndexForRegion:(MKCoordinateRegion)region
{
    int index = -1;
    for (int thresholdSpan = 10000; index <= 2; thresholdSpan *= 2) {
        MKCoordinateRegion threshold = MKCoordinateRegionMakeWithDistance(region.center, thresholdSpan, thresholdSpan);
        if (region.span.longitudeDelta < threshold.span.longitudeDelta) {
            break;
        }
        index++;
    }
    return index;
}

typedef struct {
    CLLocationDegrees  minlatitude;
    CLLocationDegrees  maxlatitude;
    CLLocationDegrees  minlongitude;
    CLLocationDegrees  maxlongitude;
} KMRegion;

KMRegion KMRegionFromMKCoordinateRegion(MKCoordinateRegion region)
{
    KMRegion kmregion;
    kmregion.minlatitude = region.center.latitude - region.span.latitudeDelta;
    kmregion.maxlatitude = region.center.latitude + region.span.latitudeDelta;
    kmregion.minlongitude = region.center.longitude - region.span.longitudeDelta;
    kmregion.maxlongitude = region.center.longitude + region.span.longitudeDelta;
    return kmregion;
}

BOOL MKCoordinateInKMRegion(CLLocationCoordinate2D coordinate, KMRegion region)
{
    if (coordinate.longitude < region.minlongitude) return NO;
    if (coordinate.longitude > region.maxlongitude) return NO;
    if (coordinate.latitude < region.minlatitude) return NO;
    if (coordinate.latitude > region.maxlatitude) return NO;
    return YES;
}

/*
    Landmarkの数が多い場合は、与えられたregion範囲のLandmarkを検索し、
    結果を_treasureAnnotationsにキャッシュしたKMTreasureAnnotationインスタンスのLandmarkと比較し
    新しいものだけ_treasureAnnotationsにKMTreasureAnnotationとしてキャッシュする。
    そして、検索されなかったLandmarkを持つKMTreasureAnnotationは_treasureAnnotationsからとりはぶく
    といった作業が必要。
 */
- (NSSet*)treasureAnnotationsInRegion:(MKCoordinateRegion)region hunter:(CLLocationCoordinate2D)hunter power:(float)power
{
    NSMutableSet* set = [NSMutableSet set];
    KMRegion r = KMRegionFromMKCoordinateRegion(region);    //  regionで指定された範囲を決定

    int index = [self gropuIndexForRegion:region];
    if (index >= 0) {
        NSArray* garray = [_groupAnnotations[index] allValues];
        for (MKPointAnnotation* a in garray) {
            if (MKCoordinateInKMRegion(a.coordinate, r)) {
                [set addObject:a];
            }
        }
        return set;
    }
    
    //  検索モードのときは、nearThresholdMeter内の場合、無条件に発見（find）フラグをたてる。その範囲。
    KMRegion pr;
    
    if ((power != 0.0) || (region.span.latitudeDelta <= findingModeThresholdDegree)) {  //  power != 0.0は無条件で検索モード
        //  検索モードなので近接範囲を決定
        CLLocationDistance meter = nearThresholdMeter;
        if (power != 0.0) meter *= power;
        MKCoordinateRegion peekregion = MKCoordinateRegionMakeWithDistance(hunter, meter, meter);
        pr = KMRegionFromMKCoordinateRegion(peekregion);    //  peekregionで指定された範囲を決定
    }
    
    for (KMTreasureAnnotation* a in _treasureAnnotations) {
        if (MKCoordinateInKMRegion(a.coordinate, r) == NO)
            continue;
        if (a.find) {
            [set addObject:a];
            continue;
        }
        //  検索モードか？
        if (region.span.latitudeDelta > findingModeThresholdDegree)
            continue;
        //  検索モード
        if (MKCoordinateInKMRegion(a.coordinate, pr) == NO)
            continue;
        //  nearThresholdMeter内なので無条件に発見（find）フラグをたてる。
        a.find = YES;
        [set addObject:a];
    }
    return set;
}

- (NSArray*)landmarksForKey :(Tag *)tag
{
    NSArray* array = [tag.landmarks allObjects];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:[array count]];
    for (Landmark* landmark in array) {
        int index = [_treasureAnnotations indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            if (obj == landmark) {
                return YES;
            }
            return NO;
        }];
        if (index != NSNotFound) {
            [result addObject:[_treasureAnnotations objectAtIndex:index]];
        }
    }
    return result;
}

- (NSArray*)keywords
{
    return [Landmark tagsPassed:_moc];
}

- (NSArray*)landmarks
{
    return _treasureAnnotations;
}

- (void)setPassedAnnotation:(KMTreasureAnnotation*)annotation
{
    annotation.passed = YES;
    for (Tag* keyword in annotation.keywords) {
        for (KMTreasureAnnotation* a in _treasureAnnotations) {
            int index = [a.keywords indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                if (keyword == obj) {
                    return YES;
                }
                return NO;
            }];
            if (index != NSNotFound) {
                a.find = YES;
            }
        }
    }
    if (_complite < 1.0)
        _complite += 0.2;
}

- (void)save
{
    if (![_moc save:nil]) {
        // FIXME
    }
}

@end

//  MKMetersBetweenMapPoints