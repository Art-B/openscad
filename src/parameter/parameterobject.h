#pragma once

#include "engine/value.h"
#include "engine/Assignment.h"
#include "engine/expression.h"

#include <QString>

class ParameterObject
{
public:
	typedef enum { UNDEFINED, COMBOBOX, SLIDER, CHECKBOX, TEXT, NUMBER, VECTOR } parameter_type_t;

	ValuePtr value;
	ValuePtr values;
	ValuePtr defaultValue;
	Value::Type dvt;
	parameter_type_t target;
	QString description;
	std::string name;
	bool set;
	std::string groupName;

private:
	Value::Type vt;
	parameter_type_t checkVectorWidget();
	void setValue(const ValuePtr defaultValue, const ValuePtr values);

public:
	ParameterObject(std::shared_ptr<Context> context, const shared_ptr<Assignment> &assignment, const ValuePtr defaultValue);
	void applyParameter(const shared_ptr<Assignment> &assignment);
	bool operator==(const ParameterObject &second);
};
