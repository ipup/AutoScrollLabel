//
//  CBAutoScrollLabel.m
//  CBAutoScrollLabel
//
//  Created by Brian Stormont on 10/21/09.
//  Updated by Christopher Bess on 2/5/12
//
//  Copyright 2009 Stormy Productions. 
//
//  Permission is granted to use this code free of charge for any project.
//

#import "CBAutoScrollLabel.h"
#import <QuartzCore/QuartzCore.h>
#import "SimpleAttributedLabel.h"
#import "MOScrollView.h"

#define kLabelCount 2
// pixel buffer space between scrolling label
#define kDefaultLabelBufferSpace 20
#define kDefaultPixelsPerSecond 30
#define kDefaultPauseTime 1.5f

// shortcut method for NSArray iterations
static void each_object(NSArray *objects, void (^block)(id object))
{
    for (id obj in objects)
        block(obj);
}

// shortcut to change each label attribute value
#define EACH_LABEL(ATTR, VALUE) each_object(self.labels, ^(SimpleAttributedLabel *label) { label.ATTR = VALUE; });

@interface CBAutoScrollLabel ()
{
	BOOL _isScrolling;
}
@property (nonatomic, strong) NSArray *labels;
@property (strong, nonatomic, readonly) SimpleAttributedLabel *mainLabel;
@property (nonatomic, strong) MOScrollView *scrollView;

@end

@implementation CBAutoScrollLabel

@synthesize scrollDirection = _scrollDirection;
@synthesize pauseInterval = _pauseInterval;
@synthesize labelSpacing = _labelSpacing;
@synthesize scrollSpeed = _scrollSpeed;
@synthesize text;
@synthesize labels;
@synthesize mainLabel;
@synthesize animationOptions;
@synthesize shadowColor;
@synthesize shadowOffset;
@synthesize textAlignment;
@synthesize scrolling = _isScrolling;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
     	[self commonInit];
    }
    return self;	
}

- (id)initWithFrame:(CGRect)frame 
{
    if ((self = [super initWithFrame:frame]))
    {
		[self commonInit];
    }
    return self;
}

- (void)commonInit
{
    // create the labels
    NSMutableSet *labelSet = [[NSMutableSet alloc] initWithCapacity:kLabelCount];
	for (int index = 0 ; index < kLabelCount ; ++index)
    {
		SimpleAttributedLabel *label = [[SimpleAttributedLabel alloc] init];
		//label.textColor = [UIColor whiteColor];
		label.backgroundColor = [UIColor clearColor];
        
        // store labels
		[self.scrollView addSubview:label];
        [labelSet addObject:label];
        
        #if ! __has_feature(objc_arc)
        [label release];
        #endif
	}
	
    self.labels = [labelSet.allObjects copy];
    
    #if ! __has_feature(objc_arc)
    [labelSet release];
    #endif
    
    // default values
	_scrollDirection = CBAutoScrollDirectionLeft;
	_scrollSpeed = kDefaultPixelsPerSecond;
	_pauseInterval = kDefaultPauseTime;
	_labelSpacing = kDefaultLabelBufferSpace;
    self.textAlignment = UITextAlignmentLeft;
    self.animationOptions = UIViewAnimationOptionCurveEaseIn;
	self.scrollView.showsVerticalScrollIndicator = NO;
	self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.scrollEnabled = NO;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
}

- (void)dealloc 
{
    self.labels = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(enableShadow) object:nil];
    #if ! __has_feature(objc_arc)
    [super dealloc];
    #endif
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self refreshLabels];
    [self applyGradientMaskForFadeLength:self.fadeLength enableLeft:_isScrolling];
}

#pragma mark - Properties

- (UIScrollView *)scrollView
{
    if (_scrollView == nil)
    {
        _scrollView = [[MOScrollView alloc] initWithFrame:self.bounds];
        _scrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        _scrollView.backgroundColor = [UIColor clearColor];
        
        [self addSubview:_scrollView];
        
#if ! __has_feature(objc_arc)
        [_scrollView release];
#endif
    }
    return _scrollView;
}

- (void)setFadeLength:(CGFloat)fadeLength
{
    if (_fadeLength != fadeLength)
    {
        _fadeLength = fadeLength;
        
        [self refreshLabels];
        [self applyGradientMaskForFadeLength:fadeLength enableLeft:NO];
    }
}

- (SimpleAttributedLabel *)mainLabel
{
    return [self.labels objectAtIndex:0];
}

- (void) setText:(NSString *)theText
{
    [self setText:theText andRefreshLabels:YES];
}

- (void)setText:(NSString *)theText andRefreshLabels:(BOOL)refresh
{
    // ignore identical text changes
	if ([theText isEqualToString:self.text])
		return;
	
    EACH_LABEL(text, theText)
    
    if (refresh)
        [self refreshLabels];
}

- (NSString *)text
{
	return self.mainLabel.text;
}

- (void) setAttributedText:(NSAttributedString *)theText
{
    [self setAttributedText:theText andRefreshLabels:YES];
}

- (void)setAttributedText:(NSAttributedString *)theText andRefreshLabels:(BOOL)refresh
{
    // ignore identical text changes
	if ([theText.string isEqualToString:self.attributedText.string])
		return;
	
    EACH_LABEL(attributedText, theText)
    
    if (refresh)
        [self refreshLabels];
}

- (NSAttributedString *)setAttributedText
{
	return self.mainLabel.attributedText;
}

- (void)setTextColor:(UIColor *)color
{
    EACH_LABEL(textColor, color)
}

- (UIColor *)textColor
{
	return self.mainLabel.textColor;
}

- (void)setFont:(UIFont *)font
{
    EACH_LABEL(font, font)
    
	[self refreshLabels];
}

- (UIFont *)font
{
	return self.mainLabel.font;
}

- (void)setScrollSpeed:(float)speed
{
	_scrollSpeed = speed;
    
    [self scrollLabelIfNeeded];
}

- (void)setScrollDirection:(CBAutoScrollDirection)direction
{
	_scrollDirection = direction;
    
    [self scrollLabelIfNeeded];
}

- (void)setShadowColor:(UIColor *)color
{
    EACH_LABEL(shadowColor, color)
}

- (UIColor *)shadowColor
{
    return self.mainLabel.shadowColor;
}

- (void)setShadowOffset:(CGSize)offset
{
    EACH_LABEL(shadowOffset, offset)
}

- (CGSize)shadowOffset
{
    return self.mainLabel.shadowOffset;
}

#pragma mark - Misc

- (void) enableShadow
{
    _isScrolling = YES;
    [self applyGradientMaskForFadeLength:self.fadeLength enableLeft:YES];
}

- (void)scrollLabelIfNeeded
{
    CGFloat labelWidth = CGRectGetWidth(self.mainLabel.bounds);
	if (labelWidth <= CGRectGetWidth(self.bounds))
        return;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollLabelIfNeeded) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(enableShadow) object:nil];
    
    BOOL doScrollLeft = (self.scrollDirection == CBAutoScrollDirectionLeft);
    self.scrollView.contentOffset = (doScrollLeft ? CGPointMake(0.0f, 0.0f) : CGPointMake(labelWidth + _labelSpacing, 0));
    
    // Add the right shadow
    [self applyGradientMaskForFadeLength:self.fadeLength enableLeft:NO];
    
    // Add the left shadow after delay
    [self performSelector:@selector(enableShadow) withObject:nil afterDelay:self.pauseInterval];
    
    // animate the scrolling
    NSTimeInterval duration = labelWidth / self.scrollSpeed;
//    SEL selector = @selector(_setContentOffsetAnimationDuration:);
//    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self.scrollView methodSignatureForSelector:selector]];
//    
//    [invocation setSelector:selector];
//    [invocation setTarget:self.scrollView];
//    [invocation setArgument:&duration atIndex:2];
//    [invocation invoke];

    
//    [self.scrollView setContentOffset:(doScrollLeft ? CGPointMake(labelWidth + _labelSpacing, 0) : CGPointZero) animated:YES];
//    

    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.pauseInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.scrollView setContentOffset:(doScrollLeft ? CGPointMake(labelWidth + _labelSpacing, 0) : CGPointZero) withTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn] duration:duration];
    });
   
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((self.pauseInterval + duration) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _isScrolling = NO;
        
        // remove the left shadow
        [self applyGradientMaskForFadeLength:self.fadeLength enableLeft:NO];
        
        // setup pause delay/loop
        [self performSelector:@selector(scrollLabelIfNeeded) withObject:nil];
    });
}

- (void)refreshLabels
{
    if (!self.text) return;
    
    // calculate the label size
    CGSize labelSize = [self.mainLabel.text sizeWithAttributes:@{NSFontAttributeName: self.mainLabel.font}];
    
    __block float offset = 0.0f;

    each_object(self.labels, ^(SimpleAttributedLabel *label) {
        CGRect frame = label.frame;
        frame.origin.x = offset;
        frame.size.height = CGRectGetHeight(self.bounds);
        frame.size.width = labelSize.width + 2 /*Magic number*/;
        label.frame = frame;

        
        // Recenter label vertically within the scroll view
        label.center = CGPointMake(label.center.x, roundf(self.center.y - CGRectGetMinY(self.frame)));
        
        offset += CGRectGetWidth(label.bounds) + _labelSpacing;
    });
    
	self.scrollView.contentOffset = CGPointZero;

	// if the label is bigger than the space allocated, then it should scroll
	if (CGRectGetWidth(self.mainLabel.bounds) > CGRectGetWidth(self.bounds) )
    {
        CGSize size;
        size.width = CGRectGetWidth(self.mainLabel.bounds) * 2.0f + _labelSpacing;
        size.height = CGRectGetHeight(self.bounds);
        self.scrollView.contentSize = size;

        EACH_LABEL(hidden, NO)
        
        [self applyGradientMaskForFadeLength:self.fadeLength enableLeft:_isScrolling];

		[self scrollLabelIfNeeded];
	}
    else
    {
		// Hide the other labels
        EACH_LABEL(hidden, (self.mainLabel != label))
        
        // adjust the scroll view and main label
        self.scrollView.contentSize = self.bounds.size;
        self.mainLabel.frame = self.bounds;
        self.mainLabel.hidden = NO;
        //self.mainLabel.textAlignment = self.textAlignment;
        
        [self applyGradientMaskForFadeLength:0 enableLeft:NO];
	}
}

#pragma mark - Gradient

// ref: https://github.com/cbpowell/MarqueeLabel
- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength enableLeft:(BOOL)enableLeft
{
    CGFloat labelWidth = CGRectGetWidth(self.mainLabel.bounds);
	if (labelWidth <= CGRectGetWidth(self.bounds))
        fadeLength = 0.0;

    if (fadeLength)
    {
        // Recreate gradient mask with new fade length
        CAGradientLayer *gradientMask = [CAGradientLayer layer];
        
        gradientMask.bounds = self.layer.bounds;
        gradientMask.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        
        gradientMask.shouldRasterize = YES;
        gradientMask.rasterizationScale = [UIScreen mainScreen].scale;
        
        gradientMask.startPoint = CGPointMake(0.0, CGRectGetMidY(self.frame));
        gradientMask.endPoint = CGPointMake(1.0, CGRectGetMidY(self.frame));

        // setup fade mask colors and location
        id transparent = (id)[[UIColor clearColor] CGColor];
        id opaque = (id)[[UIColor blackColor] CGColor];
        CGFloat fadePoint = fadeLength / CGRectGetWidth(self.bounds);
        gradientMask.colors = @[transparent, opaque, opaque, transparent];
        gradientMask.locations = @[@0, enableLeft ? @(fadePoint) : @0, @(1 - fadePoint), @1];
        
        self.layer.mask = gradientMask;
    }
    else
    {
        // Remove gradient mask for 0.0f lenth fade length
        self.layer.mask = nil;
    }
}

@end
