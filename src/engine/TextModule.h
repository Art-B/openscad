#ifndef OPENSCAD_TEXTMODULE_H
#define OPENSCAD_TEXTMODULE_H

#include "module.h"

class TextModule : public AbstractModule
{
public:
  TextModule() : AbstractModule() { }
  AbstractNode *instantiate(const std::shared_ptr<Context>& ctx, const ModuleInstantiation *inst, const std::shared_ptr<EvalContext>& evalctx) const override;
};

#endif // OPENSCAD_TEXTMODULE_H
