#pragma once

#include "PSBFile.h"

namespace PSB {

tTJSVariant BuildCompatVariant(const std::shared_ptr<IPSBValue> &value,
                               bool rootIsMotion = false, int depth = 0);

tTJSVariant BuildCompatRootVariant(const PSBFile &file);

} // namespace PSB
