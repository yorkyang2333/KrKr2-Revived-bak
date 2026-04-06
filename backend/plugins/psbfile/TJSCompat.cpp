#include "TJSCompat.h"

#include <initializer_list>
#include <optional>

#include "tjsArray.h"
#include "tjsDictionary.h"

namespace PSB {
namespace {

constexpr int kMaxCompatDepth = 24;

void SetMember(iTJSDispatch2 *obj, const tjs_char *name,
               const tTJSVariant &value) {
    tTJSVariant copy(value);
    obj->PropSet(TJS_MEMBERENSURE, name, nullptr, &copy, obj);
}

bool TryGetNumeric(const std::shared_ptr<IPSBValue> &value, tjs_real &out) {
    if(!value) {
        return false;
    }
    if(const auto number = std::dynamic_pointer_cast<PSBNumber>(value)) {
        switch(number->numberType) {
            case PSBNumberType::Int:
                out = number->getValue<int>();
                return true;
            case PSBNumberType::Long:
                out = static_cast<tjs_real>(number->getValue<tjs_int64>());
                return true;
            case PSBNumberType::Float:
                out = number->getValue<float>();
                return true;
            case PSBNumberType::Double:
                out = number->getValue<double>();
                return true;
        }
    }
    if(const auto boolean = std::dynamic_pointer_cast<PSBBool>(value)) {
        out = boolean->value ? 1.0 : 0.0;
        return true;
    }
    return false;
}

size_t TryGetCollectionSize(const std::shared_ptr<IPSBValue> &value) {
    if(!value) {
        return 0;
    }
    if(const auto list = std::dynamic_pointer_cast<PSBList>(value)) {
        return list->size();
    }
    if(const auto array = std::dynamic_pointer_cast<PSBArray>(value)) {
        return array->value.size();
    }
    if(const auto dict = std::dynamic_pointer_cast<PSBDictionary>(value)) {
        return static_cast<size_t>(std::distance(dict->begin(), dict->end()));
    }
    return 0;
}

std::shared_ptr<IPSBValue>
FindFirstValue(const std::shared_ptr<const PSBDictionary> &dict,
               std::initializer_list<const char *> names) {
    if(!dict) {
        return nullptr;
    }
    for(const char *name : names) {
        auto it = dict->find(name);
        if(it != dict->end()) {
            return it->second;
        }
    }
    return nullptr;
}

tTJSVariant MakeArray(const std::vector<tTJSVariant> &values) {
    iTJSDispatch2 *array = TJSCreateArrayObject();
    static tjs_uint addHint = 0;
    for(const auto &value : values) {
        tTJSVariant copy(value);
        tTJSVariant *args[] = { &copy };
        array->FuncCall(0, TJS_W("add"), &addHint, nullptr, 1, args, array);
    }

    tTJSVariant result(array, array);
    array->Release();
    return result;
}

tTJSVariant MakeStringArray(const std::shared_ptr<const PSBDictionary> &dict) {
    std::vector<tTJSVariant> values;
    if(dict) {
        for(const auto &[key, _] : *dict) {
            values.emplace_back(ttstr(key));
        }
    }
    return MakeArray(values);
}

tTJSVariant BuildCompatDictionary(const std::shared_ptr<const PSBDictionary> &dict,
                                  bool rootIsMotion, int depth) {
    iTJSDispatch2 *obj = TJSCreateDictionaryObject();

    for(const auto &[key, value] : *dict) {
        SetMember(obj, ttstr(key).c_str(),
                  BuildCompatVariant(value, false, depth + 1));
    }

    const auto motionCandidate =
        FindFirstValue(dict, { "motion", "source", "motions", "data" });

    const bool motionLike = rootIsMotion || motionCandidate != nullptr ||
        FindFirstValue(dict, { "loopTime", "duration", "time", "variables" }) !=
            nullptr;

    tTJSVariant result(obj, obj);

    if(motionLike) {
        if(motionCandidate) {
            SetMember(obj, TJS_W("motion"),
                      BuildCompatVariant(motionCandidate, false, depth + 1));
        } else {
            SetMember(obj, TJS_W("motion"), result);
        }

        if(FindFirstValue(dict, { "outline" }) == nullptr) {
            SetMember(obj, TJS_W("outline"), tTJSVariant((tjs_int)0));
        }

        if(FindFirstValue(dict, { "variableKeys" }) == nullptr) {
            const auto variables =
                FindFirstValue(dict, { "variables", "vars", "variableMap" });
            if(const auto variableDict =
                   std::dynamic_pointer_cast<const PSBDictionary>(variables)) {
                SetMember(obj, TJS_W("variableKeys"), MakeStringArray(variableDict));
            } else {
                SetMember(obj, TJS_W("variableKeys"), MakeArray({}));
            }
        }

        if(FindFirstValue(dict, { "count" }) == nullptr) {
            const auto countSource = FindFirstValue(
                dict, { "frames", "motions", "children", "variables",
                        "variableKeys", "keys" });
            const tjs_int count =
                static_cast<tjs_int>(TryGetCollectionSize(countSource));
            SetMember(obj, TJS_W("count"), tTJSVariant(count));
        }

        if(FindFirstValue(dict, { "loopTime" }) == nullptr) {
            const auto timeSource = FindFirstValue(
                dict, { "duration", "time", "length", "totalTime",
                        "frameTime", "loop_length" });
            tjs_real value = 0.0;
            if(!TryGetNumeric(timeSource, value)) {
                value = 0.0;
            }
            SetMember(obj, TJS_W("loopTime"), tTJSVariant(value));
        }
    }

    obj->Release();
    return result;
}

tTJSVariant BuildCompatList(const std::shared_ptr<const PSBList> &list,
                            int depth) {
    std::vector<tTJSVariant> values;
    values.reserve(list->size());
    for(const auto &value : *list) {
        values.emplace_back(BuildCompatVariant(value, false, depth + 1));
    }
    return MakeArray(values);
}

} // namespace

tTJSVariant BuildCompatVariant(const std::shared_ptr<IPSBValue> &value,
                               bool rootIsMotion, int depth) {
    if(!value || depth > kMaxCompatDepth) {
        return {};
    }
    if(const auto dict = std::dynamic_pointer_cast<const PSBDictionary>(value)) {
        return BuildCompatDictionary(dict, rootIsMotion, depth);
    }
    if(const auto list = std::dynamic_pointer_cast<const PSBList>(value)) {
        return BuildCompatList(list, depth);
    }
    return value->toTJSVal();
}

tTJSVariant BuildCompatRootVariant(const PSBFile &file) {
    return BuildCompatVariant(
        std::const_pointer_cast<IPSBValue>(
            std::dynamic_pointer_cast<const IPSBValue>(file.getObjects())),
        file.getType() == PSBType::Motion);
}

} // namespace PSB
