#ifndef SST__SIGNAL_HANDLER
#define SST__SIGNAL_HANDLER

#include "runtime_context.hh"

namespace sst::runtime {

void register_signal_handler(int signal, context context);

}

#endif  // SST__SIGNAL_HANDLER
