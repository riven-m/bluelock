//
//  CBUUID+StringExtraction.m
//  Smartlock
//
//  Created by RivenL on 15/3/16.
//  Copyright (c) 2015年 RivenL. All rights reserved.
//

#import "CBUUID+StringExtraction.h"

@implementation CBUUID (StringExtraction)
/*----------------------------------------------------*/
#pragma mark - Helper Methods -
/*----------------------------------------------------*/
- (NSString *)representativeString {
    NSData *data = [self data];
    NSUInteger bytesToConvert = [data length];
    const unsigned char *uuidBytes = [data bytes];
    NSMutableString *outputString = [NSMutableString stringWithCapacity:16];
    
    for(NSUInteger currentByteIndex=0; currentByteIndex < bytesToConvert; currentByteIndex++) {
        switch (currentByteIndex) {
            case 3:
            case 5:
            case 7:
            case 9:
                [outputString appendFormat:@"%02x-", uuidBytes[currentByteIndex]];
                break;
            default:
                [outputString appendFormat:@"%02x", uuidBytes[currentByteIndex]];
                break;
        }
    }
    
    return outputString;
}
@end
