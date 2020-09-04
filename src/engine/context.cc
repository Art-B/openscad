/*
 *  OpenSCAD (www.openscad.org)
 *  Copyright (C) 2009-2011 Clifford Wolf <clifford@clifford.at> and
 *                          Marius Kintel <marius@kintel.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  As a special exception, you have permission to link this program
 *  with the CGAL library and distribute executables, as long as you
 *  follow the requirements of the GNU GPL in regard to all of the
 *  software in the executable aside from CGAL.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */
 
#include "compiler_specific.h"
#include "context.h"
#include "evalcontext.h"
#include "expression.h"
#include "function.h"
#include "UserModule.h"
#include "ModuleInstantiation.h"
#include "builtin.h"
#include "../common/printutils.h"
#include <boost/filesystem.hpp>
#include "../common/boost-utils.h"
namespace fs = boost::filesystem;

// $children is not a config_variable. config_variables have dynamic scope, 
// meaning they are passed down the call chain implicitly.
// $children is simply misnamed and shouldn't have included the '$'.
static bool is_config_variable(const std::string &name)
{
	return name[0] == '$' && name != "$children";
}

/*!
	Initializes this context. Optionally initializes a context for an 
	external library. Note that if parent is null, a new stack will be
	created, and all children will share the root parent's stack.
*/
Context::Context(const std::shared_ptr<Context> parent) : parent(parent)
{
	if (parent) {
		assert(parent->ctx_stack && "Parent context stack was null!");
		this->ctx_stack = parent->ctx_stack;
		this->document_path = parent->document_path;
	}
	else {
		this->ctx_stack = new Stack;
		this->document_path = std::make_shared<std::string>();
	}
}

Context::~Context()
{
	if (!parent) delete this->ctx_stack;
}

void Context::push(std::shared_ptr<Context> ctx)
{
	this->ctx_stack->push_back(ctx);
}

void Context::pop()
{
	assert(this->ctx_stack && "Context stack was null at destruction!");
	this->ctx_stack->pop_back();
}

/*!
	Initialize context from a module argument list and a evaluation context
	which may pass variables which will be preferred over default values.
*/
void Context::setVariables(const std::shared_ptr<EvalContext> evalctx, const AssignmentList &args, const AssignmentList &optargs, bool usermodule)
{
	// Set any default values
	for (const auto &arg : args) {
		set_variable(arg->getName(), arg->getExpr() ? arg->getExpr()->evaluate(this->parent) : ValuePtr::undefined);
	}
	
	if (evalctx) {
		auto assignments = evalctx->resolveArguments(args, optargs, usermodule && !OpenSCAD::parameterCheck);
		for (const auto &ass : assignments) {
			this->set_variable(ass.first, ass.second->evaluate(evalctx));
		}
	}
}

void Context::set_variable(const std::string &name, const ValuePtr &value)
{
	if (is_config_variable(name)) this->config_variables[name] = value;
	else this->variables[name] = value;
}

void Context::set_variable(const std::string &name, const Value &value)
{
	set_variable(name, ValuePtr(value));
}

void Context::set_constant(const std::string &name, const ValuePtr &value)
{
	if (this->constants.find(name) != this->constants.end()) {
		LOG(message_group::Warning,Location::NONE,"","Attempt to modify constant '%1$s'.",name);
	}
	else {
		this->constants[name] = value;
	}
}

void Context::set_constant(const std::string &name, const Value &value)
{
	set_constant(name, ValuePtr(value));
}

void Context::apply_variables(const std::shared_ptr<Context> other)
{
	for (const auto &var : other->variables) {
		set_variable(var.first, var.second);
	}
}

/*!
  Apply config variables of 'other' to this context, from the full context stack of 'other', bottom-up.
*/
void Context::apply_config_variables(const std::shared_ptr<Context> other)
{
	if (other.get() == this) {
		// Anything in 'other' and its ancestors is already part of this context, no need to descend any further.
		return;
	}
	if (other->parent) {
		// Assign parent's variables first, since they might be overridden by a child
		apply_config_variables(other->parent);
	}
	for (const auto &var : other->config_variables) {
		set_variable(var.first, var.second);
	}
}

ValuePtr Context::lookup_variable(const std::string &name, bool silent, const Location &loc) const
{
	assert(this->ctx_stack && "Context had null stack in lookup_variable()!!");
	if (is_config_variable(name)) {
		for (int i = this->ctx_stack->size()-1; i >= 0; i--) {
			const auto &confvars = ctx_stack->at(i)->config_variables;
			if (confvars.find(name) != confvars.end()) {
				return confvars.find(name)->second;
			}
		}
		if (!silent) {
			LOG(message_group::Warning,loc,this->documentPath(),"Ignoring unknown variable '%1$s'",name);
		}
		return ValuePtr::undefined;
	}
	if (!this->parent && this->constants.find(name) != this->constants.end()) {
		return this->constants.find(name)->second;
	}
	if (this->variables.find(name) != this->variables.end()) {
		return this->variables.find(name)->second;
	}
	if (this->parent) {
		return this->parent->lookup_variable(name, silent, loc);
	}
	if (!silent) {
		LOG(message_group::Warning,loc,this->documentPath(),"Ignoring unknown variable '%1$s'",name);
	}
	return ValuePtr::undefined;
}


double Context::lookup_variable_with_default(const std::string &variable, const double &def, const Location &loc) const
{
	ValuePtr v = this->lookup_variable(variable, true, loc);
	return (v->type() == Value::Type::NUMBER) ? v->toDouble() : def;
}

std::string Context::lookup_variable_with_default(const std::string &variable, const std::string &def, const Location &loc) const
{
	ValuePtr v = this->lookup_variable(variable, true, loc);
	return (v->type() == Value::Type::STRING) ? v->toString() : def;
}

ValuePtr Context::lookup_local_config_variable(const std::string &name) const
{
	if (is_config_variable(name)) {
		if (config_variables.find(name) != config_variables.end()) {
			return config_variables.find(name)->second;
		}
	}
	return ValuePtr::undefined;
}

bool Context::has_local_variable(const std::string &name) const
{
	if (is_config_variable(name)) {
		return config_variables.find(name) != config_variables.end();
	}
	if (!parent && constants.find(name) != constants.end()) {
		return true;
	}
	return variables.find(name) != variables.end();
}

/**
 * This is separated because PRINTB uses quite a lot of stack space
 * and the methods using it evaluate_function() and instantiate_module()
 * are called often when recursive functions or modules are evaluated.
 * noinline prevents compiler optimization, as we here specifically
 * optimize for stack usage during normal operating, not runtime during
 * error handling.
 *
 * @param what what is ignored
 * @param name name of the ignored object
 * @param loc location of the function/module call
 * @param docPath document path of the root file, used to calculate the relative path
 */
static void NOINLINE print_ignore_warning(const char *what, const char *name, const Location &loc, const char *docPath){
	LOG(message_group::Warning,loc,docPath,"Ignoring unknown %1$s '%2$s'",what,name);
}
 
ValuePtr Context::evaluate_function(const std::string &name, const std::shared_ptr<EvalContext>& evalctx) const
{
	if (this->parent) return this->parent->evaluate_function(name, evalctx);
	print_ignore_warning("function", name.c_str(),evalctx->loc,this->documentPath().c_str());
	return ValuePtr::undefined;
}

AbstractNode *Context::instantiate_module(const ModuleInstantiation &inst, const std::shared_ptr<EvalContext>& evalctx) const
{
	if (this->parent) return this->parent->instantiate_module(inst, evalctx);
	print_ignore_warning("module", inst.name().c_str(),evalctx->loc,this->documentPath().c_str());
	return nullptr;
}

/*!
	Returns the absolute path to the given filename, unless it's empty.
 */
std::string Context::getAbsolutePath(const std::string &filename) const
{
	if (!filename.empty() && !fs::path(filename).is_absolute()) {
		return fs::absolute(fs::path(*this->document_path) / filename).string();
	}
	else {
		return filename;
	}
}

#ifdef DEBUG
std::string Context::dump(const AbstractModule *mod, const ModuleInstantiation *inst)
{
	std::ostringstream s;
	if (inst) {
		s << boost::format("ModuleContext %p (%p) for %s inst (%p)\n") % this % this->parent % inst->name() % inst;
	}
	else {
		s << boost::format("Context: %p (%p)\n") % this % this->parent;
	}
	s << boost::format("  document path: %s\n") % *this->document_path;
	if (mod) {
		const UserModule *m = dynamic_cast<const UserModule*>(mod);
		if (m) {
			s << "  module args:";
			for(const auto &arg : m->definition_arguments) {
				s << boost::format("    %s = %s\n") % arg->getName() % variables[arg->getName()];
			}
		}
	}
	typedef std::pair<std::string, ValuePtr> ValueMapType;
	s << "  vars:\n";
	for(const auto &v : constants) {
		s << boost::format("    %s = %s\n") % v.first % v.second->toEchoString();
	}
	for(const auto &v : variables) {
		s << boost::format("    %s = %s\n") % v.first % v.second->toEchoString();
	}
	for(const auto &v : config_variables) {
		s << boost::format("    %s = %s\n") % v.first % v.second->toEchoString();
	}
	return s.str();
}
#endif

