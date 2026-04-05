#pragma once

class tTVPSystemControl {
private:
    bool ContinuousEventCalling = false;
    bool EventEnable = true;

public:
    tTVPSystemControl();

    void InvokeEvents();
    void CallDeliverAllEventsOnIdle();

    void BeginContinuousEvent();
    void EndContinuousEvent();

    void NotifyCloseClicked();
    void NotifyEventDelivered();

    void SetEventEnabled(bool enabled) { EventEnable = enabled; }
    [[nodiscard]] bool GetEventEnabled() const { return EventEnable; }

    bool ApplicationIdle();
};

extern tTVPSystemControl *TVPSystemControl;
extern bool TVPSystemControlAlive;
