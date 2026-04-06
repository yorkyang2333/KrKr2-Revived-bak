//
// Created by LiDon on 2025/9/15.
//
#pragma once

#include "tjs.h"

namespace motion {

    class Player {
    public:
        Player();

        tTJSVariant getMotion() const;
        void setMotion(tTJSVariant value);

        tjs_int getCount() const;
        void setCount(tjs_int value);

        tjs_real getLoopTime() const;
        void setLoopTime(tjs_real value);

        tTJSVariant getVariableKeys() const;
        void setVariableKeys(tTJSVariant value);

        tjs_int getOutline() const;
        void setOutline(tjs_int value);

    private:
        void setDefaultVariableKeys();

        tTJSVariant motion_;
        tTJSVariant variableKeys_;
        tjs_int count_ = 0;
        tjs_real loopTime_ = 0.0;
        tjs_int outline_ = 0;
    };

} // namespace motion
