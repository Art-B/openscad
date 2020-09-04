#pragma once

#include "node.h"
#include "math/linalg.h"

class TransformNode : public AbstractNode
{
public:
	VISITABLE();
	EIGEN_MAKE_ALIGNED_OPERATOR_NEW
	TransformNode(const ModuleInstantiation *mi, const std::shared_ptr<EvalContext> &ctx);
	std::string toString() const override;
	std::string name() const override;

	Transform3d matrix;
};
