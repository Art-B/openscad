#pragma once

#include "engine/math/Polygon2d.h"
#include "cgal.h"
#include "CGAL_Nef_polyhedron.h"

namespace Polygon2DCGAL {
	CGAL_Nef_polyhedron toNefPolyhedron();
};
