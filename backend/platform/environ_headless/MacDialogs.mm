#import <AppKit/AppKit.h>
#import <dispatch/dispatch.h>

#include "Platform.h"

static int ShowSimpleInputBoxOnMainThread(
    ttstr &text,
    const ttstr &caption,
    const ttstr &prompt,
    const std::vector<ttstr> &vecButtons
) {
    std::string utf8Caption = caption.AsStdString();
    std::string utf8Prompt = prompt.AsStdString();
    std::string utf8Text = text.AsStdString();

    NSString *nsCaption = [NSString stringWithUTF8String:utf8Caption.c_str()];
    NSString *nsPrompt = [NSString stringWithUTF8String:utf8Prompt.c_str()];
    NSString *nsText = [NSString stringWithUTF8String:utf8Text.c_str()];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:nsCaption ?: @""];
    [alert setInformativeText:nsPrompt ?: @""];
    [alert setAlertStyle:NSAlertStyleInformational];

    NSTextField *inputField =
        [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 24)];
    [inputField setStringValue:nsText ?: @""];
    [alert setAccessoryView:inputField];

    if(vecButtons.empty()) {
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
    } else {
        for(const ttstr &button : vecButtons) {
            std::string utf8Button = button.AsStdString();
            NSString *nsButton =
                [NSString stringWithUTF8String:utf8Button.c_str()];
            [alert addButtonWithTitle:nsButton ?: @""];
        }
    }

    [alert.window setInitialFirstResponder:inputField];
    [inputField selectText:nil];

    NSInteger response = [alert runModal];
    text = ttstr([[inputField stringValue] UTF8String]);

    return static_cast<int>(response - NSAlertFirstButtonReturn);
}

int TVPShowSimpleInputBox(
    ttstr &text,
    const ttstr &caption,
    const ttstr &prompt,
    const std::vector<ttstr> &vecButtons
) {
    if([NSThread isMainThread]) {
        return ShowSimpleInputBoxOnMainThread(text, caption, prompt, vecButtons);
    }

    __block int result = -1;
    __block ttstr capturedText = text;
    dispatch_sync(dispatch_get_main_queue(), ^{
        result = ShowSimpleInputBoxOnMainThread(
            capturedText,
            caption,
            prompt,
            vecButtons
        );
    });
    text = capturedText;
    return result;
}
