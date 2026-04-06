//
// Created by LiDon on 2025/9/15.
//

#include "Player.h"

#include "tjsArray.h"
#include "tjsDictionary.h"
#include "tjsObject.h"

namespace motion {

namespace {

tTJSVariant CreateEmptyArrayVariant() {
    iTJSDispatch2 *array = TJSCreateArrayObject();
    tTJSVariant result(array, array);
    array->Release();
    return result;
}

tTJSVariant CreateEmptyMotionVariant(const tTJSVariant &variableKeys) {
    iTJSDispatch2 *obj = TJSCreateDictionaryObject();
    tTJSVariant result(obj, obj);
    tTJSVariant zeroInt((tjs_int)0);
    tTJSVariant zeroReal((tjs_real)0.0);

    obj->PropSet(TJS_MEMBERENSURE, TJS_W("motion"), nullptr, &result, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("count"), nullptr, &zeroInt, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("outline"), nullptr, &zeroInt, obj);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("loopTime"), nullptr, &zeroReal, obj);

    tTJSVariant variableKeysCopy(variableKeys);
    obj->PropSet(TJS_MEMBERENSURE, TJS_W("variableKeys"), nullptr,
                 &variableKeysCopy, obj);
    obj->Release();
    return result;
}

void SetObjectMemberIfPresent(const tTJSVariant &target, const tjs_char *name,
                              const tTJSVariant &value) {
    if(target.Type() != tvtObject) {
        return;
    }

    iTJSDispatch2 *obj = target.AsObjectNoAddRef();
    if(!obj) {
        return;
    }

    tTJSVariant copy(value);
    obj->PropSet(TJS_MEMBERENSURE, name, nullptr, &copy, obj);
}

bool TryReadObjectMember(const tTJSVariant &target, const tjs_char *name,
                         tTJSVariant &value) {
    if(target.Type() != tvtObject) {
        return false;
    }

    iTJSDispatch2 *obj = target.AsObjectNoAddRef();
    if(!obj) {
        return false;
    }

    return TJS_SUCCEEDED(obj->PropGet(0, name, nullptr, &value, obj));
}

} // namespace

Player::Player() {
    setDefaultVariableKeys();
    motion_ = CreateEmptyMotionVariant(variableKeys_);
}

tTJSVariant Player::getMotion() const {
    return motion_;
}

void Player::setMotion(tTJSVariant value) {
    motion_ = value;

    tTJSVariant prop;
    if(TryReadObjectMember(motion_, TJS_W("count"), prop)) {
        try {
            count_ = static_cast<tjs_int>(prop.AsInteger());
        } catch(...) {
        }
    }
    if(TryReadObjectMember(motion_, TJS_W("loopTime"), prop)) {
        try {
            loopTime_ = static_cast<tjs_real>(prop.AsReal());
        } catch(...) {
        }
    }
    if(TryReadObjectMember(motion_, TJS_W("outline"), prop)) {
        try {
            outline_ = static_cast<tjs_int>(prop.AsInteger());
        } catch(...) {
        }
    }
    if(TryReadObjectMember(motion_, TJS_W("variableKeys"), prop)) {
        variableKeys_ = prop;
    } else {
        SetObjectMemberIfPresent(motion_, TJS_W("variableKeys"), variableKeys_);
    }
}

tjs_int Player::getCount() const {
    return count_;
}

void Player::setCount(tjs_int value) {
    count_ = value;
    SetObjectMemberIfPresent(motion_, TJS_W("count"), tTJSVariant(value));
}

tjs_real Player::getLoopTime() const {
    return loopTime_;
}

void Player::setLoopTime(tjs_real value) {
    loopTime_ = value;
    SetObjectMemberIfPresent(motion_, TJS_W("loopTime"), tTJSVariant(value));
}

tTJSVariant Player::getVariableKeys() const {
    return variableKeys_;
}

void Player::setVariableKeys(tTJSVariant value) {
    variableKeys_ = value;
    SetObjectMemberIfPresent(motion_, TJS_W("variableKeys"), variableKeys_);
}

tjs_int Player::getOutline() const {
    return outline_;
}

void Player::setOutline(tjs_int value) {
    outline_ = value;
    SetObjectMemberIfPresent(motion_, TJS_W("outline"), tTJSVariant(value));
}

void Player::setDefaultVariableKeys() {
    variableKeys_ = CreateEmptyArrayVariant();
}

} // namespace motion
