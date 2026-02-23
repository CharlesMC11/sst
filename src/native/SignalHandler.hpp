#pragma once

#include "RuntimeContext.hpp"

namespace sst::runtime {

void registerSignalHandler(int signal, Context context);

}
