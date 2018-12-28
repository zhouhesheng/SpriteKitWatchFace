//
//  FaceScene.h
//  SpriteKitWatchFace
//
//  Created by Steven Troughton-Smith on 10/10/2018.
//  Copyright © 2018 Steven Troughton-Smith. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    ThemeHermesOriginal,
    ThemeHermesOriginal4,
    ThemeHermesOriginal1,
    ThemeHermesOriginalOrange,
    ThemeHermesOriginalOrange4,
    ThemeHermesOriginalOrange1,
    ThemeHermesClassic,
    ThemeHermesClassic4,
    ThemeHermesClassic1,
    ThemeHermesClassicOrange,
    ThemeHermesClassicOrange4,
    ThemeHermesClassicOrange1,
    ThemeHermesRoma,
    ThemeHermesRoma4,
    ThemeHermesRoma1,
    ThemeHermesRomaOrange,
    ThemeHermesRomaOrange4,
    ThemeHermesRomaOrange1,
    ThemeHermesPink,
    ThemeRoyal,
    
    
    ThemeMAX,
} Theme;

typedef enum : NSUInteger {
	NumeralStyleAll,
	NumeralStyleCardinal,
	NumeralStyleNone
} NumeralStyle;

typedef enum : NSUInteger {
	TickmarkStyleAll,
	TickmarkStyleMajor,
	TickmarkStyleMinor,
	TickmarkStyleNone
} TickmarkStyle;

@interface FaceScene : SKScene <SKSceneDelegate>

-(void)refreshTheme;

@property Theme theme;
@property NumeralStyle numeralStyle;
@property TickmarkStyle tickmarkStyle;

@property SKColor *colorRegionColor;
@property SKColor *faceBackgroundColor;
@property SKColor *handColor;
@property SKColor *secondHandColor;
@property SKColor *inlayColor;

@property SKColor *majorMarkColor;
@property SKColor *minorMarkColor;
@property SKColor *textColor;
@property SKColor *dateColor;//新增日期颜色(by wusaul)

@property SKColor *alternateMajorMarkColor;
@property SKColor *alternateMinorMarkColor;
@property SKColor *alternateTextColor;
@property SKColor *alternateDateColor;//新增日期颜色(by wusaul)

@property BOOL useProgrammaticLayout;
@property BOOL useRoundFace;
@property BOOL useMasking;
@property BOOL showDateoriginal;//新增日期字体(by twd)
@property BOOL showDateclassic;//新增日期字体(by twd)
@property BOOL showDateroma;//新增日期字体(by twd)

@property CGSize faceSize;

@end





NS_ASSUME_NONNULL_END
