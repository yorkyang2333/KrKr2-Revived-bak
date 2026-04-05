#include "SystemControl.h"

#include "Application.h"
#include "EventIntf.h"

tTVPSystemControl::tTVPSystemControl() = default;

static tTVPSystemControl g_headlessSystemControl;
tTVPSystemControl *TVPSystemControl = &g_headlessSystemControl;
bool TVPSystemControlAlive = true;

void tTVPSystemControl::InvokeEvents() {
    CallDeliverAllEventsOnIdle();
}

void tTVPSystemControl::CallDeliverAllEventsOnIdle() {
    // Headless mode is polled from krkr2_tick(), so there is no native event
    // queue to poke here.
}

void tTVPSystemControl::BeginContinuousEvent() {
    ContinuousEventCalling = true;
}

void tTVPSystemControl::EndContinuousEvent() {
    ContinuousEventCalling = false;
}

void tTVPSystemControl::NotifyCloseClicked() {}

void tTVPSystemControl::NotifyEventDelivered() {}

bool tTVPSystemControl::ApplicationIdle() {
    if(ContinuousEventCalling) {
        TVPProcessContinuousHandlerEventFlag = true;
    }

    if(EventEnable) {
        TVPDeliverAllEvents();
    }

    return !ContinuousEventCalling;
}
