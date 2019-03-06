//
//  main.m
//  map-keys-on-attach
//
#include "AssertMacros.h"

@import Foundation;
@import IOKit;
@import IOKit.hid;
@import IOKit.hidsystem;
@import XPC;

#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>


/*
 ** This is the Maltron Keyboard
 */
static uint32_t     _idVendor = 0x4d8;
static NSNumber* the_idVendor;
static uint32_t     _idProduct = 0x55;
static NSNumber* the_idProduct;

static const uint64_t kMask = 0x700000000;

void invoke_mapping(uint64_t _regId)
{
    /*
     * `                  = 0x35
     * Menu (Application) = 0x65
     * Escape             = 0x29
     * Help (Insert)      = 0x49
     */
    uint64_t backtick = 0x35, menu = 0x65, esc = 0x29, help = 0x49;
    NSArray* map = @[
                     @{@kIOHIDKeyboardModifierMappingSrcKey:@(backtick | kMask),
                        @kIOHIDKeyboardModifierMappingDstKey:@(menu | kMask)},
                     @{@kIOHIDKeyboardModifierMappingSrcKey:@(menu | kMask),
                        @kIOHIDKeyboardModifierMappingDstKey:@(backtick | kMask)},
                     @{@kIOHIDKeyboardModifierMappingSrcKey:@(esc | kMask),
                        @kIOHIDKeyboardModifierMappingDstKey:@(help | kMask)},
                     @{@kIOHIDKeyboardModifierMappingSrcKey:@(help | kMask),
                        @kIOHIDKeyboardModifierMappingDstKey:@(esc | kMask)}];

    NSNumber* regId = [NSNumber numberWithUnsignedInteger:_regId];
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault);
    NSArray* services = (NSArray *)CFBridgingRelease(IOHIDEventSystemClientCopyServices(client));
    if (services) {
        for (id s in services) {
            IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)s;
            id value = CFBridgingRelease(IOHIDServiceClientGetRegistryID(service));
            if ([value isEqualToNumber: regId]) {
                if (IOHIDServiceClientSetProperty(service,
                                                  CFSTR(kIOHIDUserKeyUsageMapKey),
                                                  (__bridge CFArrayRef)map)) {
                    NSLog(@"Mapping OK: %@", map);
                } else {
                    NSLog(@"Mapping Failed");
                }
                break;
            }
        }
    }
}

uint64_t checkIODevice(io_service_t dev)
{

    uint64_t regId = 0;
    NSNumber* idVendor = NULL;
    NSNumber* idProduct = NULL;

    io_name_t name = {0};
    IORegistryEntryGetName(dev, name);
    NSLog(@"Dev name: %s", name);

    idVendor = (NSNumber*) CFBridgingRelease(IORegistryEntryCreateCFProperty(dev, CFSTR("VendorID"), NULL, 0));
    __Require_Quiet(idVendor, exit);

    NSLog(@"Dev vendor: %@ (want: %@)", idVendor, the_idVendor);
    __Require_Quiet([idVendor isEqualToNumber: the_idVendor], exit);

    idProduct = (NSNumber*) CFBridgingRelease(IORegistryEntryCreateCFProperty(dev, CFSTR("ProductID"), NULL, 0));
    __Require_Quiet(idProduct, exit);

    NSLog(@"Dev product: %@ (want: %@)", idProduct, the_idProduct);
    __Require_Quiet([idProduct isEqualToNumber: the_idProduct], exit);

    IORegistryEntryGetRegistryEntryID(dev, &regId);
    NSLog(@"Dev regId: %llu", regId);

exit:
    return regId;
}

int main(int argc, char *argv[])
{
    the_idVendor = [NSNumber numberWithInt: _idVendor];
    the_idProduct = [NSNumber numberWithInt: _idProduct];

    const char* match_name = "com.apple.iokit.matching";
    const dispatch_queue_t q = dispatch_get_main_queue();

    xpc_set_event_stream_handler(match_name, q, ^(xpc_object_t event) {
        const char *name = xpc_dictionary_get_string(event, XPC_EVENT_KEY_NAME);
        uint64_t service_id = xpc_dictionary_get_uint64(event, "IOMatchLaunchServiceID");
        io_iterator_t serviceIterator = {0};
        IOServiceGetMatchingServices(kIOMasterPortDefault,
                                     IORegistryEntryIDMatching(service_id),
                                     &serviceIterator);
        if (serviceIterator) {
            @autoreleasepool {
                uint64_t regId = 0;
                io_service_t curr = {0};
                while (IOIteratorIsValid(serviceIterator) &&
                       (curr = IOIteratorNext(serviceIterator))) {
                    if ((regId = checkIODevice(curr))) {
                        invoke_mapping(regId);
                        exit(0);
                    }
                }
            }
        }
    });
    dispatch_main();
}
