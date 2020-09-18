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

#include "calc.h"
#include "module.h"
#include "evalcontext.h"
#include "../common/printutils.h"
#include "builtin.h"

#include "textnode.h"
#include "TextModule.h"
#include "../gui/FreetypeRenderer.h"
#include "math/Polygon2d.h"

#include <boost/assign/std/vector.hpp>
using namespace boost::assign; // bring 'operator+=()' into scope

std::vector<const Geometry *> TextNode::createGeometryList() const
{
	FreetypeRenderer renderer;
	return renderer.render(this->get_params());
}

FreetypeRenderer::Params TextNode::get_params() const
{
	return params;
}

std::string TextNode::toString() const
{
	return STR(name() << "(" << this->params << ")");
}

void register_builtin_text()
{
	Builtins::init("text", new TextModule(),
				{
					"text(string, size = 10, string, halign = \"left\", valign = \"baseline\", spacing = 1, direction = \"ltr\", language = \"en\", script = \"latin\"[, $fn])",
				});
}