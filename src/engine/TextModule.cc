#include "TextModule.h"

#include "textnode.h"
#include "context.h"
#include "calc.h"
#include "builtin.h"

AbstractNode *TextModule::instantiate(const std::shared_ptr<Context>& ctx, const ModuleInstantiation *inst, const std::shared_ptr<EvalContext>& evalctx) const
{
  auto node = new TextNode(inst, evalctx);

  AssignmentList args{assignment("text"), assignment("size"), assignment("font")};
  AssignmentList optargs{
      assignment("direction"), assignment("language"), assignment("script"),
      assignment("halign"), assignment("valign"), assignment("spacing")
  };

  ContextHandle<Context> c{Context::create<Context>(ctx)};
  c->setVariables(evalctx, args, optargs);

  auto fn = c->lookup_variable("$fn")->toDouble();
  auto fa = c->lookup_variable("$fa")->toDouble();
  auto fs = c->lookup_variable("$fs")->toDouble();

  node->params.set_fn(fn);
  node->params.set_fa(fa);
  node->params.set_fs(fs);

  auto size = c->lookup_variable_with_default("size", 10.0);
  auto segments = Calc::get_fragments_from_r(size, fn, fs, fa);
  // The curved segments of most fonts are relatively short, so
  // by using a fraction of the number of full circle segments
  // the resolution will be better matching the detail level of
  // other objects.
  auto text_segments = std::max(floor(segments / 8) + 1, 2.0);

  node->params.set_size(size);
  node->params.set_segments(text_segments);
  node->params.set_text(c->lookup_variable_with_default("text", ""));
  node->params.set_spacing(c->lookup_variable_with_default("spacing", 1.0));
  node->params.set_font(c->lookup_variable_with_default("font", ""));
  node->params.set_direction(c->lookup_variable_with_default("direction", ""));
  node->params.set_language(c->lookup_variable_with_default("language", "en"));
  node->params.set_script(c->lookup_variable_with_default("script", ""));
  node->params.set_halign(c->lookup_variable_with_default("halign", "left"));
  node->params.set_valign(c->lookup_variable_with_default("valign", "baseline"));

  FreetypeRenderer renderer;
  renderer.detect_properties(node->params);

  return node;
}


