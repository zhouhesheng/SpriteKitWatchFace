//
//  FaceScene.m
//  SpriteKitWatchFace
//
//  Created by Steven Troughton-Smith on 10/10/2018.
//  Copyright © 2018 Steven Troughton-Smith. All rights reserved.
//

#import "FaceScene.h"
@import CoreText;

#if TARGET_OS_IPHONE

/* Sigh. */

#define NSFont UIFont
#define NSFontWeightMedium UIFontWeightMedium
#define NSFontWeightRegular UIFontWeightRegular

#define NSFontFeatureTypeIdentifierKey UIFontFeatureTypeIdentifierKey
#define NSFontFeatureSettingsAttribute UIFontDescriptorFeatureSettingsAttribute
#define NSFontDescriptor UIFontDescriptor

#define NSFontFeatureSelectorIdentifierKey UIFontFeatureSelectorIdentifierKey
#define NSFontNameAttribute UIFontDescriptorNameAttribute

#endif

#define PREPARE_SCREENSHOT 0



CGFloat workingRadiusForFaceOfSizeWithAngle(CGSize faceSize, CGFloat angle)
{
	CGFloat faceHeight = faceSize.height;
	CGFloat faceWidth = faceSize.width;
	
	CGFloat workingRadius = 0;
	
	double vx = cos(angle);
	double vy = sin(angle);
	
	double x1 = 0;
	double y1 = 0;
	double x2 = faceHeight;
	double y2 = faceWidth;
	double px = faceHeight/2;
	double py = faceWidth/2;
	
	double t[4];
	double smallestT = 1000;
	
	t[0]=(x1-px)/vx;
	t[1]=(x2-px)/vx;
	t[2]=(y1-py)/vy;
	t[3]=(y2-py)/vy;
	
	for (int m = 0; m < 4; m++)
	{
		double currentT = t[m];
		
		if (currentT > 0 && currentT < smallestT)
			smallestT = currentT;
	}
	
	workingRadius = smallestT;
	
	return workingRadius;
}

@implementation NSFont (SmallCaps)
-(NSFont *)smallCaps
{
	NSArray *settings = @[@{NSFontFeatureTypeIdentifierKey: @(kUpperCaseType), NSFontFeatureSelectorIdentifierKey: @(kUpperCaseSmallCapsSelector)}];
	NSDictionary *attributes = @{NSFontFeatureSettingsAttribute: settings, NSFontNameAttribute: self.fontName};
	
	return [NSFont fontWithDescriptor:[NSFontDescriptor fontDescriptorWithFontAttributes:attributes] size:self.pointSize];
}
@end

@interface FaceScene ()

@property SKTexture * backgroundTexture;
@property SKTexture * hoursHandTexture;
@property SKTexture * minutesHandTexture;
@property SKTexture * secondsHandTexture;
@property CGFloat hoursAnchorFromBottom;
@property CGFloat minutesAnchorFromBottom;
@property CGFloat secondsAnchorFromBottom;
@property BOOL runsBackwards;

@end

@implementation FaceScene

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		
		self.faceSize = (CGSize){184, 224};

		self.theme = [[NSUserDefaults standardUserDefaults] integerForKey:@"Theme"];
        if (self.theme >= ThemeMAX) {
            self.theme = 0;
        }
		self.useProgrammaticLayout = NO;
		self.useRoundFace = YES;
		self.numeralStyle = NumeralStyleNone;
		self.tickmarkStyle = TickmarkStyleNone;
		self.showDateoriginal = YES;
        self.showDateclassic = NO;
        self.showDateroma = NO;
		
		[self refreshTheme];
		
		self.delegate = self;
	}
	return self;
}

#pragma mark -

-(void)setupTickmarksForRoundFaceWithLayerName:(NSString *)layerName
{
	CGFloat margin = 4.0;
	CGFloat labelMargin = 26.0;
	
	SKCropNode *faceMarkings = [SKCropNode node];
	faceMarkings.name = layerName;
	
	/* Hardcoded for 44mm Apple Watch */
	
	for (int i = 0; i < 12; i++)
	{
		CGFloat angle = -(2*M_PI)/12.0 * i;
		CGFloat workingRadius = self.faceSize.width/2;
		CGFloat longTickHeight = workingRadius/15;
		
		SKSpriteNode *tick = [SKSpriteNode spriteNodeWithColor:self.majorMarkColor size:CGSizeMake(2, longTickHeight)];
		
		tick.position = CGPointZero;
		tick.anchorPoint = CGPointMake(0.5, (workingRadius-margin)/longTickHeight);
		tick.zRotation = angle;
		
		if (self.tickmarkStyle == TickmarkStyleAll || self.tickmarkStyle == TickmarkStyleMajor)
			[faceMarkings addChild:tick];
		
		CGFloat h = 25;
		
		NSDictionary *attribs = @{NSFontAttributeName : [NSFont systemFontOfSize:h weight:NSFontWeightMedium], NSForegroundColorAttributeName : self.textColor};
		
		NSAttributedString *labelText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i", i == 0 ? 12 : i] attributes:attribs];
		
		SKLabelNode *numberLabel = [SKLabelNode labelNodeWithAttributedText:labelText];
		numberLabel.position = CGPointMake((workingRadius-labelMargin) * -sin(angle), (workingRadius-labelMargin) * cos(angle) - 9);
		
		if (self.numeralStyle == NumeralStyleAll || ((self.numeralStyle == NumeralStyleCardinal) && (i % 3 == 0)))
			[faceMarkings addChild:numberLabel];
	}
	
	for (int i = 0; i < 60; i++)
	{
		CGFloat angle = - (2*M_PI)/60.0 * i;
		CGFloat workingRadius = self.faceSize.width/2;
		CGFloat shortTickHeight = workingRadius/20;
		SKSpriteNode *tick = [SKSpriteNode spriteNodeWithColor:self.minorMarkColor size:CGSizeMake(1, shortTickHeight)];
		
		tick.position = CGPointZero;
		tick.anchorPoint = CGPointMake(0.5, (workingRadius-margin)/shortTickHeight);
		tick.zRotation = angle;
		
		if (self.tickmarkStyle == TickmarkStyleAll || self.tickmarkStyle == TickmarkStyleMinor)
		{
			if (i % 5 != 0)
				[faceMarkings addChild:tick];
		}
	}
	
	if (self.showDateoriginal)
	{
		NSDateFormatter * df = [[NSDateFormatter alloc] init];
		[df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale preferredLanguages] firstObject]]];
		[df setDateFormat:@"d"];
        
		CGFloat numeralDelta = 0.0;

        
		
        NSDictionary *attribs = @{NSFontAttributeName : [[NSFont fontWithName:@"Hermes1" size:20] smallCaps], NSForegroundColorAttributeName : self.dateColor};
        
		
		NSAttributedString *labelText = [[NSAttributedString alloc] initWithString:[[df stringFromDate:[NSDate date]] uppercaseString] attributes:attribs];
        
        
		
		SKLabelNode *numberLabel = [SKLabelNode labelNodeWithAttributedText:labelText];
		
		if (self.numeralStyle == NumeralStyleNone)
			numeralDelta = 10.0;
		
		numberLabel.position = CGPointMake(-9.3+numeralDelta, -64.5);
		
		[faceMarkings addChild:numberLabel];
	}
    
    if (self.showDateclassic)
    {
        NSDateFormatter * df = [[NSDateFormatter alloc] init];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale preferredLanguages] firstObject]]];
        [df setDateFormat:@"d"];
        
        
        CGFloat numeralDelta = 0.0;
        
        
        NSDictionary *attribs = @{NSFontAttributeName : [[NSFont fontWithName:@"Hermes2" size:23] smallCaps], NSForegroundColorAttributeName : self.dateColor};
        
        NSAttributedString *labelText = [[NSAttributedString alloc] initWithString:[[df stringFromDate:[NSDate date]] uppercaseString] attributes:attribs];
        
        
        
        SKLabelNode *numberLabel = [SKLabelNode labelNodeWithAttributedText:labelText];
        
        if (self.numeralStyle == NumeralStyleNone)
            numeralDelta = 10.0;
        
        numberLabel.position = CGPointMake(-9.3+numeralDelta, -63);
        
        [faceMarkings addChild:numberLabel];
    }
    if (self.showDateroma)
    {
        NSDateFormatter * df = [[NSDateFormatter alloc] init];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale preferredLanguages] firstObject]]];
        [df setDateFormat:@"d"];
        
        
        CGFloat numeralDelta = 0.0;
        
        
        NSDictionary *attribs = @{NSFontAttributeName : [[NSFont systemFontOfSize:23 weight:NSFontWeightRegular] smallCaps], NSForegroundColorAttributeName : self.dateColor};
        
        NSAttributedString *labelText = [[NSAttributedString alloc] initWithString:[[df stringFromDate:[NSDate date]] uppercaseString] attributes:attribs];
        
        
        
        SKLabelNode *numberLabel = [SKLabelNode labelNodeWithAttributedText:labelText];
        
        if (self.numeralStyle == NumeralStyleNone)
            numeralDelta = 10.0;
        
        numberLabel.position = CGPointMake(-9.3+numeralDelta, -63);
        
        [faceMarkings addChild:numberLabel];
    }

	[self addChild:faceMarkings];
}
    


-(void)setupTickmarksForRectangularFaceWithLayerName:(NSString *)layerName
{
	CGFloat margin = 5.0;
	CGFloat labelYMargin = 30.0;
	CGFloat labelXMargin = 24.0;
	
	SKCropNode *faceMarkings = [SKCropNode node];
	faceMarkings.name = layerName;
	
	/* Major */
	for (int i = 0; i < 12; i++)
	{
		CGFloat angle = -(2*M_PI)/12.0 * i;
		CGFloat workingRadius = workingRadiusForFaceOfSizeWithAngle(self.faceSize, angle);
		CGFloat longTickHeight = workingRadius/10.0;
		
		SKSpriteNode *tick = [SKSpriteNode spriteNodeWithColor:self.majorMarkColor size:CGSizeMake(2, longTickHeight)];
		
		tick.position = CGPointZero;
		tick.anchorPoint = CGPointMake(0.5, (workingRadius-margin)/longTickHeight);
		tick.zRotation = angle;
		
		tick.zPosition = 0;
		
		if (self.tickmarkStyle == TickmarkStyleAll || self.tickmarkStyle == TickmarkStyleMajor)
			[faceMarkings addChild:tick];
	}
	
	/* Minor */
	for (int i = 0; i < 60; i++)
	{
		
		CGFloat angle =  (2*M_PI)/60.0 * i;
		CGFloat workingRadius = workingRadiusForFaceOfSizeWithAngle(self.faceSize, angle);
		CGFloat shortTickHeight = workingRadius/20;
		SKSpriteNode *tick = [SKSpriteNode spriteNodeWithColor:self.minorMarkColor size:CGSizeMake(1, shortTickHeight)];
		
		/* Super hacky hack to inset the tickmarks at the four corners of a curved display instead of doing math */
		if (i == 6 || i == 7  || i == 23 || i == 24 || i == 36 || i == 37 || i == 53 || i == 54)
		{
			workingRadius -= 8;
		}

		tick.position = CGPointZero;
		tick.anchorPoint = CGPointMake(0.5, (workingRadius-margin)/shortTickHeight);
		tick.zRotation = angle;
		
		tick.zPosition = 0;
		
		if (self.tickmarkStyle == TickmarkStyleAll || self.tickmarkStyle == TickmarkStyleMinor)
		{
			if (i % 5 != 0)
			{
				[faceMarkings addChild:tick];
			}
		}
	}
	
	/* Numerals */
	for (int i = 1; i <= 12; i++)
	{
		CGFloat fontSize = 25;
		
		SKSpriteNode *labelNode = [SKSpriteNode spriteNodeWithColor:[SKColor clearColor] size:CGSizeMake(fontSize, fontSize)];
		labelNode.anchorPoint = CGPointMake(0.5,0.5);
		
		if (i == 1 || i == 11 || i == 12)
			labelNode.position = CGPointMake(labelXMargin-self.faceSize.width/2 + ((i+1)%3) * (self.faceSize.width-labelXMargin*2)/3.0 + (self.faceSize.width-labelXMargin*2)/6.0, self.faceSize.height/2-labelYMargin);
		else if (i == 5 || i == 6 || i == 7)
			labelNode.position = CGPointMake(labelXMargin-self.faceSize.width/2 + (2-((i+1)%3)) * (self.faceSize.width-labelXMargin*2)/3.0 + (self.faceSize.width-labelXMargin*2)/6.0, -self.faceSize.height/2+labelYMargin);
		else if (i == 2 || i == 3 || i == 4)
			labelNode.position = CGPointMake(self.faceSize.height/2-fontSize-labelXMargin, -(self.faceSize.width-labelXMargin*2)/2 + (2-((i+1)%3)) * (self.faceSize.width-labelXMargin*2)/3.0 + (self.faceSize.width-labelYMargin*2)/6.0);
		else if (i == 8 || i == 9 || i == 10)
			labelNode.position = CGPointMake(-self.faceSize.height/2+fontSize+labelXMargin, -(self.faceSize.width-labelXMargin*2)/2 + ((i+1)%3) * (self.faceSize.width-labelXMargin*2)/3.0 + (self.faceSize.width-labelYMargin*2)/6.0);
		
		[faceMarkings addChild:labelNode];
		
		NSDictionary *attribs = @{NSFontAttributeName : [NSFont fontWithName:@"Futura-Medium" size:fontSize], NSForegroundColorAttributeName : self.textColor};
        
		
		NSAttributedString *labelText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i", i] attributes:attribs];
		
		SKLabelNode *numberLabel = [SKLabelNode labelNodeWithAttributedText:labelText];
		
		numberLabel.position = CGPointMake(0, -9);
		
		if (self.numeralStyle == NumeralStyleAll || ((self.numeralStyle == NumeralStyleCardinal) && (i % 3 == 0)))
			[labelNode addChild:numberLabel];
	}
	
	if (self.showDateoriginal)
	{
		NSDateFormatter * df = [[NSDateFormatter alloc] init];
		[df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale preferredLanguages] firstObject]]];
		[df setDateFormat:@"d"];
		
		CGFloat h = 30;
		
		NSDictionary *attribs = @{NSFontAttributeName : [[NSFont systemFontOfSize:h weight:NSFontWeightMedium] smallCaps], NSForegroundColorAttributeName : self.textColor};
		
		NSAttributedString *labelText = [[NSAttributedString alloc] initWithString:[[df stringFromDate:[NSDate date]] uppercaseString] attributes:attribs];
		
		SKLabelNode *numberLabel = [SKLabelNode labelNodeWithAttributedText:labelText];
		CGFloat numeralDelta = 0.0;
		
		if (self.numeralStyle == NumeralStyleNone)
			numeralDelta = 10.0;
		
		numberLabel.position = CGPointMake(32+numeralDelta, -4);
		
		[faceMarkings addChild:numberLabel];
	}
	
	[self addChild:faceMarkings];
}



#pragma mark -

-(void)setupColors
{
	SKColor *colorRegionColor = nil;
	SKColor *faceBackgroundColor = nil;
	SKColor *majorMarkColor = nil;
	SKColor *minorMarkColor = nil;
	SKColor *inlayColor = nil;
	SKColor *handColor = nil;
	SKColor *textColor = nil;
	SKColor *secondHandColor = nil;
    SKColor *dateColor = nil;//新增日期颜色
    SKColor *alternateDateColor = nil;//新增日期颜色
	
	SKColor *alternateMajorMarkColor = nil;
	SKColor *alternateMinorMarkColor = nil;
	SKColor *alternateTextColor = nil;

    self.useMasking = YES;//使用蒙版？(不知道描述是否准确)
    self.showDateoriginal = NO;//在下方显示日期
    self.showDateclassic = NO;//在右侧显示日期
    self.showDateroma = NO;//在右上侧显示日期

    faceBackgroundColor = [SKColor blackColor];
    colorRegionColor = [SKColor blackColor];
    inlayColor = colorRegionColor;
    majorMarkColor = [SKColor colorWithWhite:1 alpha:0.8];
    minorMarkColor = [faceBackgroundColor colorWithAlphaComponent:1];
    handColor = [SKColor whiteColor];
    textColor = [SKColor colorWithWhite:1 alpha:1];
    secondHandColor = [SKColor colorWithWhite:0.9 alpha:1];
    dateColor = [SKColor  colorWithWhite:1 alpha:1];//新增日期颜色
    alternateDateColor = [SKColor  colorWithWhite:1 alpha:0.8];//新增日期颜色
    alternateTextColor = textColor;
    alternateMinorMarkColor = [colorRegionColor colorWithAlphaComponent:0.5];
    alternateMajorMarkColor = [SKColor colorWithWhite:1 alpha:0.8];

    NSString * backgroundImageName = nil;
    NSString * hourHandImageName = nil;
    NSString * minuteHandImageName = nil;
    NSString * secondHandImageName = nil;
    CGFloat hoursAnchorFromBottom   = 0;
    CGFloat minutesAnchorFromBottom = 0;
    CGFloat secondsAnchorFromBottom = 0;
    BOOL runBackwards = NO;
    
	switch (self.theme) {
        
        case ThemeHermesOriginal:
            backgroundImageName = @"Hermes_watch_face_original";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】

          
            break;
        case ThemeHermesOriginal4:
            backgroundImageName = @"Hermes_watch_face_original4";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesOriginal1:
            backgroundImageName = @"Hermes_watch_face_original1";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesOriginalOrange:
            backgroundImageName = @"Hermes_watch_face_original_orange";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesOriginalOrange4:
            backgroundImageName = @"Hermes_watch_face_original_orange4";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesOriginalOrange1:
            backgroundImageName = @"Hermes_watch_face_original_orange1";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
            
        case ThemeHermesClassic:
            backgroundImageName = @"Hermes_watch_face_classic";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 17;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = YES;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesClassic4:
            backgroundImageName = @"Hermes_watch_face_classic4";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 17;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = YES;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesClassic1:
            backgroundImageName = @"Hermes_watch_face_classic1";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 17;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = YES;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesClassicOrange:
            backgroundImageName = @"Hermes_watch_face_classic_orange";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = YES;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesClassicOrange4:
            backgroundImageName = @"Hermes_watch_face_classic_orange4";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = YES;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesClassicOrange1:
            backgroundImageName = @"Hermes_watch_face_classic_orange1";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = YES;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            
            break;
        case ThemeHermesRoma:
            backgroundImageName = @"Hermes_watch_face_roma";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 17;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = YES;//使用roma系列日期【注释 by twd】
            break;
        case ThemeHermesRoma4:
            backgroundImageName = @"Hermes_watch_face_roma4";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 17;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = YES;//使用roma系列日期【注释 by twd】
            break;
        case ThemeHermesRoma1:
            backgroundImageName = @"Hermes_watch_face_roma1";
            hourHandImageName = @"Hermes_hours";
            minuteHandImageName = @"Hermes_minutes";
            secondHandImageName = @"Hermes_seconds";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 17;
            secondsAnchorFromBottom = 24;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = YES;//使用roma系列日期【注释 by twd】
            break;
        case ThemeHermesRomaOrange:
            backgroundImageName = @"Hermes_watch_face_roma_orange";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = YES;//使用roma系列日期【注释 by twd】
            break;
        case ThemeHermesRomaOrange4:
            backgroundImageName = @"Hermes_watch_face_roma_orange4";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = YES;//使用roma系列日期【注释 by twd】
            break;
        case ThemeHermesRomaOrange1:
            backgroundImageName = @"Hermes_watch_face_roma_orange1";
            hourHandImageName = @"Hermes_hours_white";
            minuteHandImageName = @"Hermes_minutes_white";
            secondHandImageName = @"Hermes_seconds_orange";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 16;
            secondsAnchorFromBottom = 27;
            self.showDateoriginal = NO;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = YES;//使用roma系列日期【注释 by twd】
            break;
        case ThemeHermesPink:
        {
            colorRegionColor = [SKColor colorWithRed:0.848 green:0.187 blue:0.349 alpha:1];
            faceBackgroundColor = [SKColor colorWithRed:0.387 green:0.226 blue:0.270 alpha:1];
            majorMarkColor = [SKColor colorWithRed:0.831 green:0.540 blue:0.612 alpha:1];
            backgroundImageName = @"HermesDoubleface_watch_Pink";
            hourHandImageName = @"HermesDoubleclour_Pink_H";
            minuteHandImageName = @"HermesDoubleclour_Pink_M";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 18;
            dateColor = [SKColor colorWithRed:0.960 green:0.898 blue:0.8 alpha:1.000];
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
            break;
        }
        case ThemeRoyal:
        {
            colorRegionColor = [SKColor colorWithRed:0.118 green:0.188 blue:0.239 alpha:1.000];
            faceBackgroundColor = [SKColor colorWithWhite:0.9 alpha:1.0];
            majorMarkColor = [SKColor colorWithRed:0.318 green:0.388 blue:0.539 alpha:1.000];
            backgroundImageName = @"HermesDoubleface_watch_Orange";
            hourHandImageName = @"HermesDoubleclour_Orange_H";
            minuteHandImageName = @"HermesDoubleclour_Orange_M";
            hoursAnchorFromBottom = 18;
            minutesAnchorFromBottom = 18;
            dateColor = [SKColor colorWithRed:0.898 green:0.509 blue:0.243 alpha:1.000];
            self.showDateoriginal = YES;//使用riginal系列日期【注释 by twd】
            self.showDateclassic = NO;//使用classic系列日期【注释 by twd】
            self.showDateroma = NO;//使用roma系列日期【注释 by twd】
          }
		default:
			break;
	}
    
    self.backgroundTexture = [SKTexture textureWithImageNamed:backgroundImageName];
    self.hoursHandTexture = [SKTexture textureWithImageNamed:hourHandImageName];
    self.minutesHandTexture = [SKTexture textureWithImageNamed:minuteHandImageName];
    self.secondsHandTexture = [SKTexture textureWithImageNamed:secondHandImageName];
    self.hoursAnchorFromBottom = hoursAnchorFromBottom;
    self.minutesAnchorFromBottom = minutesAnchorFromBottom;
    self.secondsAnchorFromBottom = secondsAnchorFromBottom;
    self.runsBackwards = runBackwards;
    
	self.colorRegionColor = colorRegionColor;
    self.faceBackgroundColor = faceBackgroundColor;
	self.majorMarkColor = majorMarkColor;
	self.minorMarkColor = minorMarkColor;
	self.inlayColor = inlayColor;
	self.textColor = textColor;
	self.handColor = handColor;
	self.secondHandColor = secondHandColor;
    
    self.dateColor = dateColor;//新增日期颜色
    self.alternateDateColor = alternateDateColor;//新增日期颜色
	
	self.alternateMajorMarkColor = alternateMajorMarkColor;
	self.alternateMinorMarkColor = alternateMinorMarkColor;
	self.alternateTextColor = alternateTextColor;
}

-(void)setupScene
{
	SKNode *face = [self childNodeWithName:@"Face"];
	
	SKSpriteNode *hourHand = (SKSpriteNode *)[face childNodeWithName:@"Hours"];
	SKSpriteNode *minuteHand = (SKSpriteNode *)[face childNodeWithName:@"Minutes"];
	
	SKSpriteNode *hourHandInlay = (SKSpriteNode *)[hourHand childNodeWithName:@"Hours Inlay"];
	SKSpriteNode *minuteHandInlay = (SKSpriteNode *)[minuteHand childNodeWithName:@"Minutes Inlay"];
	
	SKSpriteNode *secondHand = (SKSpriteNode *)[face childNodeWithName:@"Seconds"];
	SKSpriteNode *colorRegion = (SKSpriteNode *)[face childNodeWithName:@"Color Region"];
	SKSpriteNode *colorRegionReflection = (SKSpriteNode *)[face childNodeWithName:@"Color Region Reflection"];
	SKSpriteNode *numbers = (SKSpriteNode *)[face childNodeWithName:@"Numbers"];
	
	hourHand.color = self.handColor;
	hourHand.colorBlendFactor = 1.0;
    hourHand.texture = self.hoursHandTexture;
    hourHand.size = hourHand.texture.size;
    hourHand.anchorPoint = CGPointMake(0.5, _hoursAnchorFromBottom / hourHand.size.height);
	
	minuteHand.color = self.handColor;
	minuteHand.colorBlendFactor = 1.0;
    minuteHand.texture = self.minutesHandTexture;
    minuteHand.size = minuteHand.texture.size;
    minuteHand.anchorPoint = CGPointMake(0.5, _minutesAnchorFromBottom / minuteHand.size.height);
	
	secondHand.color = self.secondHandColor;
	secondHand.colorBlendFactor = 1.0;
    secondHand.texture = self.secondsHandTexture;
    secondHand.size = secondHand.texture.size;
    secondHand.anchorPoint = CGPointMake(0.5, _secondsAnchorFromBottom / secondHand.size.height);
	
	self.backgroundColor = self.faceBackgroundColor;
	
	colorRegion.color = self.colorRegionColor;
	colorRegion.colorBlendFactor = 1.0;
	
	numbers.color = self.textColor;
	numbers.colorBlendFactor = 1.0;
    numbers.texture = self.backgroundTexture;
    numbers.size = numbers.texture.size;
	
	hourHandInlay.color = self.inlayColor;
	hourHandInlay.colorBlendFactor = 1.0;
	
	minuteHandInlay.color = self.inlayColor;
	minuteHandInlay.colorBlendFactor = 1.0;
	
	SKSpriteNode *numbersLayer = (SKSpriteNode *)[face childNodeWithName:@"Numbers"];

	if (self.useProgrammaticLayout)
	{
		numbersLayer.alpha = 0;
		
		if (self.useRoundFace)
		{
			[self setupTickmarksForRoundFaceWithLayerName:@"Markings"];
		}
		else
		{
			[self setupTickmarksForRectangularFaceWithLayerName:@"Markings"];
		}
	}
	else
	{
		numbersLayer.alpha = 1;
	}
	
	colorRegionReflection.alpha = 0;
}


-(void)setupMasking
{
	SKCropNode *faceMarkings = (SKCropNode *)[self childNodeWithName:@"Markings"];
	SKNode *face = [self childNodeWithName:@"Face"];
	
	SKNode *colorRegion = [face childNodeWithName:@"Color Region"];
	SKNode *colorRegionReflection = [face childNodeWithName:@"Color Region Reflection"];
	
	faceMarkings.maskNode = colorRegion;
	
	self.textColor = self.alternateTextColor;
	self.minorMarkColor = self.alternateMinorMarkColor;
	self.majorMarkColor = self.alternateMajorMarkColor;
	
	
	if (self.useRoundFace)
	{
		[self setupTickmarksForRoundFaceWithLayerName:@"Markings Alternate"];
	}
	else
	{
		[self setupTickmarksForRectangularFaceWithLayerName:@"Markings Alternate"];
	}
	
	SKCropNode *alternateFaceMarkings = (SKCropNode *)[self childNodeWithName:@"Markings Alternate"];
	colorRegionReflection.alpha = 1;
	alternateFaceMarkings.maskNode = colorRegionReflection;
}

#pragma mark -

- (void)update:(NSTimeInterval)currentTime forScene:(SKScene *)scene
{
	[self updateHands];
}

-(void)updateHands
{
#if PREPARE_SCREENSHOT
	NSDate *now = [NSDate dateWithTimeIntervalSince1970:32760+27]; // 10:06:27am
#else
	NSDate *now = [NSDate date];
#endif
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond| NSCalendarUnitNanosecond) fromDate:now];
	
	SKNode *face = [self childNodeWithName:@"Face"];
	
	SKNode *hourHand = [face childNodeWithName:@"Hours"];
	SKNode *minuteHand = [face childNodeWithName:@"Minutes"];
	SKNode *secondHand = [face childNodeWithName:@"Seconds"];
	
	SKNode *colorRegion = [face childNodeWithName:@"Color Region"];
	SKNode *colorRegionReflection = [face childNodeWithName:@"Color Region Reflection"];

	hourHand.zRotation =  - (2*M_PI)/12.0 * (CGFloat)(components.hour%12 + 1.0/60.0*components.minute);
	minuteHand.zRotation =  - (2*M_PI)/60.0 * (CGFloat)(components.minute + 1.0/60.0*components.second);
	secondHand.zRotation = - (2*M_PI)/60 * (CGFloat)(components.second + 1.0/NSEC_PER_SEC*components.nanosecond);
    

	
	colorRegion.zRotation =  M_PI_2 -(2*M_PI)/60.0 * (CGFloat)(components.minute + 1.0/60.0*components.second);
	colorRegionReflection.zRotation =  M_PI_2 - (2*M_PI)/60.0 * (CGFloat)(components.minute + 1.0/60.0*components.second);
}

-(void)refreshTheme
{
	[[NSUserDefaults standardUserDefaults] setInteger:self.theme forKey:@"Theme"];
	
	SKNode *existingMarkings = [self childNodeWithName:@"Markings"];
	SKNode *existingDualMaskMarkings = [self childNodeWithName:@"Markings Alternate"];

	[existingMarkings removeAllChildren];
	[existingMarkings removeFromParent];
	
	[existingDualMaskMarkings removeAllChildren];
	[existingDualMaskMarkings removeFromParent];
	
	[self setupColors];
	[self setupScene];
	
	if (self.useMasking)
	{
		[self setupMasking];
	}
}



@end
