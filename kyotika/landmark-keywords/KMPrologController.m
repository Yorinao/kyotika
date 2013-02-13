//
//  KMPrologController.m
//  kyotika
//
//  Created by kunii on 2013/02/02.
//  Copyright (c) 2013年 國居貴浩. All rights reserved.
//

#import "KMPrologController.h"

@interface KMPrologController ()
@property (assign) IBOutlet UIScrollView* scrollView;
@property (strong) IBOutlet UIView* contentsView;
@end

@implementation KMPrologController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"About", @"About");
        self.tabBarItem.image = [UIImage imageNamed:@"About"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_scrollView flashScrollIndicators];
    _scrollView.contentSize = _contentsView.bounds.size;
    [_scrollView addSubview:_contentsView];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
